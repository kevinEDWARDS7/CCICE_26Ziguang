#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#if defined(__has_include)
#if __has_include(<execinfo.h>)
#define HAVE_EXECINFO 1
#include <execinfo.h>
#endif
#endif

#include <drm.h>
#include <drm_mode.h>
#include <drm_fourcc.h>
#include <xf86drm.h>
#include <xf86drmMode.h>

#include "pango_pcie_abi.h"

#define DEFAULT_DRM_CARD "/dev/dri/card0"
#define DEFAULT_FRAME_COUNT 0U
#define DEFAULT_DELAY_LOOPS 50000U
#define XRGB_ALPHA 0xff000000U

static volatile sig_atomic_t g_stop = 0;

struct app_options {
    const char *pcie_path;
    const char *drm_path;
    unsigned int input_width;
    unsigned int input_height;
    unsigned int line_bytes;
    unsigned int frame_count;
    unsigned int delay_loops;
    int no_display;
    const char *dump_frame_path;
    unsigned int dump_lines;
    int dma_sentinel_enabled;
    unsigned int dma_sentinel_byte;
    unsigned int dma_sync_timeout_us;
};

struct dumb_buffer {
    uint32_t handle;
    uint32_t fb_id;
    uint32_t width;
    uint32_t height;
    uint32_t pitch;
    uint64_t size;
    void *map;
};

struct drm_display {
    int fd;
    drmModeRes *res;
    drmModeConnector *conn;
    drmModeEncoder *enc;
    drmModeCrtc *old_crtc;
    uint32_t conn_id;
    uint32_t crtc_id;
    drmModeModeInfo mode;
    struct dumb_buffer buf;
};

static void on_signal(int signo)
{
    (void)signo;
    g_stop = 1;
}

static void crash_handler(int signo)
{
    fprintf(stderr, "fatal signal %d, dumping backtrace\n", signo);
#if defined(HAVE_EXECINFO)
    void *frames[32];
    int count = backtrace(frames, (int)(sizeof(frames) / sizeof(frames[0])));
    backtrace_symbols_fd(frames, count, STDERR_FILENO);
#else
    fprintf(stderr, "backtrace unavailable: execinfo.h not found at build time\n");
#endif
    signal(signo, SIG_DFL);
    raise(signo);
}

static void install_signal_handlers(void)
{
    struct sigaction sa;

    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = on_signal;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);

    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = crash_handler;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGSEGV, &sa, NULL);
    sigaction(SIGBUS, &sa, NULL);
    sigaction(SIGABRT, &sa, NULL);
}

static void usage(const char *prog)
{
    fprintf(stderr,
            "Usage: %s [options]\n"
            "\n"
            "Options:\n"
            "  --pcie PATH          PCIe character device. Default: %s\n"
            "  --drm PATH           DRM card device. Default: %s\n"
            "  --width N            Input image width. Default: %u\n"
            "  --height N           Input image height. Default: %u\n"
            "  --line-bytes N       Input line bytes. Default: %u\n"
            "  --frames N           Frames to display. 0 means run until Ctrl+C. Default: %u\n"
            "  --delay-loops N      Busy-wait loops before and after PCI_DMA_WRITE_CMD. Default: %u\n"
            "  --no-display         Read PCIe frames and print statistics without opening DRM.\n"
            "  --dump-frame PATH    Dump raw RGB565 bytes read from PCIe.\n"
            "  --dump-lines N       Dump only the first N lines. Default with --dump-frame: full frame.\n"
            "  --dma-sentinel N     Fill DMA target with byte N and wait until tail changes. Default: 0xa5\n"
            "  --no-dma-sentinel    Disable sentinel-based DMA sync polling.\n"
            "  --dma-sync-timeout-us N\n"
            "                       Timeout for sentinel polling. 0 uses driver default. Max: 65535\n"
            "  -h, --help           Show this help.\n",
            prog,
            PCIE_DRIVER_FILE_PATH,
            DEFAULT_DRM_CARD,
            IMAGE_WIDTH,
            IMAGE_HEIGHT,
            LINE_BYTES,
            DEFAULT_FRAME_COUNT,
            DEFAULT_DELAY_LOOPS);
}

