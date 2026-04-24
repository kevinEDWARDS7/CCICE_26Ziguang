#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#include <xf86drm.h>
#include <xf86drmMode.h>

#define TYPE 'S'
#define PCI_MAP_ADDR_CMD _IOWR(TYPE, 2, int)
#define PCI_DMA_READ_CMD _IOWR(TYPE, 4, int)
#define PCI_DMA_WRITE_CMD _IOWR(TYPE, 5, int)
#define PCI_READ_FROM_KERNEL_CMD _IOWR(TYPE, 6, int)
#define PCI_UMAP_ADDR_CMD _IOWR(TYPE, 7, int)

#define DMA_MAX_PACKET_SIZE 4096
#define DMA_BEAT_BYTES 16U
#define DMA_BEAT_RGB565_PIXELS (DMA_BEAT_BYTES / 2U)

typedef struct {
    unsigned char read_buf[DMA_MAX_PACKET_SIZE];
    unsigned char write_buf[DMA_MAX_PACKET_SIZE];
} DMA_DATA;

typedef struct {
    unsigned int current_len;
    unsigned int offset_addr;
    unsigned int cmd;
    DMA_DATA data;
} DMA_OPERATION;

typedef enum {
    SRC_FMT_RGB565 = 0,
    SRC_FMT_RGB888 = 1
} SrcPixelFormat;

typedef enum {
    RGB565_ORDER_NORMAL = 0,
    RGB565_ORDER_PIXEL_SWAP,
    RGB565_ORDER_BEAT16_REVERSE,
    RGB565_ORDER_BEAT16_REVERSE_PIXEL_SWAP
} Rgb565Order;

typedef struct {
    int fd;
    uint32_t conn_id;
    uint32_t crtc_id;
    drmModeModeInfo mode;
    drmModeCrtc *orig_crtc;

    uint32_t fb_id;
    uint32_t handle;
    uint32_t pitch;
    uint64_t size;
    unsigned char *map;
} DrmOutput;

typedef struct {
    int pcie_fd;
    DMA_OPERATION dma;
    unsigned int src_width;
    unsigned int src_height;
    unsigned int src_line_bytes;
    SrcPixelFormat src_format;
    Rgb565Order rgb565_order;
    unsigned int fps_limit;
    unsigned int busy_wait_loop;
    unsigned int dma_retries;
    unsigned int retry_sleep_us;
    unsigned int max_line_failures;
    unsigned int debug_enable;
    unsigned int debug_interval_sec;
    unsigned int debug_overlay;
    unsigned int dump_frames;
    const char *dump_prefix;
    const char *pcie_path;
    const char *drm_path;
    const char *connector_name;
} AppContext;

typedef struct {
    unsigned int dma_lines_ok;
    unsigned int dma_lines_fail;
    unsigned int nonzero_lines;
    unsigned int changed_lines;
    unsigned int fb_lines_written;
    uint64_t frame_hash;
} FrameDebugInfo;

typedef struct {
    uint64_t start_ns;
    uint64_t last_report_ns;
    uint64_t last_line_hash;
    uint64_t last_frame_hash;
    unsigned int repeated_frame_hashes;

    unsigned long long frame_index;
    unsigned long long dma_ok_lines;
    unsigned long long dma_fail_lines;
    unsigned long long all_zero_lines;
    unsigned long long changed_lines;
    unsigned long long displayed_frames;
    unsigned long long displayed_pixels;
    unsigned long long received_bytes;
    unsigned long long dumped_frames;
} PipelineStats;

static volatile sig_atomic_t g_stop = 0;

static void on_signal(int signo)
{
    (void)signo;
    g_stop = 1;
}

static unsigned int parse_u32(const char *s, const char *name)
{
    char     *end   = NULL;
    unsigned long v = strtoul(s, &end, 10);
    if (s[0] == '\0' || end == NULL || *end != '\0') {
        fprintf(stderr, "invalid %s: %s\n", name, s);
        exit(2);
    }
    if (v > 0xFFFFFFFFUL) {
        fprintf(stderr, "%s out of range: %s\n", name, s);
        exit(2);
    }
    return (unsigned int)v;
}

static const char *src_fmt_name(SrcPixelFormat fmt)
{
    return (fmt == SRC_FMT_RGB888) ? "RGB888": "RGB565";
}

static SrcPixelFormat parse_src_format(const char *s)
{
    if (strcmp(s, "rgb565") == 0) {
        return SRC_FMT_RGB565;
    }
    if (strcmp(s, "rgb888") == 0) {
        return SRC_FMT_RGB888;
    }

    fprintf(stderr, "invalid --src-format: %s (expected: rgb565 or rgb888)\n", s);
    exit(2);
}

static const char *rgb565_order_name(Rgb565Order order)
{
    switch (order) {
    case RGB565_ORDER_NORMAL: 
        return "normal";
    case RGB565_ORDER_PIXEL_SWAP: 
        return "pixel-swap";
    case RGB565_ORDER_BEAT16_REVERSE: 
        return "beat16-reverse";
    case RGB565_ORDER_BEAT16_REVERSE_PIXEL_SWAP: 
        return "beat16-reverse-pixel-swap";
    default: 
        return "unknown";
    }
}

