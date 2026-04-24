# 参考代码盘点

## 目标映射

当前目标链路：

`HDMI IN -> FPGA 帧整理 -> PCIe DMA -> RK3568 接收 -> DRM HDMI OUT`

## 可复用 FPGA 代码

### HDMI 输入与视频时序

导入来源：

- `code_25/four_pinjie_video/four_pinjie_video/HDMI_DDR3_OV5640/source/rtl`
- `code_25/four_pinjie_video/four_pinjie_video/HDMI_DDR3_OV5640/source`

可用模块：

- `ms7200_ctl.v`
- `ms7210_ctl.v`
- `ms72xx_ctl.v`
- `hdmi_ddr_ov5640_top.v`
- `video_scale_process.v`
- `video_packet_send.v`
- `timing_gen_xy.v`

在当前方案中的用途：

- 保留 HDMI 接收初始化和视频时序处理作为输入侧参考。
- 不再把原来的多路输入选择逻辑当成当前主线架构。

### DDR 帧缓存

导入来源：

- `code_25/dl/dl/source/frame_ddr3`

可用模块：

- `frame_read_write.v`
- `frame_fifo_write.v`
- `frame_fifo_read.v`
- `mem_write_arbiter.v`
- `mem_read_arbiter.v`
- `image_fifo_writer.v`
- `image_fifo_reader.v`

在当前方案中的用途：

- 作为完整帧缓存或跨时钟域缓冲的优先基线。
- 在第一阶段，如果按行 DMA 足够稳定，这部分可以先保持可选。

### PCIe DMA

导入来源：

- `code_26/Test_demo/pcie_test_platform_v1_0/pango_pcie_dma_alloc/pcie_test_rtl/PG2L100H_PCIe_DMA/ipcore/pcie/example_design/rtl/pcie_dma_ctrl`

可用模块：

- `ips2l_pcie_dma.v`
- `ips2l_pcie_dma_controller.v`
- `ips2l_pcie_dma_tx_top.v`
- `ips2l_pcie_dma_rx_top.v`
- `ips2l_pcie_dma_wr_ctrl.v`
- `ips2l_pcie_dma_rd_ctrl.v`

在当前方案中的用途：

- 保留为官方 DMA 传输核心。
- 本工作区新增的胶水逻辑负责把单路视频帧整理成更清晰的输入数据流，再接入该 DMA 路径。

## 可复用 RK3568 代码

### PCIe 接收与显示

导入来源：

- `code_26/Test_demo/RK/pcie_test_platform_v1_0/pango_pcie_dma_alloc/pcie_hdmi_out_sync/pcie_hdmi_out_drm_sync.c`

可用能力：

- 基于 `PCI_DMA_WRITE_CMD` 的设备到主机 DMA 读回。
- DRM framebuffer 申请与显示模式选择。
- 原始 RGB565 到 XRGB8888 的转换显示路径。

### PCIe 工具层

仅作参考：

- `code_25/rk_new12/pcie_yolo/FPGA_pcie.h`
- `code_25/rk_new12/pcie_yolo/FPGA_pcie.cpp`

在当前方案中的用途：

- 复用 ioctl 定义和 DMA 事务风格。
- 当前 HDMI OUT 阶段不继续带入 Qt 和 YOLO 依赖。

## 本工作区新增文件

### FPGA 集成壳

- `fpga/hdmi_pcie_bridge/rtl/frame_packet_defs.vh`
- `fpga/hdmi_pcie_bridge/rtl/hdmi_frame_packetizer.v`
- `fpga/hdmi_pcie_bridge/rtl/stream_width_adapter_32to128.v`
- `fpga/hdmi_pcie_bridge/rtl/traffic_hdmi_pcie_top.v`

作用：

- 定义统一帧头格式。
- 把实时 HDMI 像素流整理成可控的数据包流。
- 提供 128 位流接口形态，便于后续映射到 PCIe DMA 数据通路。

### RK3568 本地应用壳

- `rk3568/pcie_hdmi_out/include/pango_pcie_ioctl.h`
- `rk3568/pcie_hdmi_out/Makefile`
- `rk3568/pcie_hdmi_out/README.md`

作用：

- 让复制过来的 DRM 应用可以在本目录独立构建。
- 为后续接入帧头解析和更严格的收帧校验做准备。
