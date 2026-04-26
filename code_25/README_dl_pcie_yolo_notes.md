# code_25 学长代码阅读说明：dl/dl 与 rk_new12/pcie_yolo

本文只针对以下两个目录做代码阅读和结构说明：

- `code_25/dl/dl`
- `code_25/rk_new12/pcie_yolo`

本文不评价、约束或替代当前新方案，只记录这两份学长代码本身的工程内容、数据链路和可复用点。

## 1. 总体关系

从代码结构看，这两个目录大致对应一套“FPGA 采集/缓存/PCIe 传输 + RK3568 接收/显示/YOLO 推理”的历史实现：

```text
OV5640/CMOS 输入
    -> FPGA 图像采集与格式整理
    -> DDR3 帧缓存/多通道图像缓存
    -> FPGA PCIe DMA
    -> RK3568 用户态 PCIe 程序
    -> Qt 显示 / OpenCV 处理 / RKNN YOLO 推理
```

其中：

- `code_25/dl/dl` 主要是 FPGA 端 PDS 工程和 RTL。
- `code_25/rk_new12/pcie_yolo` 主要是 RK3568 端 Qt/C++ 应用、PCIe 驱动 ioctl 封装、OpenCV/RKNN 目标检测代码和交叉编译辅助文件。

## 2. code_25/dl/dl：FPGA 端工程

### 2.1 工程定位

`code_25/dl/dl` 是一个 FPGA 图像采集与 PCIe 传输工程。顶层和工程文件显示，它不是单独的算法模块，而是包含：

- CMOS/OV5640 摄像头输入配置与采集
- DDR3 初始化和帧缓存相关逻辑
- 多通道图像流整理和选择
- PCIe IP 包装与 DMA 控制
- PDS 工程文件、综合/布局布线/时序报告和生成产物

主要工程文件：

- `project/dl_prj.pds`：PDS 工程文件。
- `source/dl_fpga_prj.v`：主要 FPGA 顶层。
- `project/source/dl_fpga_prj.v`：工程内副本/构建侧源码副本。

### 2.2 主要源码目录

```text
code_25/dl/dl/
├── project/                  # PDS 工程、报告、综合与布局布线产物
├── source/
│   ├── dl_fpga_prj.v          # FPGA 主顶层
│   ├── ov5640_top.v           # OV5640/CMOS 采集管理
│   ├── cmos_8_16bit.v         # 8bit CMOS 数据转 16bit 像素流
│   ├── cmos_pixel_width_adapter.v
│   ├── i2c_com.v / simple_i2c_master_ctrl.v
│   ├── reg_config.v / sensor_reg_cfg_mgr.v
│   ├── frame_ddr3/            # DDR 帧缓存/AXI burst 相关逻辑
│   ├── pcie/                  # PCIe IP、DMA 控制器和相关 FIFO/RAM
│   └── user/                  # 图像通道选择、压缩/裁剪/降采样类自定义逻辑
```

### 2.3 顶层 `dl_fpga_prj.v`

`source/dl_fpga_prj.v` 是该 FPGA 工程的核心顶层。根据端口和实例关系，它承担以下职责：

- 接收系统时钟和复位。
- 连接 DDR3 物理接口。
- 连接 HSST/PCIe 差分信号。
- 管理 CMOS/OV5640 输入接口。
- 例化图像采集、DDR、PCIe DMA 和 PCIe wrapper。

可确认的关键实例/连接包括：

- `ov5640_capture_manager`：摄像头选择、I2C 初始化、CMOS 数据采集。
- `img_data_stream_reducer`：对多路图像数据做流整理/缩减，生成后级可用数据流。
- `pcie_image_channel_selector`：根据 DMA 读数据请求，从多个图像通道中选择一路/一区域送给 PCIe。
- `pcie_dma_core`：PCIe DMA 控制核心，对外暴露 AXIS master/slave 和 DMA 写数据请求接口。
- `pcie_test`：PCIe wrapper/IP 顶层实例，连接实际 PCIe AXIS 接口。

顶层中可以看到典型 PCIe DMA 接口连接：

```verilog
.i_axis_master_tvld(axis_master_tvalid_mem)
.o_axis_master_trdy(axis_master_tready_mem)
.i_axis_master_tdata(axis_master_tdata_mem)
.i_axis_master_tkeep(axis_master_tkeep_mem)
.i_axis_master_tlast(axis_master_tlast_mem)
.i_axis_master_tuser(axis_master_tuser_mem)
```

同时还引出了面向图像数据的 DMA 请求接口：