static Rgb565Order parse_rgb565_order(const char *s)
{
    if (strcmp(s, "normal") == 0) {
        return RGB565_ORDER_NORMAL;
    }
    if (strcmp(s, "pixel-swap") == 0) {
        return RGB565_ORDER_PIXEL_SWAP;
    }
    if (strcmp(s, "beat16-reverse") == 0) {
        return RGB565_ORDER_BEAT16_REVERSE;
    }
    if (strcmp(s, "beat16-reverse-pixel-swap") == 0) {
        return RGB565_ORDER_BEAT16_REVERSE_PIXEL_SWAP;
    }

    fprintf(stderr,
            "invalid --rgb565-order: %s (expected: normal, pixel-swap, beat16-reverse, beat16-reverse-pixel-swap)\n",
            s);
    exit(2);
}

static inline uint16_t load_rgb565_pixel(const unsigned char *src_line,
                                         unsigned int logical_x,
                                         unsigned int src_total_pixels,
                                         Rgb565Order order)
{
    unsigned int physical_x = logical_x;
    unsigned int byte_index;
    uint8_t lo;
    uint8_t hi;

    if (logical_x >= src_total_pixels) {
        return 0;
    }

    if (order == RGB565_ORDER_BEAT16_REVERSE ||
        order == RGB565_ORDER_BEAT16_REVERSE_PIXEL_SWAP) {
        unsigned int beat_base = (logical_x / DMA_BEAT_RGB565_PIXELS) * DMA_BEAT_RGB565_PIXELS;
        unsigned int in_beat   = logical_x % DMA_BEAT_RGB565_PIXELS;
                 physical_x    = beat_base + (DMA_BEAT_RGB565_PIXELS - 1U - in_beat);
    }

    byte_index = 2U * physical_x;
    lo         = src_line[byte_index];
    hi         = src_line[byte_index + 1U];

    if (order == RGB565_ORDER_PIXEL_SWAP ||
        order == RGB565_ORDER_BEAT16_REVERSE_PIXEL_SWAP) {
        uint8_t tmp = lo;
                lo  = hi;
                hi  = tmp;
    }

    return (uint16_t)lo | ((uint16_t)hi << 8);
}

static inline void blit_line_rgb565_to_xrgb8888(unsigned char *dst_line,
                                                const unsigned char *src_line,
                                                unsigned int src_total_pixels,
                                                unsigned int display_pixels,
                                                Rgb565Order order)
{
    for (unsigned int x = 0; x < display_pixels; ++x) {
        uint16_t p565 = load_rgb565_pixel(src_line, x, src_total_pixels, order);
        uint8_t  r5   = (uint8_t)((p565 >> 11) & 0x1FU);
        uint8_t  g6   = (uint8_t)((p565 >> 5) & 0x3FU);
        uint8_t  b5   = (uint8_t)(p565 & 0x1FU);
        uint8_t  r8   = (uint8_t)((r5 << 3) | (r5 >> 2));
        uint8_t  g8   = (uint8_t)((g6 << 2) | (g6 >> 4));
        uint8_t  b8   = (uint8_t)((b5 << 3) | (b5 >> 2));

        dst_line[4U * x]      = b8;
        dst_line[4U * x + 1U] = g8;
        dst_line[4U * x + 2U] = r8;
        dst_line[4U * x + 3U] = 0;
    }
}

static inline void blit_line_rgb888_to_xrgb8888(unsigned char *dst_line,
                                                const unsigned char *src_line,
                                                unsigned int pixel_count)
{
    for (unsigned int x = 0; x < pixel_count; ++x) {
        uint8_t r8 = src_line[3U * x];
        uint8_t g8 = src_line[3U * x + 1U];
        uint8_t b8 = src_line[3U * x + 2U];

        dst_line[4U * x]      = b8;
        dst_line[4U * x + 1U] = g8;
        dst_line[4U * x + 2U] = r8;
        dst_line[4U * x + 3U] = 0;
    }
}

static void usage(const char *prog)
{
    fprintf(stderr,
            "Usage: %s [--pcie /dev/pango_pci_driver] [--drm /dev/dri/card0] "
            "[--connector HDMI-A-1] [--width 1280] [--height 720] "
            "[--line-bytes 2560] [--src-format rgb565] [--rgb565-order normal] "
            "[--fps 0] [--busy-wait 4000] [--dma-retries 8] [--retry-sleep-us 100] [--max-line-failures 0] "
            "[--debug] [--debug-interval 1] [--no-debug-overlay] "
            "[--dump-frames 0] [--dump-prefix debug_frame]\n",
            prog);
}

static int open_pcie(const char *pcie_path)
{
    int fd = open(pcie_path, O_RDWR);
    if (fd < 0) {
        perror("open pcie");
    }
    return fd;
}

static int dma_map(int fd, DMA_OPERATION *dma)
{
    if (ioctl(fd, PCI_MAP_ADDR_CMD, dma) != 0) {
        perror("PCI_MAP_ADDR_CMD");
        return -1;
    }
    return 0;
}

static void sleep_us(unsigned int us)
{
    struct timespec ts;

    if (us == 0U) {
        return;
    }

    ts.tv_sec  = us / 1000000U;
    ts.tv_nsec = (long)(us % 1000000U) * 1000L;
    (void)nanosleep(&ts, NULL);
}

static void dma_unmap(int fd, DMA_OPERATION *dma)
{
    if (fd >= 0) {
        (void)ioctl(fd, PCI_UMAP_ADDR_CMD, dma);
    }
}