static int parse_u32(const char *text, unsigned int *out)
{
    char *end = NULL;
    unsigned long value;

    if (!text || !out) {
        return -1;
    }

    errno = 0;
    value = strtoul(text, &end, 0);
    if (errno != 0 || end == text || *end != '\0' || value > 0xffffffffUL) {
        return -1;
    }

    *out = (unsigned int)value;
    return 0;
}

static int parse_args(int argc, char **argv, struct app_options *opts)
{
    if (!opts) {
        return -1;
    }

    opts->pcie_path = PCIE_DRIVER_FILE_PATH;
    opts->drm_path = DEFAULT_DRM_CARD;
    opts->input_width = IMAGE_WIDTH;
    opts->input_height = IMAGE_HEIGHT;
    opts->line_bytes = LINE_BYTES;
    opts->frame_count = DEFAULT_FRAME_COUNT;
    opts->delay_loops = DEFAULT_DELAY_LOOPS;
    opts->no_display = 0;
    opts->dump_frame_path = NULL;
    opts->dump_lines = 0U;
    opts->dma_sentinel_enabled = 1;
    opts->dma_sentinel_byte = 0xa5U;
    opts->dma_sync_timeout_us = 0U;

    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--pcie") == 0 && i + 1 < argc) {
            opts->pcie_path = argv[++i];
        } else if (strcmp(argv[i], "--drm") == 0 && i + 1 < argc) {
            opts->drm_path = argv[++i];
        } else if (strcmp(argv[i], "--width") == 0 && i + 1 < argc) {
            if (parse_u32(argv[++i], &opts->input_width) != 0) {
                return -1;
            }
        } else if (strcmp(argv[i], "--height") == 0 && i + 1 < argc) {
            if (parse_u32(argv[++i], &opts->input_height) != 0) {
                return -1;
            }
        } else if (strcmp(argv[i], "--line-bytes") == 0 && i + 1 < argc) {
            if (parse_u32(argv[++i], &opts->line_bytes) != 0) {
                return -1;
            }
        } else if (strcmp(argv[i], "--frames") == 0 && i + 1 < argc) {
            if (parse_u32(argv[++i], &opts->frame_count) != 0) {
                return -1;
            }
        } else if (strcmp(argv[i], "--delay-loops") == 0 && i + 1 < argc) {
            if (parse_u32(argv[++i], &opts->delay_loops) != 0) {
                return -1;
            }
        } else if (strcmp(argv[i], "--no-display") == 0) {
            opts->no_display = 1;
        } else if (strcmp(argv[i], "--dump-frame") == 0 && i + 1 < argc) {
            opts->dump_frame_path = argv[++i];
        } else if (strcmp(argv[i], "--dump-lines") == 0 && i + 1 < argc) {
            if (parse_u32(argv[++i], &opts->dump_lines) != 0) {
                return -1;
            }
        } else if (strcmp(argv[i], "--dma-sentinel") == 0 && i + 1 < argc) {
            if (parse_u32(argv[++i], &opts->dma_sentinel_byte) != 0) {
                return -1;
            }
            opts->dma_sentinel_enabled = 1;
        } else if (strcmp(argv[i], "--no-dma-sentinel") == 0) {
            opts->dma_sentinel_enabled = 0;
        } else if (strcmp(argv[i], "--dma-sync-timeout-us") == 0 && i + 1 < argc) {
            if (parse_u32(argv[++i], &opts->dma_sync_timeout_us) != 0) {
                return -1;
            }
        } else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            usage(argv[0]);
            exit(0);
        } else {
            return -1;
        }
    }

    if (opts->input_width == 0U || opts->input_height == 0U) {
        fprintf(stderr, "invalid input dimensions\n");
        return -1;
    }
    if (opts->line_bytes == 0U || opts->line_bytes > DMA_MAX_PACKET_SIZE) {
        fprintf(stderr, "line bytes must be in range 1..%u\n", DMA_MAX_PACKET_SIZE);
        return -1;
    }
    if ((opts->line_bytes % 4U) != 0U) {
        fprintf(stderr, "line bytes must be 4-byte aligned because the driver uses DWORD length\n");
        return -1;
    }
    if (opts->input_width > UINT_MAX / 2U || opts->line_bytes < opts->input_width * 2U)
    {
        fprintf(stderr, "line bytes must be at least width * 2 for RGB565 input\n");
        return -1;
    }
    if (opts->dump_lines > opts->input_height) {
        fprintf(stderr, "dump lines must be less than or equal to height\n");
        return -1;
    }
    if (opts->dma_sentinel_enabled && opts->dma_sentinel_byte > 0xffU) {
        fprintf(stderr, "DMA sentinel byte must be in range 0..255\n");
        return -1;
    }
    if (opts->dma_sync_timeout_us > 0xffffU) {
        fprintf(stderr, "DMA sync timeout must be in range 0..65535 us\n");
        return -1;
    }

    return 0;
}

