# PG2L100H PCIe DMA Base

本目录是从以下完整 PDS 工程整体复制得到的本地工作副本：

- `code_26/Test_demo/pcie_test_platform_v1_0/pango_pcie_dma_alloc/pcie_test_rtl/PG2L100H_PCIe_DMA`

复制目的：

- 不修改原始官方/参考工程
- 以一个可直接被 PDS 打开的完整 PCIe 工程为底座继续开发
- 后续只在 `code_26_2` 内修改

## 当前定位

这是当前 FPGA 主工程的新底座。

后续目标不是继续维护此前独立生成的 FPGA 壳工程，而是基于这个完整 PCIe 工程，把 HDMI 输入、必要的视频整理和可能的 DDR 缓存路径并入进来，最终形成：

`HDMI IN -> FPGA -> PCIe -> RK3568`

## 为什么选它

选择这个工程，而不是直接选 HDMI 工程做底座，原因如下：

1. PCIe 侧板级相关性最强
   - PCIe IP
   - 时钟与复位
   - APB 控制
   - DMA 控制器
   - 顶层 example design
   这些部分最不适合重新拼接。

2. 它是完整 PDS 工程
   - 有 `project.pds`
   - 有 `ipcore/pcie/pcie.idf`
   - 有 example design
   - 有 `pnr/example_design/pango_pcie_top.pds`

3. 当前最终平台本身就是 RK3568 + PG2L100H/PG2L50H 异构 PCIe 平台
   - 所以应当优先保证“PCIe 主工程”是稳定的
   - 然后把 HDMI 输入链路裁剪并入

## 当前确认的关键入口

### 工程文件

- `project.pds`

这是当前复制后的完整 PDS 工程描述文件。

### 顶层模块

当前模板工程中，真正可作为修改起点的顶层模块是：

- `pango_pcie_top`

对应文件：

- `ipcore/pcie/example_design/bench/pango_pcie_top.v`

说明：

- `impl.tcl` 本身只简单引用了 `ipcore/pcie/pcie.idf`
- 真正成体系的可分析顶层，在 example design 中
- `pnr/example_design/impl.tcl` 也是围绕 `pango_pcie_top` 编译

### PCIe DMA 核心接口

关键模块：

- `ipcore/pcie/example_design/rtl/pcie_dma_ctrl/ips2l_pcie_dma.v`

该模块暴露的关键数据入口是：

- `i_axis_master_tvld`
- `o_axis_master_trdy`
- `i_axis_master_tdata`
- `i_axis_master_tkeep`
- `i_axis_master_tlast`
- `i_axis_master_tuser`

这组接口就是后续把 HDMI 视频整理结果送入 PCIe DMA 的主要接入点。

## 与 HDMI 工程的连接思路

当前已经确认，学长 HDMI 工程中最值得优先借用的是：

- `code_25/four_pinjie_video/four_pinjie_video/HDMI_DDR3_OV5640`

重点参考模块：

- `source/rtl/hdmi_ddr_ov5640_top.v`
- `source/video_packet_send.v`
- `source/frame_read_write.v`
- `source/frame_fifo_write.v`
- `source/frame_fifo_read.v`
- `source/video_scale_process.v`
- `source/mem_read_arbi.v`
- `source/mem_write_arbi.v`

当前推荐迁移方式不是整套照搬，而是：

1. 保留本 PCIe 工程作为主顶层基座
2. 从 HDMI 工程中抽取：
   - HDMI 输入初始化
   - 视频时序与像素流
   - 视频打包逻辑
   - 如有必要再抽取 DDR 帧缓存逻辑
3. 重新整理成适配 PCIe DMA `axis_master` 输入接口的数据流

## 为什么之前那套新写 RTL 不能直接作为主工程

此前在 `code_26_2/fpga/hdmi_pcie_bridge` 中生成的文件，问题不在于思路完全错误，而在于它们更像“集成接口草图”，不具备以下条件：

- 不是真正完整的 PDS 工程
- 没有绑定现成 PCIe 顶层
- 没有继承完整板级工程结构
- 没有直接接入官方 PCIe DMA example design

因此它们更适合作为：

- 协议定义参考
- 新增逻辑思路参考
- 后续并入本工程的辅助模块

而不适合作为当前唯一主工程。

## 下一步修改原则

后续如果继续修改这个工程，原则如下：

1. 先在本目录内完成工程理解和接口盘点
2. 再新增本地 `src` 或 `user_logic` 一类目录承载 HDMI 并入逻辑
3. 优先少改 `ipcore/pcie` 自身内容
4. 优先在 `pango_pcie_top` 外围增加视频输入与适配逻辑
5. 只有当 example design 的接口确实不够用时，才深入修改 DMA 控制侧

## 当前结论

当前这份复制后的完整工程，是后续 FPGA 主线的推荐起点。

当前确认的模板工程顶层模块是：

- `pango_pcie_top`

当前确认的 PCIe 数据入口模块是：

- `ips2l_pcie_dma`

后续 HDMI 输入并入，优先从：

- `video_packet_send.v`
- `hdmi_ddr_ov5640_top.v`
- `frame_read_write.v`

这几类模块开始裁剪和接入。