static int recv_one_line(int fd,
                         DMA_OPERATION *dma,
                         unsigned int busy_wait_loop,
                         unsigned int dma_retries,
                         unsigned int retry_sleep_us,
                         int *last_err)
{
    int      err          = EIO;
    unsigned int attempts = dma_retries + 1U;

    dma->cmd = PCI_DMA_WRITE_CMD;

    for (unsigned int attempt = 0; attempt < attempts; ++attempt) {
        if (ioctl(fd, PCI_DMA_WRITE_CMD, dma) != 0) {
            err = errno;
            if (err == EINTR && g_stop) {
                break;
            }
            sleep_us(retry_sleep_us);
            continue;
        }

        for (volatile unsigned int i = 0; i < busy_wait_loop; ++i) {
        }

        if (ioctl(fd, PCI_READ_FROM_KERNEL_CMD, dma) == 0) {
            if (last_err) {
                *last_err = 0;
            }
            return 0;
        }

        err = errno;
        if (err == EINTR && g_stop) {
            break;
        }
        sleep_us(retry_sleep_us);
    }

    if (last_err) {
        *last_err = err;
    }

    return -1;
}

static void sleep_for_fps(unsigned int fps)
{
    struct timespec ts;

    if (fps == 0U) {
        return;
    }

    ts.tv_sec  = 0;
    ts.tv_nsec = 1000000000L / (long)fps;
    (void)nanosleep(&ts, NULL);
}

static uint64_t monotonic_ns(void)
{
    struct timespec ts;

    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
        return 0;
    }

    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
}

static uint64_t fnv1a64(const unsigned char *buf, unsigned int len)
{
    uint64_t h = 1469598103934665603ULL;

    for (unsigned int i = 0; i < len; ++i) {
        h ^= (uint64_t)buf[i];
        h *= 1099511628211ULL;
    }

    return h;
}

static unsigned int count_nonzero_bytes(const unsigned char *buf, unsigned int len)
{
    unsigned int count = 0;

    for (unsigned int i = 0; i < len; ++i) {
        if (buf[i] != 0U) {
            ++count;
        }
    }

    return count;
}

static void stats_init(PipelineStats *stats)
{
    memset(stats, 0, sizeof(*stats));
    stats->start_ns = monotonic_ns();
}

static const char *frame_dma_state(const FrameDebugInfo *frame, unsigned int expect_lines)
{
    if (frame->dma_lines_ok == 0U) {
        return "NO_DMA";
    }
    if (frame->dma_lines_ok == expect_lines && frame->dma_lines_fail == 0U) {
        return "DMA_OK";
    }
    return "DMA_PARTIAL";
}

static const char *frame_data_state(const FrameDebugInfo *frame)
{
    if (frame->dma_lines_ok == 0U) {
        return "NO_INPUT";
    }
    if (frame->nonzero_lines == 0U) {
        return "ALL_ZERO";
    }
    if (frame->changed_lines == 0U) {
        return "STATIC_OR_STUCK";
    }
    return "ACTIVE";
}

static void put_pixel_xrgb8888(DrmOutput *drm, unsigned int x, unsigned int y, uint8_t r, uint8_t g, uint8_t b)
{
    unsigned char *p;

    if (!drm->map) {
        return;
    }
    if (x >= (unsigned int)drm->mode.hdisplay || y >= (unsigned int)drm->mode.vdisplay) {
        return;
    }

    p = drm->map + (size_t)y * drm->pitch + (size_t)x * 4U;
    p[0] = b;
    p[1] = g;
    p[2] = r;
    p[3] = 0;
}

static void fill_rect_xrgb8888(DrmOutput *drm,
                               unsigned int x,
                               unsigned int y,
                               unsigned int w,
                               unsigned int h,
                               uint8_t r,
                               uint8_t g,
                               uint8_t b)
{
    unsigned int x_end = x + w;
    unsigned int y_end = y + h;

    if (x >= (unsigned int)drm->mode.hdisplay || y >= (unsigned int)drm->mode.vdisplay) {
        return;
    }
    if (x_end > (unsigned int)drm->mode.hdisplay) {
        x_end = (unsigned int)drm->mode.hdisplay;
    }
    if (y_end > (unsigned int)drm->mode.vdisplay) {
        y_end = (unsigned int)drm->mode.vdisplay;
    }

    for (unsigned int yy = y; yy < y_end; ++yy) {
        for (unsigned int xx = x; xx < x_end; ++xx) {
            put_pixel_xrgb8888(drm, xx, yy, r, g, b);
        }
    }
}

static void draw_debug_overlay(DrmOutput *drm,
                               const FrameDebugInfo *frame,
                               unsigned int expect_lines,
                               unsigned long long frame_index)
{
    uint8_t dma_r = 255, dma_g = 0, dma_b = 0;
    uint8_t data_r = 255, data_g = 0, data_b = 0;
    uint8_t fb_r = 255, fb_g = 0, fb_b = 0;
    unsigned int marker_x;
    unsigned int marker_y = 44U;

    if (frame->dma_lines_ok == expect_lines && frame->dma_lines_fail == 0U) {
        dma_r = 0; dma_g = 220; dma_b = 0;
    } else if (frame->dma_lines_ok > 0U) {
        dma_r = 255; dma_g = 196; dma_b = 0;
    }

    if (frame->nonzero_lines == 0U && frame->dma_lines_ok > 0U) {
        data_r = 255; data_g = 196; data_b = 0;
    } else if (frame->changed_lines > 0U) {
        data_r = 0; data_g = 220; data_b = 0;
    } else if (frame->dma_lines_ok > 0U) {
        data_r = 255; data_g = 128; data_b = 0;
    }

    if (frame->fb_lines_written > 0U) {
        fb_r = 0; fb_g = 220; fb_b = 0;
    }

    fill_rect_xrgb8888(drm, 4U, 4U, 96U, 28U, 12U, 12U, 12U);
    fill_rect_xrgb8888(drm, 8U, 8U, 24U, 20U, dma_r, dma_g, dma_b);
    fill_rect_xrgb8888(drm, 38U, 8U, 24U, 20U, data_r, data_g, data_b);
    fill_rect_xrgb8888(drm, 68U, 8U, 24U, 20U, fb_r, fb_g, fb_b);

    marker_x = 4U + (unsigned int)(frame_index % ((unsigned long long)((drm->mode.hdisplay > 20) ? (drm->mode.hdisplay - 20) : 1)));
    fill_rect_xrgb8888(drm, 0U, marker_y, (unsigned int)drm->mode.hdisplay, 2U, 0U, 0U, 32U);
    fill_rect_xrgb8888(drm, marker_x, marker_y - 2U, 16U, 6U, 255U, 255U, 255U);
}