```verilog
.o_dma_write_data_req(dma_write_req)
.o_dma_write_addr(dma_write_addr)
.i_dma_write_data(dma_write_data)
```

这说明该工程不是简单把像素直接塞进 PCIe，而是让 PCIe DMA 控制器按请求地址/节拍读取整理后的图像数据。

### 2.4 摄像头输入相关

相关文件：

- `source/ov5640_top.v`
- `source/cmos_8_16bit.v`
- `source/cmos_pixel_width_adapter.v`
- `source/i2c_com.v`
- `source/simple_i2c_master_ctrl.v`
- `source/reg_config.v`
- `source/sensor_reg_cfg_mgr.v`
- `source/power_on_delay.v`
- `source/sys_pwseq_delay_circuit.v`

`ov5640_top.v` 中的模块名是 `ov5640_capture_manager`。它包含 CMOS1/CMOS2 二选一的编译宏和两路摄像头接口信号，涉及：

- I2C/SCCB 配置
- VSYNC/HREF/PCLK/DATA 采集
- 摄像头 reset/power 时序
- 8bit 输入到 16bit 像素数据的整理

代码中使用了 `CMOS_1` / `CMOS_2` 宏选择输入源。

### 2.5 DDR3 / 帧缓存相关

相关文件集中在：

- `source/frame_ddr3/`
- `source/frame_ddr3/ddr_axi256_master.v`
- `source/frame_ddr3/ddr_axi256_burst_engine.v`
- `source/frame_ddr3/doc/frame_read_write.pdf`

工程报告和顶层参数显示，该工程使用 DDR3 作为图像帧缓存/中间缓存。`frame_ddr3` 目录提供面向 DDR AXI 侧的 256bit burst 读写逻辑。

从顶层看，DDR3 物理端口包括：

- `ddr3_ck / ddr3_ck_n`
- `ddr3_cke / ddr3_cs_n / ddr3_ras_n / ddr3_cas_n / ddr3_we_n`
- `ddr3_a / ddr3_ba`
- `ddr3_dq / ddr3_dqs / ddr3_dqs_n / ddr3_dm`

### 2.6 PCIe/DMA 相关

相关目录：

```text
source/pcie/
├── ips2l_pcie_dma.v
├── pcie_dma_core.v
├── pcie.v
├── ips2l_pcie_*.v
└── pcie_dma_ctrl/
```

需要注意：`source/pcie/ips2l_pcie_dma.v` 文件内模块名显示为 `pcie_dma_core`，与文件名不完全一致；另有 `source/pcie/pcie_dma_core.v`。阅读或移植时需要以模块名和实例名为准，不能只看文件名。

PCIe DMA 侧代码包含：

- MWR/MRD 请求与应答控制
- CplD 接收/发送控制
- DMA APB 配置接口
- AXIS master/slave 数据接口
- DMA RAM/FIFO 支撑模块

顶层 `dl_fpga_prj.v` 中 PCIe 部分的结构大致是：

```text
pcie_test wrapper
    <-> AXIS master/slave
pcie_dma_core
    <-> DMA write data request/address/data
pcie_image_channel_selector
    <-> 多通道图像数据输入
```

### 2.7 user 自定义图像流模块

相关文件：

- `source/user/pcie_img_select.v`
- `source/user/pcie_image_channel_selector.v`
- `source/user/minilize_data.v`
- `source/user/img_data_stream_reducer.v`

这些模块更接近学长工程的业务逻辑层，功能是把摄像头/DDR 输出的图像数据整理成 PCIe DMA 读取所需的 128bit 数据流，并支持多通道/分区选择。

`pcie_image_channel_selector` 中可以看到基于列、行计数的通道选择逻辑，用于按画面区域从 `ch0~ch3` 中取数。它还根据 `dma_wr_data_req` 发出各通道数据请求。

## 3. code_25/rk_new12/pcie_yolo：RK3568 端工程

### 3.1 工程定位

`code_25/rk_new12/pcie_yolo` 是 RK3568 端用户态应用工程，核心目标是：

- 从 `/dev/pango_pci_driver` 读取 FPGA PCIe 数据
- 将接收的图像数据显示在 Qt 界面中
- 使用 OpenCV 做图像格式处理
- 使用 RKNN runtime 运行 YOLOv11 目标检测
- 使用 RGA/RKNN/OpenCV 第三方库完成部署

主要工程文件：

- `RK3568_PCIE_SHOW.pro`：Qt qmake 工程文件。
- `main.cpp`：Qt 应用入口。
- `mainwindow.*` / `mainwindow.ui`：界面主窗口。
- `FPGA_pcie.*`：PCIe 驱动 ioctl、DMA 数据读取、线程封装。
- `data_receive_thread.*`：数据接收线程框架；当前实现基本为空循环。
- `rknn_object_detector.*`：RKNN YOLOv11 封装、预处理、推理、后处理。
- `image_utils.*` / `file_utils.*` / `common.h`：RKNN 示例风格的图像和文件工具。

