# code_26_2

该目录是当前阶段唯一允许写入的集成工作区。

当前目标：

`HDMI IN -> FPGA -> PCIe -> RK3568 -> HDMI OUT`

当前原则：

- 第一优先级复用官方例程。
- 第二优先级复用上一届代码。
- 只补充实现单路主链路所需的最小胶水代码。
- 不修改 `code_25` 或 `code_26`。

## 目录结构

- `docs/`
  - 只读盘点结果和集成说明。
- `fpga/imported/`
  - 可复用 FPGA 参考代码的本地快照。
- `fpga/hdmi_pcie_bridge/`
  - 新增的单路 HDMI 到 PCIe 集成层和构建脚本。
- `rk3568/pcie_hdmi_out/`
  - RK3568 用户态 PCIe 接收加 DRM HDMI 输出程序。

## 复用代码基线

- HDMI 输入与视频时序：
  - `code_25/four_pinjie_video/four_pinjie_video/HDMI_DDR3_OV5640/source`
- DDR 帧缓存：
  - `code_25/dl/dl/source/frame_ddr3`
- PCIe DMA 控制器：
  - `code_26/Test_demo/pcie_test_platform_v1_0/pango_pcie_dma_alloc/pcie_test_rtl/PG2L100H_PCIe_DMA/ipcore/pcie/example_design/rtl/pcie_dma_ctrl`
- RK3568 HDMI 输出示例：
  - `code_26/Test_demo/RK/pcie_test_platform_v1_0/pango_pcie_dma_alloc/pcie_hdmi_out_sync/pcie_hdmi_out_drm_sync.c`

## 本目录中生成了什么

该工作区目前包含的是初始集成基线，不是已经闭环可直接出 bitstream 的最终板级工程。

已包含：

- 一份筛选后的本地 RTL 和 RK 代码快照。
- 一套新的 FPGA 帧头定义与打包模块。
- 一个 32 位到 128 位的数据流拼接模块，用于 PCIe 侧接口适配。
- 一个新的单路 HDMI 到 PCIe 顶层集成壳。
- 一个本地可编译的 RK3568 DRM 应用框架。

暂未包含：

- 针对你当前 40PIN 转 HDMI 硬件的最终板级管脚约束。
- 最终的 PDS IP 重新生成结果。
- 经过验证的端到端时序收敛结果。
- 最终内核驱动改动。

## 立即使用方式

1. 使用 `docs/reference_inventory.md` 或中文版本确认哪些复制进来的模块继续保留在主线中。
2. 使用 `fpga/hdmi_pcie_bridge/rtl/traffic_hdmi_pcie_top.v` 作为新的 FPGA 集成入口。
3. 使用 `rk3568/pcie_hdmi_out/Makefile` 构建 RK 用户态显示程序。
4. 在 PDS 中导入本地 RTL，并配合你已有的、已经验证过的 PCIe 与 DDR IP 一起使用。