static int dump_frame_to_ppm(const char *path,
                             const DrmOutput *drm,
                             unsigned int width,
                             unsigned int height)
{
    FILE *fp = fopen(path, "wb");
    if (!fp) {
        perror("fopen dump frame");
        return -1;
    }

    fprintf(fp, "P6\n%u %u\n255\n", width, height);
    for (unsigned int y = 0; y < height; ++y) {
        const unsigned char *src = drm->map + (size_t)y * drm->pitch;
        for (unsigned int x = 0; x < width; ++x) {
            const unsigned char *p = src + (size_t)x * 4U;
            unsigned char rgb[3];
            rgb[0] = p[2];
            rgb[1] = p[1];
            rgb[2] = p[0];
            if (fwrite(rgb, 1, 3, fp) != 3U) {
                fclose(fp);
                fprintf(stderr, "failed to write dump frame %s\n", path);
                return -1;
            }
        }
    }

    fclose(fp);
    return 0;
}

static void report_debug_stats(const AppContext *ctx,
                               const DrmOutput *drm,
                               PipelineStats *stats,
                               const FrameDebugInfo *frame,
                               unsigned int expect_lines)
{
    uint64_t now_ns;
    double elapsed_total;
    double elapsed_since_report;
    double fps;
    double mbps;

    if (!ctx->debug_enable || ctx->debug_interval_sec == 0U) {
        return;
    }

    now_ns = monotonic_ns();
    if (stats->last_report_ns != 0U &&
        now_ns - stats->last_report_ns < (uint64_t)ctx->debug_interval_sec * 1000000000ULL) {
        return;
    }

    elapsed_total = (stats->start_ns == 0U) ? 0.0 : (double)(now_ns - stats->start_ns) / 1000000000.0;
    elapsed_since_report = (stats->last_report_ns == 0U) ? elapsed_total : (double)(now_ns - stats->last_report_ns) / 1000000000.0;
    if (elapsed_total <= 0.0) {
        elapsed_total = 1e-6;
    }
    if (elapsed_since_report <= 0.0) {
        elapsed_since_report = 1e-6;
    }

    fps = (double)stats->displayed_frames / elapsed_total;
    mbps = (double)stats->received_bytes / elapsed_total / (1024.0 * 1024.0);

    fprintf(stdout,
            "[debug] t=%.2fs frame=%llu fps=%.2f rx=%.2f MiB dma_ok_lines=%llu dma_fail_lines=%llu all_zero=%llu changed=%llu dumped=%llu\n",
            elapsed_total,
            stats->frame_index,
            fps,
            mbps,
            stats->dma_ok_lines,
            stats->dma_fail_lines,
            stats->all_zero_lines,
            stats->changed_lines,
            stats->dumped_frames);
    fprintf(stdout,
            "        last_frame: dma=%s data=%s fb=%s hash=0x%016" PRIx64 " repeated=%u display=%ux%u\n",
            frame_dma_state(frame, expect_lines),
            frame_data_state(frame),
            frame->fb_lines_written > 0U ? "FB_OK" : "FB_SKIP",
            frame->frame_hash,
            stats->repeated_frame_hashes,
            drm->mode.hdisplay,
            drm->mode.vdisplay);
    fflush(stdout);

    stats->last_report_ns = now_ns;
}

static int select_connector_and_mode(int drm_fd,
                                     const char *want_name,
                                     unsigned int want_width,
                                     unsigned int want_height,
                                     uint32_t *out_conn_id,
                                     drmModeModeInfo *out_mode,
                                     uint32_t *out_enc_id,
                                     int *out_mode_exact)
{
    drmModeRes *res = drmModeGetResources(drm_fd);
    if (!res) {
        perror("drmModeGetResources");
        return -1;
    }

    for (int i = 0; i < res->count_connectors; ++i) {
        drmModeConnector *conn = drmModeGetConnector(drm_fd, res->connectors[i]);
        if (!conn) {
            continue;
        }

        if (conn->connection != DRM_MODE_CONNECTED || conn->count_modes == 0) {
            drmModeFreeConnector(conn);
            continue;
        }

        char name[64];
        snprintf(name, sizeof(name), "%s-%u",
                 drmModeGetConnectorTypeName(conn->connector_type),
                 conn->connector_type_id);

        if (want_name && strcmp(name, want_name) != 0) {
            drmModeFreeConnector(conn);
            continue;
        }

        int preferred_idx       = -1;
        int exact_idx           = -1;
        int exact_preferred_idx = -1;
        for (int m = 0; m < conn->count_modes; ++m) {
            drmModeModeInfo *mode = &conn->modes[m];
            if ((mode->type & DRM_MODE_TYPE_PREFERRED) && preferred_idx < 0) {
                preferred_idx = m;
            }
            if ((unsigned int)mode->hdisplay == want_width &&
                (unsigned int)mode->vdisplay == want_height) {
                if (mode->type & DRM_MODE_TYPE_PREFERRED) {
                    exact_preferred_idx = m;
                    break;
                }
                if (exact_idx < 0) {
                    exact_idx = m;
                }
            }
        }

        int picked_idx    = 0;
        int exact_matched = 0;
        if (exact_preferred_idx >= 0) {
            picked_idx    = exact_preferred_idx;
            exact_matched = 1;
        } else if (exact_idx >= 0) {
            picked_idx    = exact_idx;
            exact_matched = 1;
        } else if (preferred_idx >= 0) {
            picked_idx = preferred_idx;
        }

        *out_conn_id = conn->connector_id;
        *out_mode    = conn->modes[picked_idx];
        *out_enc_id  = conn->encoder_id;
        if (*out_enc_id == 0 && conn->count_encoders > 0) {
            *out_enc_id = conn->encoders[0];
        }
        if (out_mode_exact) {
            *out_mode_exact = exact_matched;
        }
        drmModeFreeConnector(conn);
        drmModeFreeResources(res);
        return 0;
    }

    drmModeFreeResources(res);
    fprintf(stderr, "no connected connector matched '%s'\n", want_name ? want_name : "<any>");
    return -1;
}