### 3.2 Qt 工程和依赖

`RK3568_PCIE_SHOW.pro` 使用：

- Qt Core / GUI / Widgets / Network
- C++17
- OpenCV 3.4.1
- librga
- rknpu2 / RKNN runtime

工程文件中包含源码：

```text
main.cpp
mainwindow.cpp
FPGA_pcie.cpp
data_receive_thread.cpp
file_utils.c
image_utils.c
rknn_object_detector.cpp
```

头文件：

```text
mainwindow.h
FPGA_pcie.h
data_receive_thread.h
common.h
file_utils.h
image_utils.h
rknn_object_detector.h
```

第三方依赖主要放在：

```text
3rdparty/opencv_3.4.1/
3rdparty/librga/
3rdparty/rknpu2/
models/yolo11.rknn
```

目录里同时包含若干构建脚本和修复脚本，如：

- `docker_build.sh`
- `cross_compile.sh`
- `setup_cross_compile.sh`
- `install_qt_cross.sh`
- `setup_qt_simple.sh`
- `quick_fix_opencv.sh`
- `fix_opencv_symlinks.sh`

### 3.3 PCIe 用户态封装 `FPGA_pcie.*`

相关文件：

- `FPGA_pcie.h`
- `FPGA_pcie.cpp`

`FPGA_pcie.h` 中定义了设备路径和 ioctl 命令：

```cpp
#define PCIE_DRIVER_FILE_PATH "/dev/pango_pci_driver"
#define MEM_FILE_PATH         "/dev/mem"
```

主要 ioctl：

```cpp
PCI_READ_DATA_CMD
PCI_WRITE_DATA_CMD
PCI_MAP_ADDR_CMD
PCI_WRITE_TO_KERNEL_CMD
PCI_DMA_READ_CMD
PCI_DMA_WRITE_CMD
PCI_READ_FROM_KERNEL_CMD
PCI_UMAP_ADDR_CMD
PCI_PERFORMANCE_START_CMD
PCI_PERFORMANCE_END_CMD
PCI_MAP_BAR0_CMD
PCI_SET_CONFIG
```

图像参数定义为：

```cpp
#define IMAGE_WIDTH  1280
#define IMAGE_HEIGHT 720
#define LINE_BYTES   2560    // 1280 * 2, RGB565
```

这说明 RK 端期望从 FPGA/PCIe 收到的是 1280x720 的 RGB565 图像数据。

`FPGA_pcie` 类继承自 `QThread`，负责打开 PCIe 驱动、配置 DMA、接收数据并与 Qt 界面交互。代码中涉及：

- `open()` 打开 `/dev/pango_pci_driver`
- `ioctl()` 发送 PCIe/DMA 控制命令
- `mmap()`/`munmap()` 映射设备内存
- DMA 读写结构体 `DMA_OPERATION`
- PCIe 设备信息结构 `PCI_DEVICE_INFO`

需要注意：该代码属于历史工程实现，安全性和错误处理需要后续单独审查，例如 ioctl 失败后的退出路径、mmap 返回值检查、帧边界检查、缓冲区越界风险等。

### 3.4 RKNN YOLO 封装

相关文件：

- `rknn_object_detector.h`
- `rknn_object_detector.cpp`
- `models/yolo11.rknn`

`RknnObjectDetector` 主要函数：

- `InitResource()`：初始化模型资源。
- `init_model()`：读取 RKNN 模型、初始化 rknn context、查询输入输出 tensor 属性。
- `Process()`：接收 `cv::Mat`，转换颜色，调用推理，并将检测框画回图像。
- `inference_model()`：执行 RKNN 推理。
- `post_process()`：解析输出 tensor，进行置信度过滤、NMS 和坐标还原。
- `process_i8()` / `process_fp32()`：分别处理量化和浮点输出。
- `nms()`：非极大值抑制。
- `release_model()`：释放 RKNN 资源。

`Process()` 中会将输入图像从 BGR 转 RGB，并以 RKNN 示例常见流程做 letterbox、推理和后处理。

### 3.5 Qt 界面与线程

相关文件：

- `mainwindow.cpp`
- `mainwindow.h`
- `mainwindow.ui`
- `data_receive_thread.cpp`
- `data_receive_thread.h`

`mainwindow.cpp` 中初始化显示分辨率为：

