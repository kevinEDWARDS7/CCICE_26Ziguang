# CCICE_26Ziguang 工程索引

本仓库用于整理和推进 2026 紫光同创赛题工程。当前工作区的主线目标是打通：

```text
HDMI IN / 摄像头输入
-> FPGA 视频采集、帧整理、可选预处理
-> PCIe DMA
-> RK3568 接收
-> DRM/KMS HDMI OUT，后续可接 AI 推理
```

## 当前工作区结构

```text
CCICE_26Ziguang/
├─ README.md
├─ 赛题资源相关文档/
│  ├─ 资源说明readme.txt
│  ├─ 紫光同创公司官方赛题解析.md
│  └─ 赛题 PDF、硬件资源手册、历史报告和压缩包
└─ code_26_2/
   ├─ README.md
   ├─ docs/
   │  ├─ reference_inventory.md
   │  └─ reference_inventory.zh.md
   ├─ fpga/
   │  ├─ FPGA_HDMIIN_1/
   │  └─ FPGA_HDMININ/
   └─ rk3568/
      └─ pcie_hdmi_out/
         └─ pango_pcie_drm_c/
```

## 快速入口

| 用途 | 入口 |
| --- | --- |
| 当前集成主工作区 | [code_26_2/README.md](code_26_2/README.md) |
| 参考代码盘点 | [code_26_2/docs/reference_inventory.zh.md](code_26_2/docs/reference_inventory.zh.md) |
| FPGA HDMI/DDR3/PCIe 工程 | [code_26_2/fpga/](code_26_2/fpga/) |
| RK3568 PCIe 接收与 HDMI OUT | [code_26_2/rk3568/pcie_hdmi_out/pango_pcie_drm_c/README.md](code_26_2/rk3568/pcie_hdmi_out/pango_pcie_drm_c/README.md) |
| 赛题和硬件资料 | [赛题资源相关文档/](%E8%B5%9B%E9%A2%98%E8%B5%84%E6%BA%90%E7%9B%B8%E5%85%B3%E6%96%87%E6%A1%A3/) |

## 目录职责

### [赛题资源相关文档/](%E8%B5%9B%E9%A2%98%E8%B5%84%E6%BA%90%E7%9B%B8%E5%85%B3%E6%96%87%E6%A1%A3/)

存放赛题、官方解析、板卡资源手册、上一届技术报告和代码压缩包。这里是需求和硬件约束来源，优先阅读 [资源说明readme.txt](%E8%B5%9B%E9%A2%98%E8%B5%84%E6%BA%90%E7%9B%B8%E5%85%B3%E6%96%87%E6%A1%A3/%E8%B5%84%E6%BA%90%E8%AF%B4%E6%98%8Ereadme.txt) 与 [紫光同创公司官方赛题解析.md](%E8%B5%9B%E9%A2%98%E8%B5%84%E6%BA%90%E7%9B%B8%E5%85%B3%E6%96%87%E6%A1%A3/%E7%B4%AB%E5%85%89%E5%90%8C%E5%88%9B%E5%85%AC%E5%8F%B8%E5%AE%98%E6%96%B9%E8%B5%9B%E9%A2%98%E8%A7%A3%E6%9E%90.md)。

### [code_26_2/](code_26_2/)

当前真正推进的集成工作区，包含 FPGA 工程、RK3568 端程序和参考代码盘点。新开发、移植和文档沉淀优先放在这里。

### [code_26_2/fpga/](code_26_2/fpga/)

FPGA 侧有两个相近的 PDS 工程目录：[FPGA_HDMIIN_1](code_26_2/fpga/FPGA_HDMIIN_1/) 和 [FPGA_HDMININ](code_26_2/fpga/FPGA_HDMININ/)。它们都按 `project/` 加 `source/` 组织：

- `source/` 是主要 RTL 源码，顶层模块是 `dl_fpga_prj.v`。
- `source/hdmi/` 是 HDMI 接收芯片 MS7200 的 I2C 初始化。
- `source/frame_ddr3/` 是 DDR3 帧缓存和 AXI 读写逻辑。
- `source/pcie/` 是 PCIe DMA 核和控制逻辑。
- `source/user/` 是当前视频缩放、通道选择和 PCIe 取图相关胶水逻辑。
- `project/` 是 PDS 工程文件、约束、IP 和工具输出。

### [code_26_2/rk3568/pcie_hdmi_out/pango_pcie_drm_c/](code_26_2/rk3568/pcie_hdmi_out/pango_pcie_drm_c/)

RK3568 侧 C 工程，包含 PCIe 字符设备 ABI、用户态收帧显示程序和内核驱动源码：

- `include/pango_pcie_abi.h` 定义 ioctl、结构体、分辨率和 DMA 包大小。
- `src/pcie_probe_only.c` 做 PCIe 安全探测。
- `src/main.c` 做 PCIe DMA 读帧、RGB565 转 XRGB8888 和 DRM 显示。
- `driver/pango_pci_driver.c` 与 `driver/pango_pci_driver.h` 是本工程配套驱动源码。
- `scripts/` 存放板端构建和启动/关闭脚本。

## 推荐阅读顺序

1. 先读赛题和资源说明：[赛题资源相关文档/资源说明readme.txt](%E8%B5%9B%E9%A2%98%E8%B5%84%E6%BA%90%E7%9B%B8%E5%85%B3%E6%96%87%E6%A1%A3/%E8%B5%84%E6%BA%90%E8%AF%B4%E6%98%8Ereadme.txt)。
2. 再读当前主工作区说明：[code_26_2/README.md](code_26_2/README.md)。
3. FPGA 侧从 `dl_fpga_prj.v`、`source/user/`、`source/frame_ddr3/`、`source/pcie/` 开始。
4. RK3568 侧从 [pango_pcie_drm_c/README.md](code_26_2/rk3568/pcie_hdmi_out/pango_pcie_drm_c/README.md) 开始。
5. 需要理解来源和复用思路时，再看 [reference_inventory.zh.md](code_26_2/docs/reference_inventory.zh.md)。

## 生成文件和源码边界

FPGA 工程里的这些目录主要是 PDS 工具输出或中间结果，阅读结构时一般先跳过：

```text
compile/
constraint_check/
device_map/
generate_bitstream/
log/
logbackup/
place_route/
report_timing/
synthesize/
```

优先关注 `source/`、`project/source/`、`project/project.fdc`、`project/impl.tcl` 和 RK3568 工程下的 `src/`、`include/`、`driver/`、`scripts/`。

## 当前注意点

- 当前工作区没有展开历史 `code_25/`、官方 `code_26/`、`RK_CLI/` 等目录；如果后续需要对照历史代码，需要先补齐对应资料或解压赛题资源。
- [code_26_2/fpga/FPGA_HDMIIN_1/](code_26_2/fpga/FPGA_HDMIIN_1/) 和 [code_26_2/fpga/FPGA_HDMININ/](code_26_2/fpga/FPGA_HDMININ/) 是相近工程副本，实际烧录和上板版本需要以 PDS 工程、bitstream 时间和板端现象共同确认。
- FPGA/RK3568 的接口约定包括分辨率、像素格式、DMA 行字节数和 ioctl ABI；任一侧修改后，需要同步更新另一侧和文档。