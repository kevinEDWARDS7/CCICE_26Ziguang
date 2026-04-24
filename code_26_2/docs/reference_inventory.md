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

## New files in this workspace

### FPGA integration shell

- `fpga/hdmi_pcie_bridge/rtl/frame_packet_defs.vh`
- `fpga/hdmi_pcie_bridge/rtl/hdmi_frame_packetizer.v`
- `fpga/hdmi_pcie_bridge/rtl/stream_width_adapter_32to128.v`
- `fpga/hdmi_pcie_bridge/rtl/traffic_hdmi_pcie_top.v`

Purpose:

- Define a stable frame header.
- Convert live HDMI pixels into a deterministic packet stream.
- Present a 128-bit stream shape that is easier to map into the PCIe DMA datapath.

### RK3568 local app shell

- `rk3568/pcie_hdmi_out/include/pango_pcie_ioctl.h`
- `rk3568/pcie_hdmi_out/Makefile`
- `rk3568/pcie_hdmi_out/README.md`

Purpose:

- Make the copied DRM app locally buildable and decouple it from the original demo folder.
