# FPGA HDMI PCIe Bridge

本目录是当前阶段为单路主链路新增的 FPGA 集成层：

`HDMI IN -> FPGA 帧整理 -> PCIe DMA 输入侧接口`

它不是完整替代官方工程的独立量产工程，而是建立在已验证的 HDMI、DDR、PCIe 参考代码之上的“统一接口层”。

## 顶层模块

当前新增 FPGA 文件中的顶层模块是：

- `traffic_hdmi_pcie_top`

对应文件：

- `rtl/traffic_hdmi_pcie_top.v`

该模块的职责是：

- 接收单路 HDMI 输入像素流
- 调用帧打包模块生成带帧头的数据流
- 调用位宽适配模块输出 128bit 流接口
- 为后续接入官方 PCIe DMA 数据通路提供统一入口

## 文件说明

### `rtl/traffic_hdmi_pcie_top.v`

当前新增逻辑的顶层壳。

作用：

- 定义单路 HDMI 输入接口
- 实例化 `hdmi_frame_packetizer`
- 实例化 `stream_width_adapter_32to128`
- 输出适合映射到 PCIe 侧的数据流接口：
  - `pcie_axis_tdata`
  - `pcie_axis_tvalid`
  - `pcie_axis_tready`
  - `pcie_axis_tuser`
  - `pcie_axis_tlast`

### `rtl/hdmi_frame_packetizer.v`

帧打包模块。

作用：

- 监测 `vsync/de`
- 对每帧生成固定帧头
- 将 RGB888 输入压成 RGB565
- 以 32bit 数据流形式输出 payload
- 给出帧起始、行结束、帧结束标记

当前输出的帧头字段包含：

- `magic`
- `frame_id`
- `width`
- `height`
- `pixel_format`
- `flags`
- `timestamp`

这一步的目的，是避免 FPGA 发给 RK3568 的内容成为不可校验的裸流。

### `rtl/stream_width_adapter_32to128.v`

位宽适配模块。

作用：

- 将 `hdmi_frame_packetizer` 输出的 32bit 流拼成 128bit 流
- 保留帧起始和帧结束标志
- 为接入现有 PCIe DMA/TLP 发送路径做接口预处理

### `rtl/frame_packet_defs.vh`

帧头与格式定义头文件。

作用：

- 集中定义帧头 `magic`
- 集中定义像素格式枚举
- 集中定义 SOF/EOF 标志位

后续如果 RK3568 端要严格解析帧头，这个文件应作为 FPGA 与 RK 端协议定义的基础版本。

### `scripts/impl.tcl`

PDS 导入辅助脚本。

作用：

- 添加本目录下新增的 RTL 文件
- 给出需要同时导入的参考代码目录
- 指出建议顶层模块为 `traffic_hdmi_pcie_top`

注意：

- 该脚本不会自动生成 DDR3 或 PCIe IP
- 该脚本不会自动添加板级约束
- 你仍然需要在 PDS 中导入已经验证过的官方 PCIe/DDR IP 和板级约束

### `constraints/README.md`

约束说明文件。

当前没有直接生成 `.fdc` 或最终管脚约束，原因是：

- 40PIN 转 HDMI 的具体引脚绑定必须与你当前硬件一致
- 现有参考工程中存在多块板、多种接口和多路输入版本
- 如果直接套错约束，风险比暂时不生成更高

## 与参考代码的关系

本目录不是从零重写，而是为以下参考代码增加统一入口层：

- HDMI 输入参考：
  - `code_26_2/fpga/imported/hdmi_video`
- DDR 帧缓存参考：
  - `code_26_2/fpga/imported/frame_ddr3`
- PCIe DMA 参考：
  - `code_26_2/fpga/imported/pcie_dma`

推荐接入方式：

1. 保留已验证的 HDMI 接收初始化模块
2. 必要时保留 DDR 做帧缓存或跨时钟域缓冲
3. 将 `traffic_hdmi_pcie_top` 生成的 128bit 数据流接到现有 PCIe DMA 发送侧
4. 再由 RK3568 用户态程序接收并显示

## 当前状态

当前状态是“工程骨架已建立”，不是“已经完成板级闭环”。

已经完成：

- 单路主链路的 FPGA 新增接口层
- 帧头定义
- 32bit 到 128bit 的流接口适配
- 与本地参考代码目录的组织关系

尚未完成：

- 与你最终选定的 PCIe DMA 端口逐信号对接
- 与 DDR 缓存路径的最终仲裁连接
- 与板卡实际约束的绑定
- 在 PDS 中完成综合、布局布线和上板验证

## 当前使用建议

如果你现在要继续推进 FPGA 侧，建议下一步按这个顺序做：

1. 选定一个最终作为主工程底座的 PDS 工程
2. 确认该工程中的 PCIe DMA 发送输入接口具体信号
3. 将 `traffic_hdmi_pcie_top` 的输出映射到该 DMA 输入
4. 再决定是否在中间插入 DDR 帧缓存

如果你接下来要我继续做，我会先说明准备修改哪个 FPGA 文件、它在链路中的位置、原本做什么、为什么改、如何验证，然后再继续写代码。
