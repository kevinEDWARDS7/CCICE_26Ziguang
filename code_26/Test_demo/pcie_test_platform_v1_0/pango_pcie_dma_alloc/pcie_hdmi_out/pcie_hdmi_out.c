#include <errno.h>
#include <fcntl.h>
#include <linux/fb.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#define TYPE 'S'
#define PCI_MAP_ADDR_CMD _IOWR(TYPE, 2, int)
#define PCI_DMA_WRITE_CMD _IOWR(TYPE, 5, int)
#define PCI_READ_FROM_KERNEL_CMD _IOWR(TYPE, 6, int)
#define PCI_UMAP_ADDR_CMD _IOWR(TYPE, 7, int)

#define DMA_MAX_PACKET_SIZE 4096

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

typedef struct {
    int fb_fd;
    struct fb_fix_screeninfo fix;
    struct fb_var_screeninfo var;
    unsigned char *fb_base;
    size_t fb_size;
} FbDevice;

typedef struct {
    int pcie_fd;
    DMA_OPERATION dma;
    FbDevice fb;
    unsigned int src_width;
    unsigned int src_height;
    unsigned int src_line_bytes;
    SrcPixelFormat src_format;
    unsigned int fps_limit;
    unsigned int busy_wait_loop;
} AppContext;

static volatile sig_atomic_t g_stop = 0;

static void on_signal(int signo)
{
    (void)signo;
    g_stop = 1;
}

static int open_fb(FbDevice *fb, const char *fb_path)
{
    memset(fb, 0, sizeof(*fb));

    fb->fb_fd = open(fb_path, O_RDWR);
    if (fb->fb_fd < 0) {
        perror("open fb");
        return -1;
    }

    if (ioctl(fb->fb_fd, FBIOGET_FSCREENINFO, &fb->fix) != 0) {
        perror("FBIOGET_FSCREENINFO");
        close(fb->fb_fd);
        return -1;
    }

    if (ioctl(fb->fb_fd, FBIOGET_VSCREENINFO, &fb->var) != 0) {
        perror("FBIOGET_VSCREENINFO");
        close(fb->fb_fd);
        return -1;
    }

    fb->fb_size = (size_t)fb->fix.line_length * fb->var.yres_virtual;
    fb->fb_base = (unsigned char *)mmap(NULL, fb->fb_size, PROT_READ | PROT_WRITE, MAP_SHARED, fb->fb_fd, 0);
    if (fb->fb_base == MAP_FAILED) {
        perror("mmap fb");
        close(fb->fb_fd);
        return -1;
    }

    fprintf(stdout,
            "FB: %ux%u, bpp=%u, line_length=%u, R(%u,%u) G(%u,%u) B(%u,%u)\n",
            fb->var.xres,
            fb->var.yres,
            fb->var.bits_per_pixel,
            fb->fix.line_length,
            fb->var.red.offset,
            fb->var.red.length,
            fb->var.green.offset,
            fb->var.green.length,
            fb->var.blue.offset,
            fb->var.blue.length);

    return 0;
}

static void close_fb(FbDevice *fb)
{
    if (fb->fb_base && fb->fb_base != MAP_FAILED) {
        munmap(fb->fb_base, fb->fb_size);
    }
    if (fb->fb_fd >= 0) {
        close(fb->fb_fd);
    }
    memset(fb, 0, sizeof(*fb));
}

static inline uint32_t scale_8_to_n(uint8_t v, uint32_t n)
{
    if (n >= 8U) {
        return (uint32_t)v << (n - 8U);
    }
    return (uint32_t)(v >> (8U - n));
}

