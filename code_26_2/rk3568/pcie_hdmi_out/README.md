# RK3568 PCIe HDMI Out

This directory contains the local RK3568 user-space app for the current phase:

`PCIe receive -> DRM framebuffer -> HDMI OUT`

## Source baseline

- Copied from:
  - `code_26/Test_demo/RK/pcie_test_platform_v1_0/pango_pcie_dma_alloc/pcie_hdmi_out_sync/pcie_hdmi_out_drm_sync.c`

## Build

```sh
make
```

## Current role

- Open `/dev/pango_pci_driver`
- Trigger DMA reads from FPGA to host
- Read the DMA buffer back from kernel space
- Convert RGB565 or RGB888 line data to XRGB8888
- Present frames with DRM to HDMI output

## Notes

- This stage still assumes raw line-oriented DMA, matching the existing demo.
- The new FPGA packet header generated in `fpga/hdmi_pcie_bridge/rtl` is the next interface to fold into this app after the basic display path is stable.