static int select_crtc_for_encoder(int drm_fd, uint32_t encoder_id, uint32_t *out_crtc_id)
{
    drmModeRes *res = drmModeGetResources(drm_fd);
    if (!res) {
        perror("drmModeGetResources");
        return -1;
    }

    if (encoder_id == 0) {
        if (res->count_crtcs > 0) {
            *out_crtc_id = res->crtcs[0];
            drmModeFreeResources(res);
            return 0;
        }
        drmModeFreeResources(res);
        fprintf(stderr, "no CRTC found in DRM resources\n");
        return -1;
    }

    drmModeEncoder *enc = drmModeGetEncoder(drm_fd, encoder_id);
    if (enc && enc->crtc_id) {
        *out_crtc_id = enc->crtc_id;
        drmModeFreeEncoder(enc);
        drmModeFreeResources(res);
        return 0;
    }

    if (enc) {
        for (int i = 0; i < res->count_crtcs; ++i) {
            if (enc->possible_crtcs & (1U << i)) {
                *out_crtc_id = res->crtcs[i];
                drmModeFreeEncoder(enc);
                drmModeFreeResources(res);
                return 0;
            }
        }
        drmModeFreeEncoder(enc);
    }

    drmModeFreeResources(res);
    fprintf(stderr, "cannot find usable CRTC for encoder %u\n", encoder_id);
    return -1;
}

static int drm_setup(DrmOutput *out,
                     const char *drm_path,
                     const char *connector_name,
                     unsigned int want_mode_width,
                     unsigned int want_mode_height)
{
    struct drm_mode_create_dumb creq;
    struct drm_mode_map_dumb mreq;

    memset(out, 0, sizeof(*out));
    out->fd = -1;

    out->fd = open(drm_path, O_RDWR | O_CLOEXEC);
    if (out->fd < 0) {
        perror("open drm");
        return -1;
    }

    uint32_t enc_id     = 0;
    int      exact_mode = 0;
    if (select_connector_and_mode(out->fd,
                                  connector_name,
                                  want_mode_width,
                                  want_mode_height,
                                  &out->conn_id,
                                  &out->mode,
                                  &enc_id,
                                  &exact_mode) != 0) {
        return -1;
    }
    if (!exact_mode) {
        fprintf(stderr,
                "warning: requested display mode %ux%u not found; using connector mode %ux%u (%s)\n",
                want_mode_width,
                want_mode_height,
                out->mode.hdisplay,
                out->mode.vdisplay,
                out->mode.name);
    }
    if (select_crtc_for_encoder(out->fd, enc_id, &out->crtc_id) != 0) {
        return -1;
    }

    out->orig_crtc = drmModeGetCrtc(out->fd, out->crtc_id);

    memset(&creq, 0, sizeof(creq));
    creq.width  = out->mode.hdisplay;
    creq.height = out->mode.vdisplay;
    creq.bpp    = 32;

    if (ioctl(out->fd, DRM_IOCTL_MODE_CREATE_DUMB, &creq) != 0) {
        perror("DRM_IOCTL_MODE_CREATE_DUMB");
        return -1;
    }

    out->handle = creq.handle;
    out->pitch  = creq.pitch;
    out->size   = creq.size;

    if (drmModeAddFB(out->fd,
                     out->mode.hdisplay,
                     out->mode.vdisplay,
                     24,
                     32,
                     out->pitch,
                     out->handle,
                     &out->fb_id) != 0) {
        perror("drmModeAddFB");
        return -1;
    }

    memset(&mreq, 0, sizeof(mreq));
    mreq.handle = out->handle;
    if (ioctl(out->fd, DRM_IOCTL_MODE_MAP_DUMB, &mreq) != 0) {
        perror("DRM_IOCTL_MODE_MAP_DUMB");
        return -1;
    }

    out->map = mmap(NULL, out->size, PROT_READ | PROT_WRITE, MAP_SHARED, out->fd, mreq.offset);
    if (out->map == MAP_FAILED) {
        perror("mmap dumb");
        out->map = NULL;
        return -1;
    }

    memset(out->map, 0, out->size);

    if (drmModeSetCrtc(out->fd,
                       out->crtc_id,
                       out->fb_id,
                       0,
                       0,
                       &out->conn_id,
                       1,
                       &out->mode) != 0) {
        perror("drmModeSetCrtc");
        return -1;
    }

    fprintf(stdout,
            "DRM set: connector=%u mode=%s %ux%u, crtc=%u, pitch=%u\n",
            out->conn_id,
            out->mode.name,
            out->mode.hdisplay,
            out->mode.vdisplay,
            out->crtc_id,
            out->pitch);

    return 0;
}