static int pci_info_valid(const PCI_DEVICE_INFO *info)
{
    if (!info) {
        return 0;
    }
    if (info->vendor_id == 0U || info->device_id == 0U) {
        return 0;
    }
    if (info->link_speed == 0U || info->link_width == 0U) {
        return 0;
    }
    if (info->mps == 0U) {
        return 0;
    }
    return 1;
}

static void print_pci_info(const PCI_DEVICE_INFO *info)
{
    printf("PCIe: vendor=0x%04x device=0x%04x revision=0x%02x class=0x%04x prog=0x%02x\n",
           info->vendor_id,
           info->device_id,
           info->revision_id,
           info->class_device,
           info->class_prog);
    printf("PCIe: link=gen%u x%u mps=%u mrrs=%u cmd=0x%04x status=0x%04x\n",
           info->link_speed,
           info->link_width,
           info->mps,
           info->mrrs,
           info->cmd_reg,
           info->status_reg);
}

static int pcie_probe_or_fail(int fd)
{
    COMMAND_OPERATION cmd;

    memset(&cmd, 0, sizeof(cmd));

    if (ioctl(fd, PCI_READ_DATA_CMD, &cmd) < 0) {
        ssize_t n;

        fprintf(stderr, "PCI_READ_DATA_CMD failed, fallback to read(): %s\n", strerror(errno));
        n = read(fd, &cmd, sizeof(cmd));
        if (n <= 0) {
            fprintf(stderr, "read PCIe device info failed: %s\n", n < 0 ? strerror(errno) : "short read");
            return -1;
        }
        printf("PCIe probe read_return=%zd user_struct_size=%zu\n", n, sizeof(cmd));
    } else {
        printf("PCIe probe via PCI_READ_DATA_CMD OK, user_struct_size=%zu\n", sizeof(cmd));
    }

    print_pci_info(&cmd.get_pci_dev_info);

    if (!pci_info_valid(&cmd.get_pci_dev_info)) {
        fprintf(stderr,
                "PCIe probe invalid. Refuse DMA. Check FPGA bitstream, lspci, driver probe, and PCIe reset.\n");
        return -1;
    }

    return 0;
}

static int pcie_prepare_after_probe(int fd)
{
    DMA_OPERATION dma;
    COMMAND_OPERATION cmd;

    memset(&dma, 0, sizeof(dma));
    if (ioctl(fd, PCI_SET_CONFIG, &dma) < 0) {
        fprintf(stderr, "PCI_SET_CONFIG failed: %s\n", strerror(errno));
        return -1;
    }

    memset(&cmd, 0, sizeof(cmd));
    if (ioctl(fd, PCI_MAP_BAR0_CMD, &cmd) < 0) {
        fprintf(stderr, "PCI_MAP_BAR0_CMD failed: %s\n", strerror(errno));
        return -1;
    }

    printf("PCIe BAR0 base=0x%lx len=0x%lx\n",
           cmd.get_pci_dev_info.bar[0].bar_base,
           cmd.get_pci_dev_info.bar[0].bar_len);
    return 0;
}

static void busy_delay(unsigned int loops)
{
    for (volatile unsigned int k = 0; k < loops; ++k) {
    }
}

