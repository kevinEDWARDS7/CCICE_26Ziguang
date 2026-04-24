#include <errno.h>
#include <fcntl.h>
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
#include "pango_pcie_ioctl.h"

#ifndef PCI_READ_DATA_CMD
#define PCI_READ_DATA_CMD _IOWR(PANGO_PCIE_IOCTL_TYPE, 0, int)
#endif
#ifndef PCI_SET_CONFIG
#define PCI_SET_CONFIG _IOWR(PANGO_PCIE_IOCTL_TYPE, 11, int)
#endif

#define DMA_MAX_PACKET_SIZE 4096U

typedef struct { unsigned char read_buf[DMA_MAX_PACKET_SIZE]; unsigned char write_buf[DMA_MAX_PACKET_SIZE]; } DMA_DATA;
typedef struct { unsigned int current_len; unsigned int offset_addr; unsigned int cmd; DMA_DATA data; } DMA_OPERATION;
typedef struct { unsigned long bar_base; unsigned long bar_len; } BAR_BASE_INFO;
typedef struct { unsigned int vendor_id, device_id, cmd_reg, status_reg, revision_id, class_prog, class_device; BAR_BASE_INFO bar[6]; unsigned int min_gnt, max_lat, link_speed, link_width, mps, mrrs, data[1024]; } PCI_DEVICE_INFO;
typedef struct { unsigned char w_r, step; unsigned int addr, data, cnt, delay; PCI_DEVICE_INFO get_pci_dev_info; } COMMAND_OPERATION;
typedef struct { int fd; uint32_t conn_id, crtc_id, fb_id, handle, pitch; uint64_t size; drmModeModeInfo mode; drmModeCrtc *orig; unsigned char *map; } DRM_OUT;

static volatile sig_atomic_t stop_flag;
static void on_sig(int s) { (void)s; stop_flag = 1; }
static unsigned int arg_u32(const char *s, const char *n) { char *e = NULL; unsigned long v = strtoul(s, &e, 10); if (!s[0] || !e || *e || v > 0xffffffffUL) { fprintf(stderr, "bad %s: %s\n", n, s); exit(2); } return (unsigned int)v; }
static unsigned int nonzero(const unsigned char *p, unsigned int n) { unsigned int c = 0; for (unsigned int i = 0; i < n; ++i) if (p[i]) ++c; return c; }
static uint64_t hash64(const unsigned char *p, unsigned int n) { uint64_t h = 1469598103934665603ULL; for (unsigned int i = 0; i < n; ++i) { h ^= p[i]; h *= 1099511628211ULL; } return h; }
static uint64_t mono_ns(void) { struct timespec t; if (clock_gettime(CLOCK_MONOTONIC, &t)) return 0; return (uint64_t)t.tv_sec * 1000000000ULL + (uint64_t)t.tv_nsec; }

static uint16_t get565(const unsigned char *line, unsigned int x, int byte_swap, int beat_reverse)
{
    unsigned int px = x;
    if (beat_reverse) { unsigned int b = (x / 8U) * 8U; px = b + (7U - (x % 8U)); }
    unsigned char lo = line[2U * px], hi = line[2U * px + 1U];
    if (byte_swap) { unsigned char t = lo; lo = hi; hi = t; }
    return (uint16_t)lo | ((uint16_t)hi << 8);
}

static void blit565(unsigned char *dst, const unsigned char *src, unsigned int pixels, int byte_swap, int beat_reverse)
{
    for (unsigned int x = 0; x < pixels; ++x) {
        uint16_t p = get565(src, x, byte_swap, beat_reverse);
        unsigned char r5 = (p >> 11) & 31, g6 = (p >> 5) & 63, b5 = p & 31;
        dst[4*x+0] = (unsigned char)((b5 << 3) | (b5 >> 2));
        dst[4*x+1] = (unsigned char)((g6 << 2) | (g6 >> 4));
        dst[4*x+2] = (unsigned char)((r5 << 3) | (r5 >> 2));
        dst[4*x+3] = 0;
    }
}