static void drm_cleanup(DrmOutput *out)
{
    if (out->orig_crtc) {
        drmModeSetCrtc(out->fd,
                       out->orig_crtc->crtc_id,
                       out->orig_crtc->buffer_id,
                       out->orig_crtc->x,
                       out->orig_crtc->y,
                       &out->conn_id,
                       1,
                       &out->orig_crtc->mode);
        drmModeFreeCrtc(out->orig_crtc);
        out->orig_crtc = NULL;
    }

    if (out->map) {
        munmap(out->map, out->size);
        out->map = NULL;
    }

    if (out->fb_id) {
        drmModeRmFB(out->fd, out->fb_id);
        out->fb_id = 0;
    }

    if (out->handle) {
        struct drm_mode_destroy_dumb dreq;
        memset(&dreq, 0, sizeof(dreq));
        dreq.handle = out->handle;
        (void)ioctl(out->fd, DRM_IOCTL_MODE_DESTROY_DUMB, &dreq);
        out->handle = 0;
    }

    if (out->fd >= 0) {
        close(out->fd);
        out->fd = -1;
    }
}

static int validate_runtime_config(const AppContext *ctx)
{
    if (ctx->src_line_bytes > DMA_MAX_PACKET_SIZE) {
        fprintf(stderr,
                "line-bytes %u exceeds DMA_MAX_PACKET_SIZE %u\n",
                ctx->src_line_bytes,
                DMA_MAX_PACKET_SIZE);
        return -1;
    }

    if ((ctx->src_line_bytes % 4U) != 0U || ctx->src_line_bytes == 0U) {
        fprintf(stderr, "line-bytes must be non-zero and 4-byte aligned\n");
        return -1;
    }

    if (ctx->src_format == SRC_FMT_RGB565 &&
        (ctx->rgb565_order == RGB565_ORDER_BEAT16_REVERSE ||
         ctx->rgb565_order == RGB565_ORDER_BEAT16_REVERSE_PIXEL_SWAP) &&
        ((ctx->src_line_bytes % DMA_BEAT_BYTES) != 0U)) {
        fprintf(stderr,
                "rgb565 beat16 reverse mode requires line-bytes to be a multiple of %u bytes\n",
                DMA_BEAT_BYTES);
        return -1;
    }

    return 0;
}