static int pcie_read_frame_rgb565(int fd, unsigned char *frame, const struct app_options *opts)
{
    int ret = -1;
    int mapped = 0;
    DMA_OPERATION *dma = NULL;

    if (!frame || !opts) {
        return -1;
    }

    dma = calloc(1, sizeof(*dma));
    if (!dma) {
        fprintf(stderr, "alloc DMA_OPERATION failed\n");
        return -1;
    }

    dma->current_len = opts->line_bytes / 4U;
    dma->offset_addr = 0U;
    if (opts->dma_sentinel_enabled) {
        dma->cmd = DMA_CMD_SENTINEL_ENABLE | (opts->dma_sentinel_byte & DMA_CMD_SENTINEL_MASK);
    }
    dma->cmd |= (opts->dma_sync_timeout_us << DMA_CMD_SYNC_TIMEOUT_SHIFT) & DMA_CMD_SYNC_TIMEOUT_MASK;
    memset(dma->data.write_buf, 0, DMA_MAX_PACKET_SIZE);
    memset(dma->data.read_buf, 0, DMA_MAX_PACKET_SIZE);

    if (ioctl(fd, PCI_MAP_ADDR_CMD, dma) < 0) {
        fprintf(stderr, "PCI_MAP_ADDR_CMD failed: %s\n", strerror(errno));
        goto out;
    }
    mapped = 1;

    for (unsigned int line = 0; line < opts->input_height; ++line) {
        if (g_stop) {
            ret = 1;
            goto out;
        }

        memset(dma->data.read_buf, 0, DMA_MAX_PACKET_SIZE);

        busy_delay(opts->delay_loops);

        /* Device writes one line into the kernel DMA buffer. */
        if (ioctl(fd, PCI_DMA_WRITE_CMD, dma) < 0) {
            fprintf(stderr, "PCI_DMA_WRITE_CMD failed at line %u: %s\n", line, strerror(errno));
            goto out;
        }

        busy_delay(opts->delay_loops);

        if (ioctl(fd, PCI_DMA_SYNC_CMD, dma) < 0)
        {
            fprintf(stderr, "PCI_DMA_SYNC_CMD failed at line %u: %s\n", line, strerror(errno));
            goto out;
        }

        if (ioctl(fd, PCI_READ_FROM_KERNEL_CMD, dma) < 0) {
            fprintf(stderr, "PCI_READ_FROM_KERNEL_CMD failed at line %u: %s\n", line, strerror(errno));
            goto out;
        }

        memcpy(frame + (size_t)line * opts->line_bytes, dma->data.read_buf, opts->line_bytes);
    }

    ret = 0;

out:
    if (mapped) {
        if (ioctl(fd, PCI_UMAP_ADDR_CMD, dma) < 0) {
            fprintf(stderr, "PCI_UMAP_ADDR_CMD failed: %s\n", strerror(errno));
            if (ret == 0) {
                ret = -1;
            }
        }
    }
    free(dma);
    return ret;
}

static void print_hex_bytes(const unsigned char *data, size_t count)
{
    for (size_t i = 0; i < count; ++i) {
        printf("%02x%s", data[i], ((i + 1U) == count) ? "" : " ");
    }
}

static void print_line_pixels(const char *label,
                              const unsigned char *frame,
                              unsigned int line,
                              const struct app_options *opts)
{
    if (line >= opts->input_height) {
        return;
    }

    const unsigned char *row = frame + (size_t)line * opts->line_bytes;
    unsigned int pixels = opts->input_width < 16U ? opts->input_width : 16U;

    printf("%s first_%u_rgb565:", label, pixels);
    for (unsigned int x = 0; x < pixels; ++x) {
        const unsigned char *p = row + (size_t)x * 2U;
        uint16_t rgb565 = (uint16_t)p[0] | ((uint16_t)p[1] << 8);
        printf(" %04x", rgb565);
    }
    printf("\n");
}

static void print_line_samples(const unsigned char *frame, const struct app_options *opts)
{
    const unsigned char *row = frame;
    unsigned int samples = opts->input_width < 16U ? opts->input_width : 16U;

    printf("line0 sampled_rgb565:");
    for (unsigned int i = 0; i < samples; ++i) {
        unsigned int x = (unsigned int)(((uint64_t)i * opts->input_width) / samples);
        if (x >= opts->input_width) {
            x = opts->input_width - 1U;
        }
        const unsigned char *p = row + (size_t)x * 2U;
        uint16_t rgb565 = (uint16_t)p[0] | ((uint16_t)p[1] << 8);
        printf(" x%u=%04x", x, rgb565);
    }
    printf("\n");
}