static int drm_init(DRM_OUT *o, const char *path, const char *connector, unsigned int w, unsigned int h)
{
    memset(o, 0, sizeof(*o)); o->fd = open(path, O_RDWR | O_CLOEXEC); if (o->fd < 0) { perror("open drm"); return -1; }
    drmModeRes *res = drmModeGetResources(o->fd); if (!res) { perror("drmModeGetResources"); return -1; }
    uint32_t enc_id = 0; int found = 0;
    for (int i = 0; i < res->count_connectors && !found; ++i) {
        drmModeConnector *c = drmModeGetConnector(o->fd, res->connectors[i]); if (!c) continue;
        char name[64]; snprintf(name, sizeof(name), "%s-%u", drmModeGetConnectorTypeName(c->connector_type), c->connector_type_id);
        if (c->connection == DRM_MODE_CONNECTED && c->count_modes && (!connector || !strcmp(name, connector))) {
            int pick = 0; for (int m = 0; m < c->count_modes; ++m) if ((unsigned)c->modes[m].hdisplay == w && (unsigned)c->modes[m].vdisplay == h) { pick = m; break; }
            o->conn_id = c->connector_id; enc_id = c->encoder_id ? c->encoder_id : (c->count_encoders ? c->encoders[0] : 0); o->mode = c->modes[pick]; found = 1;
        }
        drmModeFreeConnector(c);
    }
    if (!found) { fprintf(stderr, "no connector %s\n", connector ? connector : "<any>"); return -1; }
    drmModeEncoder *enc = enc_id ? drmModeGetEncoder(o->fd, enc_id) : NULL;
    if (enc && enc->crtc_id) o->crtc_id = enc->crtc_id; else if (res->count_crtcs) o->crtc_id = res->crtcs[0];
    if (enc) drmModeFreeEncoder(enc); drmModeFreeResources(res); if (!o->crtc_id) return -1;
    o->orig = drmModeGetCrtc(o->fd, o->crtc_id);
    struct drm_mode_create_dumb cr; memset(&cr, 0, sizeof(cr)); cr.width = o->mode.hdisplay; cr.height = o->mode.vdisplay; cr.bpp = 32;
    if (ioctl(o->fd, DRM_IOCTL_MODE_CREATE_DUMB, &cr)) { perror("CREATE_DUMB"); return -1; }
    o->handle = cr.handle; o->pitch = cr.pitch; o->size = cr.size;
    if (drmModeAddFB(o->fd, o->mode.hdisplay, o->mode.vdisplay, 24, 32, o->pitch, o->handle, &o->fb_id)) { perror("drmModeAddFB"); return -1; }
    struct drm_mode_map_dumb mr; memset(&mr, 0, sizeof(mr)); mr.handle = o->handle; if (ioctl(o->fd, DRM_IOCTL_MODE_MAP_DUMB, &mr)) { perror("MAP_DUMB"); return -1; }
    o->map = mmap(NULL, o->size, PROT_READ | PROT_WRITE, MAP_SHARED, o->fd, mr.offset); if (o->map == MAP_FAILED) { perror("mmap drm"); return -1; }
    memset(o->map, 0, o->size); if (drmModeSetCrtc(o->fd, o->crtc_id, o->fb_id, 0, 0, &o->conn_id, 1, &o->mode)) { perror("drmModeSetCrtc"); return -1; }
    return 0;
}