static int run_pipeline(AppContext *ctx, DrmOutput *drm)
{
    unsigned int xres_use;
    unsigned int yres_use;
    unsigned int src_bytes_pp;
    unsigned int expected_line_bytes;
    unsigned int line_fail_streak    = 0;
    unsigned long long dropped_lines = 0;
    PipelineStats stats;

    if (validate_runtime_config(ctx) != 0) {
        return -1;
    }

    stats_init(&stats);

    src_bytes_pp        = (ctx->src_format == SRC_FMT_RGB888) ? 3U : 2U;
    expected_line_bytes = ctx->src_width * src_bytes_pp;
    if (ctx->src_line_bytes != expected_line_bytes) {
        fprintf(stderr,
                "warning: line-bytes (%u) != width*%u (%u) for %s\n",
                ctx->src_line_bytes,
                src_bytes_pp,
                expected_line_bytes,
                src_fmt_name(ctx->src_format));
    }

    memset(&ctx->dma, 0, sizeof(ctx->dma));
    ctx->dma.current_len = ctx->src_line_bytes / 4U;
    ctx->dma.offset_addr = 0;
    ctx->dma.cmd         = PCI_DMA_WRITE_CMD;

    if (dma_map(ctx->pcie_fd, &ctx->dma) != 0) {
        return -1;
    }

    xres_use = ctx->src_width < (unsigned int)drm->mode.hdisplay ? ctx->src_width : (unsigned int)drm->mode.hdisplay;
    yres_use = ctx->src_height < (unsigned int)drm->mode.vdisplay ? ctx->src_height : (unsigned int)drm->mode.vdisplay;

    fprintf(stdout,
            "start: src=%ux%u %s, display=%ux%u, fps_limit=%u, busy_wait=%u, retries=%u, retry_sleep_us=%u",
            ctx->src_width,
            ctx->src_height,
            src_fmt_name(ctx->src_format),
            drm->mode.hdisplay,
            drm->mode.vdisplay,
            ctx->fps_limit,
            ctx->busy_wait_loop,
            ctx->dma_retries,
            ctx->retry_sleep_us);
    if (ctx->src_format == SRC_FMT_RGB565) {
        fprintf(stdout, ", rgb565_order=%s", rgb565_order_name(ctx->rgb565_order));
    }
    if (ctx->debug_enable) {
        fprintf(stdout, ", debug=on, overlay=%s, report=%us",
                ctx->debug_overlay ? "on" : "off",
                ctx->debug_interval_sec);
        if (ctx->dump_frames > 0U) {
            fprintf(stdout, ", dump_frames=%u, dump_prefix=%s", ctx->dump_frames, ctx->dump_prefix);
        }
    }
    fprintf(stdout, "\n");

    while (!g_stop) {
        FrameDebugInfo frame;

        memset(&frame, 0, sizeof(frame));
        frame.frame_hash = 1469598103934665603ULL;
        ++stats.frame_index;

        for (unsigned int y = 0; y < yres_use; ++y) {
            int      dma_err   = 0;
            unsigned char *dst = drm->map + (size_t)y * drm->pitch;

            if (recv_one_line(ctx->pcie_fd,
                              &ctx->dma,
                              ctx->busy_wait_loop,
                              ctx->dma_retries,
                              ctx->retry_sleep_us,
                              &dma_err) != 0) {
                ++line_fail_streak;
                ++dropped_lines;
                ++frame.dma_lines_fail;
                ++stats.dma_fail_lines;
                memset(dst, 0, drm->pitch);
                if (line_fail_streak == 1U || (line_fail_streak % 120U) == 0U) {
                    fprintf(stderr,
                            "warning: dma line recv failed, streak=%u, dropped=%llu, errno=%d(%s)\n",
                            line_fail_streak,
                            dropped_lines,
                            dma_err,
                            strerror(dma_err));
                }
                if (ctx->max_line_failures > 0U && line_fail_streak >= ctx->max_line_failures) {
                    fprintf(stderr, "error: dma failed for %u consecutive lines, exiting.\n", line_fail_streak);
                    dma_unmap(ctx->pcie_fd, &ctx->dma);
                    return -1;
                }
                continue;
            }

            line_fail_streak = 0;
            ++frame.dma_lines_ok;
            ++stats.dma_ok_lines;
            stats.received_bytes += ctx->src_line_bytes;

            {
                unsigned int nonzero = count_nonzero_bytes(ctx->dma.data.read_buf, ctx->src_line_bytes);
                uint64_t line_hash = fnv1a64(ctx->dma.data.read_buf, ctx->src_line_bytes);

                if (nonzero == 0U) {
                    ++stats.all_zero_lines;
                } else {
                    ++frame.nonzero_lines;
                }
                if (stats.last_line_hash != 0U && stats.last_line_hash != line_hash) {
                    ++frame.changed_lines;
                    ++stats.changed_lines;
                }
                stats.last_line_hash = line_hash;
                frame.frame_hash ^= line_hash + 0x9e3779b97f4a7c15ULL + (frame.frame_hash << 6U) + (frame.frame_hash >> 2U);
            }

            if (ctx->src_format == SRC_FMT_RGB888) {
                blit_line_rgb888_to_xrgb8888(dst, ctx->dma.data.read_buf, xres_use);
            } else {
                blit_line_rgb565_to_xrgb8888(dst,
                                             ctx->dma.data.read_buf,
                                             ctx->src_width,
                                             xres_use,
                                             ctx->rgb565_order);
            }
            ++frame.fb_lines_written;
            stats.displayed_pixels += xres_use;
            if (drm->pitch > xres_use * 4U) {
                memset(dst + xres_use * 4U, 0, drm->pitch - xres_use * 4U);
            }
        }

        for (unsigned int y = yres_use; y < ctx->src_height; ++y) {
            int dma_err = 0;
            if (recv_one_line(ctx->pcie_fd,
                              &ctx->dma,
                              ctx->busy_wait_loop,
                              ctx->dma_retries,
                              ctx->retry_sleep_us,
                              &dma_err) != 0) {
                ++line_fail_streak;
                ++dropped_lines;
                ++frame.dma_lines_fail;
                ++stats.dma_fail_lines;
                if (line_fail_streak == 1U || (line_fail_streak % 120U) == 0U) {
                    fprintf(stderr,
                            "warning: dma line recv failed, streak=%u, dropped=%llu, errno=%d(%s)\n",
                            line_fail_streak,
                            dropped_lines,
                            dma_err,
                            strerror(dma_err));
                }
                if (ctx->max_line_failures > 0U && line_fail_streak >= ctx->max_line_failures) {
                    fprintf(stderr, "error: dma failed for %u consecutive lines, exiting.\n", line_fail_streak);
                    dma_unmap(ctx->pcie_fd, &ctx->dma);
                    return -1;
                }
                continue;
            }
            line_fail_streak = 0;
            ++frame.dma_lines_ok;
            ++stats.dma_ok_lines;
            stats.received_bytes += ctx->src_line_bytes;

            {
                unsigned int nonzero = count_nonzero_bytes(ctx->dma.data.read_buf, ctx->src_line_bytes);
                uint64_t line_hash = fnv1a64(ctx->dma.data.read_buf, ctx->src_line_bytes);

                if (nonzero == 0U) {
                    ++stats.all_zero_lines;
                } else {
                    ++frame.nonzero_lines;
                }
                if (stats.last_line_hash != 0U && stats.last_line_hash != line_hash) {
                    ++frame.changed_lines;
                    ++stats.changed_lines;
                }
                stats.last_line_hash = line_hash;
                frame.frame_hash ^= line_hash + 0x9e3779b97f4a7c15ULL + (frame.frame_hash << 6U) + (frame.frame_hash >> 2U);
            }
        }

        if ((unsigned int)drm->mode.vdisplay > yres_use) {
            unsigned char *start = drm->map + (size_t)yres_use * drm->pitch;
            size_t sz = (size_t)((unsigned int)drm->mode.vdisplay - yres_use) * drm->pitch;
            memset(start, 0, sz);
        }

        if (ctx->debug_overlay) {
            draw_debug_overlay(drm, &frame, ctx->src_height, stats.frame_index);
        }

        ++stats.displayed_frames;
        if (frame.frame_hash == stats.last_frame_hash && stats.last_frame_hash != 0U) {
            ++stats.repeated_frame_hashes;
        } else {
            stats.repeated_frame_hashes = 0U;
        }
        stats.last_frame_hash = frame.frame_hash;

        if (ctx->dump_frames > 0U && stats.dumped_frames < ctx->dump_frames) {
            char path_buf[512];
            snprintf(path_buf, sizeof(path_buf), "%s_%04llu.ppm", ctx->dump_prefix, stats.dumped_frames + 1ULL);
            if (dump_frame_to_ppm(path_buf, drm, xres_use, yres_use) == 0) {
                ++stats.dumped_frames;
                fprintf(stdout, "[debug] dumped frame to %s\n", path_buf);
            }
        }

        report_debug_stats(ctx, drm, &stats, &frame, ctx->src_height);

        /*
         * 鍦ㄥ綋鍓嶆棤 VSYNC/甯у畬鎴愬弽棣堢殑閾捐矾涓嬶紝杞欢鑺傛祦榛樿鍏抽棴銆?         * 鍙湁鐢ㄦ埛鏄惧紡浼犲叆 --fps N 鏃舵墠鍋氶檺閫熴€?
         */
        sleep_for_fps(ctx->fps_limit);
    }

    dma_unmap(ctx->pcie_fd, &ctx->dma);
    return 0;
}