static int dump_frame_if_requested(const unsigned char *frame,
                                   size_t frame_bytes,
                                   const struct app_options *opts)
{
    FILE *fp;
    size_t dump_bytes;
    unsigned int lines;

    if (!opts->dump_frame_path) {
        return 0;
    }

    lines = opts->dump_lines == 0U ? opts->input_height : opts->dump_lines;
    dump_bytes = (size_t)lines * opts->line_bytes;
    if (dump_bytes > frame_bytes) {
        dump_bytes = frame_bytes;
    }

    fp = fopen(opts->dump_frame_path, "wb");
    if (!fp) {
        fprintf(stderr, "open dump frame %s failed: %s\n", opts->dump_frame_path, strerror(errno));
        return -1;
    }
    if (fwrite(frame, 1U, dump_bytes, fp) != dump_bytes) {
        fprintf(stderr, "write dump frame %s failed: %s\n", opts->dump_frame_path, strerror(errno));
        fclose(fp);
        return -1;
    }
    if (fclose(fp) != 0) {
        fprintf(stderr, "close dump frame %s failed: %s\n", opts->dump_frame_path, strerror(errno));
        return -1;
    }

    printf("dump_path=%s dump_bytes=%zu\n", opts->dump_frame_path, dump_bytes);
    return 0;
}

static void print_frame_stats(const unsigned char *frame, size_t frame_bytes, const struct app_options *opts)
{
    size_t nonzero_bytes = 0U;
    size_t sentinel_bytes = 0U;
    size_t first_count = frame_bytes < 64U ? frame_bytes : 64U;
    unsigned int lines = opts->dump_lines == 0U ? opts->input_height : opts->dump_lines;
    size_t dump_bytes = (size_t)lines * opts->line_bytes;

    if (dump_bytes > frame_bytes) {
        dump_bytes = frame_bytes;
    }

    for (size_t i = 0; i < frame_bytes; ++i) {
        if (frame[i] != 0U) {
            ++nonzero_bytes;
        }
        if (opts->dma_sentinel_enabled && frame[i] == (unsigned char)opts->dma_sentinel_byte) {
            ++sentinel_bytes;
        }
    }

    printf("frame_bytes=%zu dump_bytes=%zu nonzero_bytes=%zu\n",
           frame_bytes,
           dump_bytes,
           nonzero_bytes);
    if (opts->dma_sentinel_enabled) {
        printf("dma_sentinel=0x%02x sentinel_bytes=%zu\n",
               opts->dma_sentinel_byte & 0xffU,
               sentinel_bytes);
    }
    printf("first_64_bytes:");
    if (first_count > 0U) {
        printf(" ");
        print_hex_bytes(frame, first_count);
    }
    printf("\n");
    print_line_pixels("line0", frame, 0U, opts);
    print_line_pixels("line1", frame, 1U, opts);
    print_line_samples(frame, opts);
}

static uint32_t rgb565_to_xrgb8888(uint16_t p)
{
    uint32_t r5 = (p >> 11) & 0x1fU;
    uint32_t g6 = (p >> 5) & 0x3fU;
    uint32_t b5 = p & 0x1fU;

    uint32_t r8 = (r5 << 3) | (r5 >> 2);
    uint32_t g8 = (g6 << 2) | (g6 >> 4);
    uint32_t b8 = (b5 << 3) | (b5 >> 2);

    return XRGB_ALPHA | (r8 << 16) | (g8 << 8) | b8;
}

static void blit_rgb565_to_xrgb8888_scaled(const unsigned char *src,
                                           unsigned int src_width,
                                           unsigned int src_height,
                                           unsigned int src_line_bytes,
                                           void *dst_map,
                                           unsigned int dst_width,
                                           unsigned int dst_height,
                                           unsigned int dst_pitch)
{
    uint8_t *dst = (uint8_t *)dst_map;

    for (unsigned int y = 0; y < dst_height; ++y) {
        unsigned int sy = (unsigned int)(((uint64_t)y * src_height) / dst_height);
        const unsigned char *src_line = src + (size_t)sy * src_line_bytes;
        uint32_t *dst_line = (uint32_t *)(void *)(dst + (size_t)y * dst_pitch);

        for (unsigned int x = 0; x < dst_width; ++x) {
            unsigned int sx = (unsigned int)(((uint64_t)x * src_width) / dst_width);
            const unsigned char *sp = src_line + (size_t)sx * 2U;
            uint16_t rgb565 = (uint16_t)sp[0] | ((uint16_t)sp[1] << 8);
            dst_line[x] = rgb565_to_xrgb8888(rgb565);
        }
    }
}

