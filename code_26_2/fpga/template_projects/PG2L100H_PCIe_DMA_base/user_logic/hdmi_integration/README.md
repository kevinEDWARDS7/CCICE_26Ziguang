# HDMI Integration

本目录用于把 HDMI 输入链路并入当前完整 PCIe 工程。

当前阶段的作用不是直接替代 `pango_pcie_top`，而是先把即将接入 PCIe `axis master` 侧的数据整理逻辑放进主工程目录内部，避免继续使用工程外部的孤立骨架。

## 当前文件

- `frame_packet_defs.vh`
  - 定义帧头 magic、像素格式和标志位。
- `hdmi_frame_packetizer.v`
  - 把 HDMI 像素流整理成带帧头的 32bit 流。
- `stream_width_adapter_32to128.v`
  - 将 32bit 流拼接为 PCIe 侧可用的 128bit 流。
- `hdmi_axis_master_bridge.v`
  - 作为 HDMI 输入到 PCIe `axis master` 侧的局部桥接模块。

## 当前状态

这些模块已经落在完整 PCIe 模板工程内部，但还没有正式接入 `pango_pcie_top`。

下一步接入时，优先修改：

- `ipcore/pcie/example_design/bench/pango_pcie_top.v`

目标是将：

- `axis_master_tvalid`
- `axis_master_tdata`
- `axis_master_tkeep`
- `axis_master_tlast`
- `axis_master_tuser`

从当前的 PCIe example design 默认来源，切换到 HDMI 桥接逻辑的输出，或者至少加入可切换选择通路。

## 注意

当前这里还是“工程内部集成准备阶段”，不是最终板级闭环。

在正式接顶层前，还需要明确：

- HDMI 输入来自哪组实际顶层端口
- 是否需要 MS7200 初始化逻辑直接并入
- `pix_clk` 与 `pclk_div2` 是否需要异步 FIFO / DDR 缓冲过渡
- PCIe DMA 端是否对 `tuser/tkeep/tlast` 有额外格式约束
