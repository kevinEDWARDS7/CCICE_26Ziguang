# Reference Inventory

## Goal mapping

Target pipeline:

`HDMI IN -> FPGA frame formatting -> PCIe DMA -> RK3568 receive -> DRM HDMI OUT`

## Reused FPGA code

### HDMI input and timing

Imported from:

- `code_25/four_pinjie_video/four_pinjie_video/HDMI_DDR3_OV5640/source/rtl`
- `code_25/four_pinjie_video/four_pinjie_video/HDMI_DDR3_OV5640/source`

Useful modules:

- `ms7200_ctl.v`
- `ms7210_ctl.v`
- `ms72xx_ctl.v`
- `hdmi_ddr_ov5640_top.v`
- `video_scale_process.v`
- `video_packet_send.v`
- `timing_gen_xy.v`

Use in current plan:

- Keep HDMI receiver setup and video timing handling as the input-side reference.
- Do not keep the prior multi-input routing as the mainline architecture.

### DDR frame buffer

Imported from:

- `code_25/dl/dl/source/frame_ddr3`

Useful modules:

- `frame_read_write.v`
- `frame_fifo_write.v`
- `frame_fifo_read.v`
- `mem_write_arbiter.v`
- `mem_read_arbiter.v`
- `image_fifo_writer.v`
- `image_fifo_reader.v`

Use in current plan:

- Keep as the preferred baseline for full-frame buffering or CDC smoothing.
- For the first stage, this can stay optional if line-stream DMA proves stable.

### PCIe DMA

Imported from:

- `code_26/Test_demo/pcie_test_platform_v1_0/pango_pcie_dma_alloc/pcie_test_rtl/PG2L100H_PCIe_DMA/ipcore/pcie/example_design/rtl/pcie_dma_ctrl`

Useful modules:

- `ips2l_pcie_dma.v`
- `ips2l_pcie_dma_controller.v`
- `ips2l_pcie_dma_tx_top.v`
- `ips2l_pcie_dma_rx_top.v`
- `ips2l_pcie_dma_wr_ctrl.v`
- `ips2l_pcie_dma_rd_ctrl.v`

Use in current plan:

- Keep as the official DMA transport core.
- New glue logic in this workspace should present a cleaner single-stream frame payload into this DMA path.

## Reused RK3568 code

### PCIe receive and display

Imported from:

- `code_26/Test_demo/RK/pcie_test_platform_v1_0/pango_pcie_dma_alloc/pcie_hdmi_out_sync/pcie_hdmi_out_drm_sync.c`

Useful behavior:

- `PCI_DMA_WRITE_CMD` based device-to-host DMA readback.
- DRM framebuffer allocation and mode selection.
- Raw RGB565 to XRGB8888 conversion path.

### PCIe utility layer

Reference only:

- `code_25/rk_new12/pcie_yolo/FPGA_pcie.h`
- `code_25/rk_new12/pcie_yolo/FPGA_pcie.cpp`

Use in current plan:

- Reuse ioctl layout and DMA transaction style.
- Do not carry over the Qt and YOLO dependencies into the HDMI-out-only stage.

## Current workspace landing points

### FPGA PDS projects

Current FPGA code lives in two similar PDS project copies:

- `fpga/FPGA_HDMIIN_1/`
- `fpga/FPGA_HDMININ/`

Key files:

- `source/dl_fpga_prj.v`
- `source/user/img_data_stream_reducer.v`
- `source/user/pcie_image_channel_selector.v`
- `source/pcie/pcie_dma_core.v`
- `source/pcie/ips2l_pcie_dma.v`
- `source/frame_ddr3/frame_read_write_256_burst.v`
- `project/source/word_align.v`
- `project/source/video_packet_rec.v`
- `project/source/iamge_fliter.v`

Purpose:

- `dl_fpga_prj.v` integrates HDMI input, DDR3 buffering, and PCIe DMA.
- `img_data_stream_reducer.v` passes 1920x1080 RGB565 video into the DDR write path.
- `pcie_image_channel_selector.v` pulls 128-bit image data from DDR3 and feeds the DMA write-data path.

### RK3568 local app and driver

Current RK3568 code lives in:

- `rk3568/pcie_hdmi_out/pango_pcie_drm_c/`

Key files:

- `include/pango_pcie_abi.h`
- `src/main.c`
- `src/pcie_probe_only.c`
- `driver/pango_pci_driver.c`
- `driver/pango_pci_driver.h`
- `Makefile`
- `README.md`
- `scripts/`

Purpose:

- Keep PCIe ioctl ABI and DMA data structures centralized in `pango_pcie_abi.h`.
- Use `pcie_probe_only.c` for a safe pre-DMA link probe.
- Use `main.c` for line-by-line PCIe frame receive, RGB565 to XRGB8888 conversion, and DRM/KMS HDMI output.