static drmModeModeInfo choose_mode(const drmModeConnector *conn, unsigned int want_w, unsigned int want_h)
{
    drmModeModeInfo fallback = conn->modes[0];

    for (int i = 0; i < conn->count_modes; ++i) {
        const drmModeModeInfo *m = &conn->modes[i];
        if ((unsigned int)m->hdisplay == want_w && (unsigned int)m->vdisplay == want_h) {
            return *m;
        }
    }

    for (int i = 0; i < conn->count_modes; ++i) {
        if (conn->modes[i].type & DRM_MODE_TYPE_PREFERRED) {
            return conn->modes[i];
        }
    }

    return fallback;
}

static drmModeEncoder *find_encoder_for_connector(int fd, drmModeRes *res, drmModeConnector *conn)
{
    drmModeEncoder *enc = NULL;

    if (conn->encoder_id) {
        enc = drmModeGetEncoder(fd, conn->encoder_id);
        if (enc) {
            return enc;
        }
    }

    for (int i = 0; i < conn->count_encoders; ++i) {
        enc = drmModeGetEncoder(fd, conn->encoders[i]);
        if (!enc) {
            continue;
        }

        for (int j = 0; j < res->count_crtcs; ++j) {
            if (enc->possible_crtcs & (1U << j)) {
                return enc;
            }
        }

        drmModeFreeEncoder(enc);
    }

    return NULL;
}

static uint32_t choose_crtc_id(drmModeRes *res, const drmModeEncoder *enc)
{
    if (!res || !enc) {
        return 0U;
    }

    if (enc->crtc_id) {
        return enc->crtc_id;
    }

    for (int i = 0; i < res->count_crtcs; ++i) {
        if (enc->possible_crtcs & (1U << i)) {
            return res->crtcs[i];
        }
    }

    return 0U;
}

static int create_dumb_buffer(int fd, struct dumb_buffer *buf, unsigned int width, unsigned int height)
{
    struct drm_mode_create_dumb creq;
    struct drm_mode_map_dumb mreq;

    memset(buf, 0, sizeof(*buf));
    memset(&creq, 0, sizeof(creq));
    creq.width = width;
    creq.height = height;
    creq.bpp = 32;

    if (ioctl(fd, DRM_IOCTL_MODE_CREATE_DUMB, &creq) < 0) {
        fprintf(stderr, "DRM_IOCTL_MODE_CREATE_DUMB failed: %s\n", strerror(errno));
        return -1;
    }

    buf->handle = creq.handle;
    buf->width = creq.width;
    buf->height = creq.height;
    buf->pitch = creq.pitch;
    buf->size = creq.size;

    if (drmModeAddFB(fd, buf->width, buf->height, 24, 32, buf->pitch, buf->handle, &buf->fb_id) != 0) {
        fprintf(stderr, "drmModeAddFB failed: %s\n", strerror(errno));
        struct drm_mode_destroy_dumb dreq;
        memset(&dreq, 0, sizeof(dreq));
        dreq.handle = buf->handle;
        ioctl(fd, DRM_IOCTL_MODE_DESTROY_DUMB, &dreq);
        memset(buf, 0, sizeof(*buf));
        return -1;
    }

    memset(&mreq, 0, sizeof(mreq));
    mreq.handle = buf->handle;
    if (ioctl(fd, DRM_IOCTL_MODE_MAP_DUMB, &mreq) < 0) {
        fprintf(stderr, "DRM_IOCTL_MODE_MAP_DUMB failed: %s\n", strerror(errno));
        drmModeRmFB(fd, buf->fb_id);
        struct drm_mode_destroy_dumb dreq;
        memset(&dreq, 0, sizeof(dreq));
        dreq.handle = buf->handle;
        ioctl(fd, DRM_IOCTL_MODE_DESTROY_DUMB, &dreq);
        memset(buf, 0, sizeof(*buf));
        return -1;
    }

    buf->map = mmap(NULL, buf->size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, mreq.offset);
    if (buf->map == MAP_FAILED) {
        fprintf(stderr, "mmap dumb buffer failed: %s\n", strerror(errno));
        buf->map = NULL;
        drmModeRmFB(fd, buf->fb_id);
        struct drm_mode_destroy_dumb dreq;
        memset(&dreq, 0, sizeof(dreq));
        dreq.handle = buf->handle;
        ioctl(fd, DRM_IOCTL_MODE_DESTROY_DUMB, &dreq);
        memset(buf, 0, sizeof(*buf));
        return -1;
    }

    memset(buf->map, 0, buf->size);
    return 0;
}