static const char *src_fmt_name(SrcPixelFormat fmt)
{
    return (fmt == SRC_FMT_RGB888) ? "RGB888" : "RGB565";
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

static inline void rgb565_to_rgb888(uint16_t p, uint8_t *r, uint8_t *g, uint8_t *b)
{
    uint8_t r5 = (uint8_t)((p >> 11) & 0x1F);
    uint8_t g6 = (uint8_t)((p >> 5) & 0x3F);
    uint8_t b5 = (uint8_t)(p & 0x1F);

    *r = (uint8_t)((r5 << 3) | (r5 >> 2));
    *g = (uint8_t)((g6 << 2) | (g6 >> 4));
    *b = (uint8_t)((b5 << 3) | (b5 >> 2));
}

static inline uint32_t pack_rgb_to_fb(const FbDevice *fb, uint8_t r8, uint8_t g8, uint8_t b8)
{
    uint32_t packed = 0;
    packed |= scale_8_to_n(r8, fb->var.red.length) << fb->var.red.offset;
    packed |= scale_8_to_n(g8, fb->var.green.length) << fb->var.green.offset;
    packed |= scale_8_to_n(b8, fb->var.blue.length) << fb->var.blue.offset;
    return packed;
}

static void blit_line_rgb565_to_fb(const FbDevice *fb,
                                   const unsigned char *src_line,
                                   unsigned char *dst_line,
                                   unsigned int pixel_count)
{
    unsigned int x;
    unsigned int bpp = fb->var.bits_per_pixel;
    unsigned int bytes_per_pixel = bpp / 8U;

    if (bpp == 16U &&
        fb->var.red.offset == 11U && fb->var.red.length == 5U &&
        fb->var.green.offset == 5U && fb->var.green.length == 6U &&
        fb->var.blue.offset == 0U && fb->var.blue.length == 5U) {
        memcpy(dst_line, src_line, pixel_count * 2U);
        return;
    }

    for (x = 0; x < pixel_count; ++x) {
        uint16_t p565 = (uint16_t)src_line[2U * x] | ((uint16_t)src_line[2U * x + 1U] << 8);
        uint8_t r8;
        uint8_t g8;
        uint8_t b8;
        uint32_t packed;

        rgb565_to_rgb888(p565, &r8, &g8, &b8);
        packed = pack_rgb_to_fb(fb, r8, g8, b8);

        memcpy(dst_line + x * bytes_per_pixel, &packed, bytes_per_pixel);
    }
}

static void blit_line_rgb888_to_fb(const FbDevice *fb,
                                   const unsigned char *src_line,
                                   unsigned char *dst_line,
                                   unsigned int pixel_count)
{
    unsigned int bytes_per_pixel = fb->var.bits_per_pixel / 8U;

    for (unsigned int x = 0; x < pixel_count; ++x) {
        uint8_t r8 = src_line[3U * x];
        uint8_t g8 = src_line[3U * x + 1U];
        uint8_t b8 = src_line[3U * x + 2U];
        uint32_t packed = pack_rgb_to_fb(fb, r8, g8, b8);
        memcpy(dst_line + x * bytes_per_pixel, &packed, bytes_per_pixel);
    }
}

static int open_pcie(const char *pcie_path)
{
    int fd = open(pcie_path, O_RDWR);
    if (fd < 0) {
        perror("open pcie");
        return -1;
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

static void dma_unmap(int fd, DMA_OPERATION *dma)
{
    if (fd >= 0) {
        (void)ioctl(fd, PCI_UMAP_ADDR_CMD, dma);
    }
}

static int recv_one_line(int fd, DMA_OPERATION *dma, unsigned int busy_wait_loop)
{
    if (ioctl(fd, PCI_DMA_WRITE_CMD, dma) != 0) {
        perror("PCI_DMA_WRITE_CMD");
        return -1;
    }

    for (volatile unsigned int i = 0; i < busy_wait_loop; ++i) {
    }

    if (ioctl(fd, PCI_READ_FROM_KERNEL_CMD, dma) != 0) {
        perror("PCI_READ_FROM_KERNEL_CMD");
        return -1;
    }

    return 0;
}

static void sleep_for_fps(unsigned int fps)
{
    struct timespec ts;

    if (fps == 0U) {
        return;
    }

    ts.tv_sec = 0;
    ts.tv_nsec = 1000000000L / (long)fps;
    (void)nanosleep(&ts, NULL);
}

static int run_pipeline(AppContext *ctx)
{
    unsigned int xres_use = ctx->src_width < ctx->fb.var.xres ? ctx->src_width : ctx->fb.var.xres;
    unsigned int yres_use = ctx->src_height < ctx->fb.var.yres ? ctx->src_height : ctx->fb.var.yres;
    unsigned int y;
    unsigned int src_bytes_pp;
    unsigned int expected_line_bytes;

    if (ctx->src_line_bytes > DMA_MAX_PACKET_SIZE) {
        fprintf(stderr, "line-bytes %u exceeds DMA_MAX_PACKET_SIZE %u\n", ctx->src_line_bytes, DMA_MAX_PACKET_SIZE);
        return -1;
    }

    src_bytes_pp = (ctx->src_format == SRC_FMT_RGB888) ? 3U : 2U;
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

    if ((ctx->src_line_bytes % 4U) != 0U || ctx->dma.current_len == 0U) {
        fprintf(stderr, "line-bytes must be non-zero and 4-byte aligned\n");
        return -1;
    }

    if (dma_map(ctx->pcie_fd, &ctx->dma) != 0) {
        return -1;
    }

    fprintf(stdout,
            "start: src=%ux%u %s, blit=%ux%u, fps_limit=%u, busy_wait=%u\n",
            ctx->src_width,
            ctx->src_height,
            src_fmt_name(ctx->src_format),
            xres_use,
            yres_use,
            ctx->fps_limit,
            ctx->busy_wait_loop);

    while (!g_stop) {
        for (y = 0; y < yres_use; ++y) {
            unsigned char *dst_line = ctx->fb.fb_base + y * ctx->fb.fix.line_length;
            if (recv_one_line(ctx->pcie_fd, &ctx->dma, ctx->busy_wait_loop) != 0) {
                dma_unmap(ctx->pcie_fd, &ctx->dma);
                return -1;
            }
            if (ctx->src_format == SRC_FMT_RGB888) {
                blit_line_rgb888_to_fb(&ctx->fb, ctx->dma.data.read_buf, dst_line, xres_use);
            } else {
                blit_line_rgb565_to_fb(&ctx->fb, ctx->dma.data.read_buf, dst_line, xres_use);
            }
        }

        for (; y < ctx->src_height; ++y) {
            if (recv_one_line(ctx->pcie_fd, &ctx->dma, ctx->busy_wait_loop) != 0) {
                dma_unmap(ctx->pcie_fd, &ctx->dma);
                return -1;
            }
        }

        sleep_for_fps(ctx->fps_limit);
    }

    dma_unmap(ctx->pcie_fd, &ctx->dma);
    return 0;
}

static unsigned int parse_u32(const char *s, const char *name)
{
    char *end = NULL;
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

static void usage(const char *prog)
{
    fprintf(stderr,
            "Usage: %s [--pcie /dev/pango_pci_driver] [--fb /dev/fb0]"
            " [--width 1280] [--height 720] [--line-bytes 2560] [--src-format rgb565]"
            " [--fps 0] [--busy-wait 4000]\n",
            prog);
}

int main(int argc, char **argv)
{
    const char *pcie_path = "/dev/pango_pci_driver";
    const char *fb_path   = "/dev/fb0";
    AppContext ctx;
    int i;
    int ret;

    memset(&ctx, 0, sizeof(ctx));
    ctx.pcie_fd = -1;
    ctx.fb.fb_fd = -1;
    ctx.src_width = 1280;
    ctx.src_height = 720;
    ctx.src_line_bytes = 2560;
    ctx.src_format = SRC_FMT_RGB565;
    ctx.fps_limit = 0;
    ctx.busy_wait_loop = 4000;

    for (i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--pcie") == 0 && i + 1 < argc) {
            pcie_path = argv[++i];
        } else if (strcmp(argv[i], "--fb") == 0 && i + 1 < argc) {
            fb_path = argv[++i];
        } else if (strcmp(argv[i], "--width") == 0 && i + 1 < argc) {
            ctx.src_width = parse_u32(argv[++i], "width");
        } else if (strcmp(argv[i], "--height") == 0 && i + 1 < argc) {
            ctx.src_height = parse_u32(argv[++i], "height");
        } else if (strcmp(argv[i], "--line-bytes") == 0 && i + 1 < argc) {
            ctx.src_line_bytes = parse_u32(argv[++i], "line-bytes");
        } else if (strcmp(argv[i], "--src-format") == 0 && i + 1 < argc) {
            ctx.src_format = parse_src_format(argv[++i]);
        } else if (strcmp(argv[i], "--fps") == 0 && i + 1 < argc) {
            ctx.fps_limit = parse_u32(argv[++i], "fps");
        } else if (strcmp(argv[i], "--busy-wait") == 0 && i + 1 < argc) {
            ctx.busy_wait_loop = parse_u32(argv[++i], "busy-wait");
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

    ctx.pcie_fd = open_pcie(pcie_path);
    if (ctx.pcie_fd < 0) {
        return 1;
    }

    if (open_fb(&ctx.fb, fb_path) != 0) {
        close(ctx.pcie_fd);
        return 1;
    }

    ret = run_pipeline(&ctx);

    close_fb(&ctx.fb);
    close(ctx.pcie_fd);

    if (ret != 0) {
        return 1;
    }

    return 0;
}
