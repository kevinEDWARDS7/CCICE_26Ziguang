# PCIe To HDMI OUT (RK3568)

This directory now provides two versions:

- `pcie_hdmi_out`: legacy framebuffer path (`/dev/fb0`)
- `pcie_hdmi_out_drm`: DRM/KMS path (`/dev/dri/card0`) for systems without `/dev/fb0`

## Build

```bash
cd pcie_hdmi_out
make
```

## Run (recommended: DRM)

```bash
sudo ./pcie_hdmi_out_drm --pcie /dev/pango_pci_driver --drm /dev/dri/card0 --connector HDMI-A-1 --width 1280 --height 720 --line-bytes 2560 --src-format rgb565 --fps 30
```

## Run (legacy fbdev)

```bash
sudo ./pcie_hdmi_out --fb /dev/fb0 --width 1280 --height 720 --line-bytes 2560 --src-format rgb565
```

## Notes

1. Kernel module `pango_pci_driver.ko` must be loaded.
2. HDMI connector should be `connected` in `/sys/class/drm/card0-HDMI-A-1/status`.
3. Stop with `Ctrl+C`; DMA mapping is released on exit.
4. For current FPGA top (35_HDMI_IN_DDR3_mid_filter/source/main.v), use --src-format rgb565 --width 1280 --height 720 --line-bytes 2560.