static void destroy_dumb_buffer(int fd, struct dumb_buffer *buf)
{
    if (!buf) {
        return;
    }

    if (buf->map) {
        munmap(buf->map, buf->size);
        buf->map = NULL;
    }
    if (buf->fb_id) {
        drmModeRmFB(fd, buf->fb_id);
        buf->fb_id = 0;
    }
    if (buf->handle) {
        struct drm_mode_destroy_dumb dreq;
        memset(&dreq, 0, sizeof(dreq));
        dreq.handle = buf->handle;
        ioctl(fd, DRM_IOCTL_MODE_DESTROY_DUMB, &dreq);
        buf->handle = 0;
    }
}

static int drm_display_open(struct drm_display *display,
                            const char *drm_path,
                            unsigned int want_w,
                            unsigned int want_h)
{
    memset(display, 0, sizeof(*display));
    display->fd = -1;

    display->fd = open(drm_path, O_RDWR | O_CLOEXEC);
    if (display->fd < 0) {
        fprintf(stderr, "open DRM device %s failed: %s\n", drm_path, strerror(errno));
        return -1;
    }

    display->res = drmModeGetResources(display->fd);
    if (!display->res) {
        fprintf(stderr, "drmModeGetResources failed: %s\n", strerror(errno));
        close(display->fd);
        display->fd = -1;
        return -1;
    }

    for (int i = 0; i < display->res->count_connectors; ++i) {
        drmModeConnector *conn = drmModeGetConnector(display->fd, display->res->connectors[i]);
        if (!conn) {
            continue;
        }

        if (conn->connection == DRM_MODE_CONNECTED && conn->count_modes > 0) {
            display->conn = conn;
            break;
        }

        drmModeFreeConnector(conn);
    }

    if (!display->conn) {
        fprintf(stderr, "no connected DRM connector with display mode found\n");
        return -1;
    }

    display->conn_id = display->conn->connector_id;
    display->mode = choose_mode(display->conn, want_w, want_h);
    display->enc = find_encoder_for_connector(display->fd, display->res, display->conn);
    if (!display->enc) {
        fprintf(stderr, "no usable DRM encoder found for connector %u\n", display->conn_id);
        return -1;
    }

    display->crtc_id = choose_crtc_id(display->res, display->enc);
    if (display->crtc_id == 0U) {
        fprintf(stderr, "no usable DRM CRTC found\n");
        return -1;
    }

    display->old_crtc = drmModeGetCrtc(display->fd, display->crtc_id);

    if (create_dumb_buffer(display->fd,
                           &display->buf,
                           display->mode.hdisplay,
                           display->mode.vdisplay) != 0) {
        return -1;
    }

    if (drmModeSetCrtc(display->fd,
                       display->crtc_id,
                       display->buf.fb_id,
                       0,
                       0,
                       &display->conn_id,
                       1,
                       &display->mode) != 0) {
        fprintf(stderr, "drmModeSetCrtc failed: %s\n", strerror(errno));
        fprintf(stderr, "This usually means another compositor owns DRM master. Stop desktop/display service or run on a VT.\n");
        return -1;
    }

    printf("DRM: card=%s connector=%u crtc=%u mode=%ux%u pitch=%u\n",
           drm_path,
           display->conn_id,
           display->crtc_id,
           display->buf.width,
           display->buf.height,
           display->buf.pitch);

    return 0;
}