int main(int argc, char **argv)
{
    const char *pcie = "/dev/pango_pci_driver", *drm = "/dev/dri/card0", *conn = "HDMI-A-1";
    unsigned int width = 1280, height = 720, line_bytes = 2560, busy = 4000, fps = 0, map_per_frame = 1, debug = 0;
    int byte_swap = 0, beat_reverse = 0;
    for (int i = 1; i < argc; ++i) {
        if (!strcmp(argv[i], "--pcie") && i+1 < argc) pcie = argv[++i];
        else if (!strcmp(argv[i], "--drm") && i+1 < argc) drm = argv[++i];
        else if (!strcmp(argv[i], "--connector") && i+1 < argc) conn = argv[++i];
        else if (!strcmp(argv[i], "--width") && i+1 < argc) width = arg_u32(argv[++i], "width");
        else if (!strcmp(argv[i], "--height") && i+1 < argc) height = arg_u32(argv[++i], "height");
        else if (!strcmp(argv[i], "--line-bytes") && i+1 < argc) line_bytes = arg_u32(argv[++i], "line-bytes");
        else if (!strcmp(argv[i], "--busy-wait") && i+1 < argc) busy = arg_u32(argv[++i], "busy-wait");
        else if (!strcmp(argv[i], "--fps") && i+1 < argc) fps = arg_u32(argv[++i], "fps");
        else if (!strcmp(argv[i], "--map-per-frame") && i+1 < argc) map_per_frame = arg_u32(argv[++i], "map-per-frame");
        else if (!strcmp(argv[i], "--rgb565-order") && i+1 < argc) { const char *o = argv[++i]; byte_swap = strstr(o, "swap") != NULL; beat_reverse = strstr(o, "beat16") != NULL; }
        else if (!strcmp(argv[i], "--debug")) debug = 1;
        else { fprintf(stderr, "bad arg %s\n", argv[i]); return 2; }
    }
    if (line_bytes > DMA_MAX_PACKET_SIZE || (line_bytes & 3U) || line_bytes < width * 2U) { fprintf(stderr, "bad line-bytes\n"); return 2; }
    signal(SIGINT, on_sig); signal(SIGTERM, on_sig);
    int fd = open(pcie, O_RDWR); if (fd < 0) { perror("open pcie"); return 1; }
    DMA_OPERATION dma; memset(&dma, 0, sizeof(dma)); dma.current_len = line_bytes >> 2; dma.offset_addr = 0;
    COMMAND_OPERATION cmd; memset(&cmd, 0, sizeof(cmd));
    if (!ioctl(fd, PCI_READ_DATA_CMD, &cmd)) fprintf(stderr, "[pcie] vendor=0x%04x device=0x%04x gen%u x%u mps=%u\n", cmd.get_pci_dev_info.vendor_id, cmd.get_pci_dev_info.device_id, cmd.get_pci_dev_info.link_speed, cmd.get_pci_dev_info.link_width, cmd.get_pci_dev_info.mps);
    if (ioctl(fd, PCI_SET_CONFIG, &dma)) fprintf(stderr, "[pcie] PCI_SET_CONFIG warning: %s\n", strerror(errno));
    DRM_OUT out; if (drm_init(&out, drm, conn, width, height)) return 1;
    if (!map_per_frame && ioctl(fd, PCI_MAP_ADDR_CMD, &dma)) { perror("PCI_MAP_ADDR_CMD"); return 1; }
    uint64_t start = mono_ns(), last = 0, last_hash = 0, frame = 0;
    while (!stop_flag) {
        unsigned int ok = 0, fail = 0, zero = 0, changed = 0; uint64_t fh = 1469598103934665603ULL;
        if (map_per_frame && ioctl(fd, PCI_MAP_ADDR_CMD, &dma)) { perror("PCI_MAP_ADDR_CMD"); break; }
        for (unsigned int y = 0; y < height && !stop_flag; ++y) {
            memset(dma.data.read_buf, 0, line_bytes); dma.cmd = PCI_DMA_WRITE_CMD;
            if (ioctl(fd, PCI_DMA_WRITE_CMD, &dma)) { ++fail; continue; }
            for (volatile unsigned int k = 0; k < busy; ++k) {}
            if (ioctl(fd, PCI_READ_FROM_KERNEL_CMD, &dma)) { ++fail; continue; }
            ++ok; if (!nonzero(dma.data.read_buf, line_bytes)) ++zero;
            uint64_t lh = hash64(dma.data.read_buf, line_bytes); if (lh != last_hash) ++changed; last_hash = lh; fh ^= lh; fh *= 1099511628211ULL;
            if (y < (unsigned)out.mode.vdisplay) { unsigned int p = width < (unsigned)out.mode.hdisplay ? width : (unsigned)out.mode.hdisplay; blit565(out.map + (size_t)y * out.pitch, dma.data.read_buf, p, byte_swap, beat_reverse); }
        }
        if (map_per_frame) ioctl(fd, PCI_UMAP_ADDR_CMD, &dma);
        ++frame;
        if (debug) { uint64_t t = mono_ns(); if (!last || t - last > 1000000000ULL) { double s = (double)(t - start) / 1e9; fprintf(stdout, "[debug] frame=%llu fps=%.2f ok=%u fail=%u zero=%u changed=%u hash=0x%016llx\n", (unsigned long long)frame, frame/s, ok, fail, zero, changed, (unsigned long long)fh); fflush(stdout); last = t; } }
        if (fps) { struct timespec ts = {0, 1000000000L / (long)fps}; nanosleep(&ts, NULL); }
    }
    if (!map_per_frame) ioctl(fd, PCI_UMAP_ADDR_CMD, &dma);
    if (out.orig) { drmModeSetCrtc(out.fd, out.orig->crtc_id, out.orig->buffer_id, out.orig->x, out.orig->y, &out.conn_id, 1, &out.orig->mode); drmModeFreeCrtc(out.orig); }
    return 0;
}