int main(int argc, char **argv)
{
    AppContext ctx;
    DrmOutput drm;
    int ret;

    memset(&ctx, 0, sizeof(ctx));
    ctx.pcie_fd = -1;
    ctx.pcie_path = "/dev/pango_pci_driver";
    ctx.drm_path = "/dev/dri/card0";
    ctx.connector_name = "HDMI-A-1";
    ctx.src_width = 1280;
    ctx.src_height = 720;
    ctx.src_line_bytes = 2560;
    ctx.src_format = SRC_FMT_RGB565;
    ctx.rgb565_order = RGB565_ORDER_NORMAL;
    ctx.fps_limit = 0;
    ctx.busy_wait_loop = 4000;
    ctx.dma_retries = 8;
    ctx.retry_sleep_us = 100;
    ctx.max_line_failures = 0;
    ctx.debug_enable = 0;
    ctx.debug_interval_sec = 1;
    ctx.debug_overlay = 0;
    ctx.dump_frames = 0;
    ctx.dump_prefix = "debug_frame";

    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--pcie") == 0 && i + 1 < argc) {
            ctx.pcie_path = argv[++i];
        } else if (strcmp(argv[i], "--drm") == 0 && i + 1 < argc) {
            ctx.drm_path = argv[++i];
        } else if (strcmp(argv[i], "--connector") == 0 && i + 1 < argc) {
            ctx.connector_name = argv[++i];
        } else if (strcmp(argv[i], "--width") == 0 && i + 1 < argc) {
            ctx.src_width = parse_u32(argv[++i], "width");
        } else if (strcmp(argv[i], "--height") == 0 && i + 1 < argc) {
            ctx.src_height = parse_u32(argv[++i], "height");
        } else if (strcmp(argv[i], "--line-bytes") == 0 && i + 1 < argc) {
            ctx.src_line_bytes = parse_u32(argv[++i], "line-bytes");
        } else if (strcmp(argv[i], "--src-format") == 0 && i + 1 < argc) {
            ctx.src_format = parse_src_format(argv[++i]);
        } else if (strcmp(argv[i], "--rgb565-order") == 0 && i + 1 < argc) {
            ctx.rgb565_order = parse_rgb565_order(argv[++i]);
        } else if (strcmp(argv[i], "--fps") == 0 && i + 1 < argc) {
            ctx.fps_limit = parse_u32(argv[++i], "fps");
        } else if (strcmp(argv[i], "--busy-wait") == 0 && i + 1 < argc) {
            ctx.busy_wait_loop = parse_u32(argv[++i], "busy-wait");
        } else if (strcmp(argv[i], "--dma-retries") == 0 && i + 1 < argc) {
            ctx.dma_retries = parse_u32(argv[++i], "dma-retries");
        } else if (strcmp(argv[i], "--retry-sleep-us") == 0 && i + 1 < argc) {
            ctx.retry_sleep_us = parse_u32(argv[++i], "retry-sleep-us");
        } else if (strcmp(argv[i], "--max-line-failures") == 0 && i + 1 < argc) {
            ctx.max_line_failures = parse_u32(argv[++i], "max-line-failures");
        } else if (strcmp(argv[i], "--debug") == 0) {
            ctx.debug_enable = 1;
            ctx.debug_overlay = 1;
        } else if (strcmp(argv[i], "--debug-interval") == 0 && i + 1 < argc) {
            ctx.debug_enable = 1;
            ctx.debug_interval_sec = parse_u32(argv[++i], "debug-interval");
        } else if (strcmp(argv[i], "--no-debug-overlay") == 0) {
            ctx.debug_overlay = 0;
        } else if (strcmp(argv[i], "--dump-frames") == 0 && i + 1 < argc) {
            ctx.debug_enable = 1;
            ctx.dump_frames = parse_u32(argv[++i], "dump-frames");
        } else if (strcmp(argv[i], "--dump-prefix") == 0 && i + 1 < argc) {
            ctx.dump_prefix = argv[++i];
        } else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            usage(argv[0]);
            return 0;
        } else {
            usage(argv[0]);
            return 2;
        }
    }

    signal(SIGINT, on_signal);
    signal(SIGTERM, on_signal);

    ctx.pcie_fd = open_pcie(ctx.pcie_path);
    if (ctx.pcie_fd < 0) {
        return 1;
    }

    if (drm_setup(&drm,
                  ctx.drm_path,
                  ctx.connector_name,
                  ctx.src_width,
                  ctx.src_height) != 0) {
        close(ctx.pcie_fd);
        return 1;
    }

    ret = run_pipeline(&ctx, &drm);

    drm_cleanup(&drm);
    close(ctx.pcie_fd);

    return ret == 0 ? 0 : 1;
}