static void drm_display_close(struct drm_display *display)
{
    if (!display) {
        return;
    }

    if (display->fd >= 0 && display->old_crtc) {
        drmModeSetCrtc(display->fd,
                       display->old_crtc->crtc_id,
                       display->old_crtc->buffer_id,
                       display->old_crtc->x,
                       display->old_crtc->y,
                       &display->conn_id,
                       1,
                       &display->old_crtc->mode);
    }

    if (display->fd >= 0) {
        destroy_dumb_buffer(display->fd, &display->buf);
    }
    if (display->old_crtc) {
        drmModeFreeCrtc(display->old_crtc);
        display->old_crtc = NULL;
    }
    if (display->enc) {
        drmModeFreeEncoder(display->enc);
        display->enc = NULL;
    }
    if (display->conn) {
        drmModeFreeConnector(display->conn);
        display->conn = NULL;
    }
    if (display->res) {
        drmModeFreeResources(display->res);
        display->res = NULL;
    }
    if (display->fd >= 0) {
        close(display->fd);
        display->fd = -1;
    }
}

int main(int argc, char **argv)
{
    struct app_options opts;
    struct drm_display display;
    unsigned char *frame_rgb565 = NULL;
    size_t frame_bytes;
    unsigned int frame_index = 0;
    int pcie_fd = -1;
    int ret = 1;

    memset(&display, 0, sizeof(display));
    display.fd = -1;

    if (parse_args(argc, argv, &opts) != 0) {
        usage(argv[0]);
        return 2;
    }

    install_signal_handlers();

    if (opts.input_height != 0U && (size_t)opts.line_bytes > SIZE_MAX / opts.input_height)
    {
        fprintf(stderr, "frame buffer size overflow: line_bytes=%u height=%u\n",
                opts.line_bytes,
                opts.input_height);
        return 1;
    }

    frame_bytes = (size_t)opts.line_bytes * opts.input_height;
    frame_rgb565 = malloc(frame_bytes);
    if (!frame_rgb565) {
        fprintf(stderr, "alloc RGB565 frame buffer failed, bytes=%zu\n", frame_bytes);
        return 1;
    }
    memset(frame_rgb565, 0, frame_bytes);

    pcie_fd = open(opts.pcie_path, O_RDWR);
    if (pcie_fd < 0) {
        fprintf(stderr, "open PCIe device %s failed: %s\n", opts.pcie_path, strerror(errno));
        goto out;
    }

    if (pcie_probe_or_fail(pcie_fd) != 0) {
        goto out;
    }

    if (pcie_prepare_after_probe(pcie_fd) != 0) {
        goto out;
    }

    if (!opts.no_display) {
        if (drm_display_open(&display, opts.drm_path, opts.input_width, opts.input_height) != 0) {
            goto out;
        }
    }

    printf("Start %s loop: input=%ux%u line_bytes=%u frames=%u delay_loops=%u\n",
           opts.no_display ? "capture" : "display",
           opts.input_width,
           opts.input_height,
           opts.line_bytes,
           opts.frame_count,
           opts.delay_loops);

    while (!g_stop) {
        int fr = pcie_read_frame_rgb565(pcie_fd, frame_rgb565, &opts);
        if (fr < 0) {
            fprintf(stderr, "read frame failed\n");
            break;
        }
        if (fr > 0) {
            break;
        }

        if (opts.no_display || opts.dump_frame_path) {
            print_frame_stats(frame_rgb565, frame_bytes, &opts);
            if (dump_frame_if_requested(frame_rgb565, frame_bytes, &opts) != 0) {
                break;
            }
        }

        if (!opts.no_display) {
            blit_rgb565_to_xrgb8888_scaled(frame_rgb565,
                                           opts.input_width,
                                           opts.input_height,
                                           opts.line_bytes,
                                           display.buf.map,
                                           display.buf.width,
                                           display.buf.height,
                                           display.buf.pitch);
        }

        ++frame_index;
        if (!opts.no_display && (frame_index % 30U) == 0U) {
            printf("displayed %u frames\n", frame_index);
            fflush(stdout);
        }

        if (opts.frame_count != 0U && frame_index >= opts.frame_count) {
            break;
        }
    }

    printf("Exit %s loop, frames=%u\n", opts.no_display ? "capture" : "display", frame_index);
    ret = 0;

out:
    drm_display_close(&display);
    if (pcie_fd >= 0) {
        close(pcie_fd);
    }
    free(frame_rgb565);
    return ret;
}