```cpp
width = 1280;
length = 720;
```

界面中包含团队 logo、图像显示 label、分辨率文本、帧计数等 UI 逻辑。

`data_receive_thread.cpp` 当前实现较弱：构造函数分配了一块接收缓冲区，但 `run()` 函数中只是空循环，没有实际 PCIe 读取逻辑。因此从源码看，真正的 PCIe 读写逻辑更可能集中在 `FPGA_pcie.*`，`DataReceiveThread` 更像早期设计或残留框架。

## 4. 两个目录之间的数据接口关系

从两端代码可推断出历史工程的数据格式约定：

- FPGA 端以 128bit 宽度组织 PCIe DMA 数据。
- RK 端按 `1280 x 720 x 2` 字节理解图像帧，即 RGB565。
- RK 端 `LINE_BYTES = 2560`，对应每行 1280 像素，每像素 2 字节。
- FPGA 端 `pcie_image_channel_selector` 和相关 reducer 模块负责把多路/分区图像数据整理为 DMA 可读取数据。
- RK 端再把收到的数据转换为显示图像或 `cv::Mat`，后续送入 RKNN YOLO。

需要强调：README 只根据代码静态阅读整理。实际硬件链路是否稳定，还要结合驱动、bitstream、设备树/驱动版本、RKNN 模型输入格式和运行日志验证。

## 5. 可复用价值

### 5.1 FPGA 端可复用内容

`code_25/dl/dl` 中较有参考价值的部分：

- `source/pcie/`：PCIe DMA 控制器和 AXIS 接口连接方式。
- `source/user/pcie_image_channel_selector.v`：根据 DMA 请求读取图像数据的选择逻辑。
- `source/user/img_data_stream_reducer.v`：图像流降采样/整理思路。
- `source/frame_ddr3/`：DDR3 帧缓存和 AXI burst 访问逻辑。
- `source/ov5640_top.v`：CMOS/OV5640 摄像头初始化与采集管理。
- `source/dl_fpga_prj.v`：完整系统顶层的集成方式。

### 5.2 RK3568 端可复用内容

`code_25/rk_new12/pcie_yolo` 中较有参考价值的部分：

- `FPGA_pcie.h/cpp`：用户态访问 `/dev/pango_pci_driver` 的 ioctl 定义和 DMA 操作结构。
- `rknn_object_detector.h/cpp`：RKNN YOLOv11 初始化、推理和后处理流程。
- `RK3568_PCIE_SHOW.pro`：Qt/OpenCV/RGA/RKNN 依赖配置方式。
- `mainwindow.*`：Qt 显示界面和图像显示相关逻辑。
- 交叉编译脚本：Docker、本地 aarch64 工具链、Qt 交叉编译配置等。

## 6. 明显风险和注意事项

1. `code_25/dl/dl/source/pcie/ips2l_pcie_dma.v` 的文件名和模块名存在不一致现象，移植时必须以模块名、实例名和 PDS filelist 为准。
2. `rk_new12/pcie_yolo` 下存在构建产物和第三方库，阅读源码时应区分源码、依赖和 build 输出。
3. `DataReceiveThread` 当前不是完整接收实现，不能误认为它已经承担 PCIe 接收主流程。
4. `FPGA_pcie.*` 中大量 ioctl/mmap/DMA 操作需要结合实际驱动确认 ABI 是否一致。
5. RK 端代码假定图像尺寸为 1280x720、RGB565；若 FPGA 端输出格式改变，RK 端必须同步修改。
6. RKNN YOLO 输入通常是 RGB888/BGR 转 RGB 后再 resize/letterbox；PCIe 原始 RGB565 帧需要在送入 RKNN 前完成格式转换。
7. 两端代码注释存在编码混乱，部分中文在当前环境显示为乱码，但变量名和结构关系仍可读。
8. 该说明基于静态阅读，没有在 RK3568 或 PDS 环境下重新编译验证。

## 7. 阅读结论

`code_25/dl/dl` 是 FPGA 端完整度较高的历史工程，重点价值在 PCIe DMA 与图像缓存/多通道数据组织方式；`code_25/rk_new12/pcie_yolo` 是 RK3568 端应用工程，重点价值在 PCIe 用户态访问、Qt 显示框架和 RKNN YOLO 推理流程。

这两个目录合起来可以作为“FPGA 图像数据经 PCIe 到 RK3568，再做显示和 YOLO”的历史参考，但内部存在历史工程常见问题：路径和构建产物混杂、注释编码混乱、部分线程/模块残留、PCIe 驱动 ABI 强耦合。因此复用时应按模块拆解验证，而不是整目录无条件合并。
