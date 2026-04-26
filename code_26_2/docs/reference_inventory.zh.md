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

## 当前工作区落地点

### FPGA PDS 工程

当前 FPGA 代码落在两个结构相近的 PDS 工程副本中：

- `fpga/FPGA_HDMIIN_1/`
- `fpga/FPGA_HDMININ/`

重点文件：

- `source/dl_fpga_prj.v`
- `source/user/img_data_stream_reducer.v`
- `source/user/pcie_image_channel_selector.v`
- `source/pcie/pcie_dma_core.v`
- `source/pcie/ips2l_pcie_dma.v`
- `source/frame_ddr3/frame_read_write_256_burst.v`
- `project/source/word_align.v`
- `project/source/video_packet_rec.v`
- `project/source/iamge_fliter.v`

作用：

- `dl_fpga_prj.v` 集成 HDMI 输入、DDR3 和 PCIe DMA。
- `img_data_stream_reducer.v` 将 1280x720 RGB565 图像抽样为 640x360。
- `pcie_image_channel_selector.v` 从 DDR3 取出 128 位图像数据并送入 DMA 写数据路径。

### RK3568 本地应用和驱动

当前 RK3568 代码位于：

- `rk3568/pcie_hdmi_out/pango_pcie_drm_c/`

重点文件：

- `include/pango_pcie_abi.h`
- `src/main.c`
- `src/pcie_probe_only.c`
- `driver/pango_pci_driver.c`
- `driver/pango_pci_driver.h`
- `Makefile`
- `README.md`
- `scripts/`

作用：

- 保持 PCIe ioctl ABI 和 DMA 结构体定义集中在 `pango_pcie_abi.h`。
- `pcie_probe_only.c` 用于 DMA 前的安全探测。
- `main.c` 完成 PCIe 逐行收帧、RGB565 到 XRGB8888 转换和 DRM/KMS HDMI 输出。
