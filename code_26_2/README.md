# code_26_2 项目结构

`code_26_2/` 是当前集成主工作区，目标链路是：

```text
HDMI IN -> FPGA RGB565/DDR3 帧整理 -> PCIe DMA -> RK3568 收帧 -> DRM/KMS HDMI OUT
```

## 顶层结构

```text
code_26_2/
├─ README.md
├─ docs/
│  ├─ reference_inventory.md
│  └─ reference_inventory.zh.md
├─ fpga/
│  ├─ FPGA_HDMIIN_1/
│  │  ├─ project/
│  │  └─ source/
│  └─ FPGA_HDMININ/
│     ├─ project/
│     └─ source/
└─ rk3568/
   └─ pcie_hdmi_out/
      └─ pango_pcie_drm_c/
         ├─ driver/
         ├─ include/
         ├─ scripts/
         └─ src/
```

## FPGA 工程

[fpga/FPGA_HDMIIN_1/](fpga/FPGA_HDMIIN_1/) 和 [fpga/FPGA_HDMININ/](fpga/FPGA_HDMININ/) 是两个结构相近的 PDS 工程副本。阅读和修改时优先看 `source/`，再看 `project/` 中的约束和 IP 配置。

### 关键源码目录

```text
source/
├─ dl_fpga_prj.v                 # FPGA 顶层：HDMI、DDR3、PCIe 总集成
├─ hdmi/                         # MS7200 HDMI 接收芯片 I2C 初始化
├─ frame_ddr3/                   # DDR3 帧缓存、AXI 读写和 FIFO
├─ pcie/                         # PCIe DMA core 与 pcie_dma_ctrl
├─ user/                         # 当前视频缩放、选通和 PCIe 取图逻辑
├─ axi_ctrl/                     # AXI 控制相关逻辑
├─ ov5640_*.v                    # 摄像头相关保留模块
├─ i2c_com.v / simple_i2c_*.v    # I2C 通用模块
└─ reg_config.v / power_on_*.v   # 外设配置和上电延时
```

当前最关键的 RTL：

- `source/dl_fpga_prj.v`：顶层模块 `dl_fpga_prj`，连接 HDMI 输入、DDR3、PCIe 物理接口和 DMA 数据路径。
- `source/user/img_data_stream_reducer.v`：按 1920x1080 RGB565 直通 HDMI 图像流。
- `source/user/pcie_image_channel_selector.v`：从 DDR3 读出 128 bit 图像数据，并响应 DMA 写数据请求。
- `source/pcie/pcie_dma_core.v` 和 `source/pcie/ips2l_pcie_dma.v`：PCIe DMA 主链路。
- `source/frame_ddr3/frame_read_write_256_burst.v` 等：DDR3 帧写入和读出逻辑。

### PDS 工程目录

```text
project/
├─ dl_prj.pds          # PDS 工程
├─ project.fdc         # 管脚、时钟和约束
├─ impl.tcl            # 工程流程脚本
├─ ipcore/             # DDR3、PCIe、PLL、FIFO 等 IP
├─ source/             # 工程侧附加 RTL，如 word_align/video_packet_rec
└─ compile/ device_map/ synthesize/ place_route/ ...  # 工具输出
```

`project/source/` 里有 `word_align.v`、`video_packet_rec.v`、`iamge_fliter.v` 等附加模块。`compile/`、`device_map/`、`synthesize/`、`place_route/`、`report_timing/`、`log/`、`logbackup/` 一般作为生成结果查看，不作为优先修改入口。

## RK3568 工程

RK3568 侧工程位于 [rk3568/pango_pcie_drm_c/](rk3568/pango_pcie_drm_c/)，目标是用 PCIe DMA 读回 FPGA 图像数据，并通过 DRM/KMS 输出到 HDMI。

```text
pango_pcie_drm_c/
├─ README.md
├─ Makefile
├─ include/
│  └─ pango_pcie_abi.h
├─ src/
│  ├─ main.c
│  └─ pcie_probe_only.c
├─ driver/
│  ├─ Makefile
│  ├─ pango_pci_driver.c
│  └─ pango_pci_driver.h
└─ scripts/
```

关键文件：

- `include/pango_pcie_abi.h`：用户态和驱动共享的 ioctl、结构体、默认 `1920x1080`、`LINE_BYTES=3840`、`DMA_MAX_PACKET_SIZE=4096`。
- `src/pcie_probe_only.c`：只做 PCIe 枚举和链路有效性检查，安全确认后再跑 DMA。
- `src/main.c`：逐行触发 `PCI_DMA_WRITE_CMD`，读取 RGB565 帧，转换为 XRGB8888，并通过 DRM dumb buffer 显示。
- `driver/pango_pci_driver.c`：本工程配套 PCIe 字符设备驱动实现。
- `scripts/`：板端构建和启动/关闭脚本。

## 数据流对应关系

```text
HDMI MS7200 输入
  -> dl_fpga_prj.v 将 RGB888 压成 RGB565
   -> img_data_stream_reducer.v 输出 1920x1080 RGB565
  -> frame_ddr3 写入/读出一帧图像
  -> pcie_image_channel_selector.v 输出 128 bit DMA 数据
  -> PCIe DMA 写入 RK3568 可读缓冲
  -> src/main.c 按行读取 RGB565
  -> DRM/KMS 显示到 HDMI OUT
```

## 构建入口

FPGA 侧使用 Pango/PDS 打开对应 `project/dl_prj.pds`，顶层模块为 `dl_fpga_prj`，约束文件为 `project/project.fdc`。

RK3568 用户态程序：

```sh
cd rk3568/pcie_hdmi_out/pango_pcie_drm_c
make clean
make
```

RK3568 驱动在板端编译：

```sh
cd rk3568/pcie_hdmi_out/pango_pcie_drm_c/driver
make KDIR=/usr/src/linux-headers-6.1-rockchip clean
make KDIR=/usr/src/linux-headers-6.1-rockchip -j$(nproc)
```

也可以按 [pango_pcie_drm_c/README.md](rk3568/pcie_hdmi_out/pango_pcie_drm_c/README.md) 使用 `scripts/build_on_rk3568.sh` 和 `scripts/run_display.sh`；`run_display.sh -c` 关闭显示应用，`run_display.sh -c all` 同时卸载驱动。

## 修改优先级

- 改 HDMI/DDR3/PCIe 集成：先看 `source/dl_fpga_prj.v`。
- 改图像尺寸、抽样或格式：看 `source/user/img_data_stream_reducer.v` 和 RK 侧 `include/pango_pcie_abi.h`。
- 改 PCIe 取图节奏：看 `source/user/pcie_image_channel_selector.v` 和 `src/main.c`。
- 改 ioctl 或 DMA ABI：同时改 `include/pango_pcie_abi.h`、`driver/pango_pci_driver.h`、`driver/pango_pci_driver.c` 和调用端。
- 只看工程状态时，优先读 `project/constraint_check/`、`project/report_timing/` 和 `project/log/`，不要从生成文件反推源码结构。

## 当前边界

- 当前阶段只打通基础 HDMI 输入、FPGA 帧整理、PCIe DMA、RK3568 收帧和 HDMI OUT 显示。
- RKNN、YOLO、LPRNet、OpenCV/RGA、Qt UI 和完整车牌识别流程还没有并入当前主线。
- 两个 FPGA 工程目录内容相近，正式上板前需要确认实际使用的是哪个 PDS 工程和哪份 bitstream。