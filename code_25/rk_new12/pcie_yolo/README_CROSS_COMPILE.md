# ZYNQ视频接收程序交叉编译指南

## 项目概述
这是一个基于Qt的ZYNQ视频接收和YOLOv11目标检测程序，支持：
- PCIe数据接收和实时显示
- UDP网络通信
- YOLOv11目标检测 (使用RKNN NPU)
- 硬件加速图像处理 (RGA)
- OpenCV图像处理

## 快速开始

### 方案1: Docker编译 (推荐)
这是最简单的方法，无需复杂的环境配置：

```bash
# 1. 确保Docker已安装并运行
sudo systemctl start docker
sudo usermod -aG docker $USER  # 重新登录后生效

# 2. 运行Docker编译脚本
chmod +x docker_build.sh
./docker_build.sh
```

### 方案2: 本地交叉编译
如果你更喜欢本地编译：

```bash
# 1. 设置交叉编译环境
chmod +x setup_cross_compile.sh
./setup_cross_compile.sh

# 2. 设置Qt交叉编译环境 (选择其一)
# 方案A: 完整编译Qt (耗时较长)
chmod +x install_qt_cross.sh
./install_qt_cross.sh

# 方案B: 简化Qt设置
chmod +x setup_qt_simple.sh
./setup_qt_simple.sh

# 3. 编译项目
chmod +x cross_compile.sh
./cross_compile.sh
```

## 系统要求

### 编译环境 (Ubuntu)
- Ubuntu 18.04+ 或类似Linux发行版
- 至少4GB RAM
- 至少10GB可用磁盘空间
- Docker (方案1) 或交叉编译工具链 (方案2)

### 目标设备
- ARM64架构 (aarch64)
- Linux系统
- 支持RKNN NPU的设备 (如瑞芯微RK系列)
- 至少512MB可用内存
- 支持OpenGL的显示环境

## 项目结构
```
├── 3rdparty/                 # 第三方库
│   ├── opencv/              # OpenCV库
│   ├── librga/              # RGA硬件加速库
│   └── rknpu2/              # RKNN NPU库
├── models/                  # AI模型文件
│   └── yolo11.rknn         # YOLOv11模型
├── *.cpp, *.h              # 源代码文件
├── mainwindow.ui           # Qt界面文件
├── ZYNQ_video_show.pro     # Qt项目文件
└── 编译脚本文件
```

## 编译输出
编译成功后，会生成以下文件：
- `deploy-docker/` 或 `deploy-aarch64/`: 部署包目录
  - `ZYNQ_video_show`: 主程序可执行文件
  - `3rdparty/`: 依赖库
  - `models/`: AI模型文件
  - `README.md`: 部署说明

## 部署到目标设备

### 1. 复制文件
```bash
scp -r deploy-docker/ user@target-device:/opt/
```

### 2. 设置权限和环境
```bash
ssh user@target-device
cd /opt/deploy-docker
chmod +x ZYNQ_video_show
export LD_LIBRARY_PATH=./3rdparty/opencv/opencv-linux-aarch64/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=./3rdparty/librga/Linux/aarch64:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=./3rdparty/rknpu2/Linux/aarch64:$LD_LIBRARY_PATH
```

### 3. 运行程序
```bash
./ZYNQ_video_show
```

## 常见问题

### Q: 编译时出现"交叉编译工具链未安装"错误
A: 运行 `./setup_cross_compile.sh` 安装交叉编译工具链

### Q: Qt相关编译错误
A: 确保Qt交叉编译环境已正确安装，或使用Docker方案

### Q: OpenCV库找不到
A: 检查 `3rdparty/opencv/opencv-linux-aarch64/` 目录是否存在

### Q: 目标设备上运行时出现库文件找不到
A: 检查LD_LIBRARY_PATH环境变量设置，确保所有依赖库路径正确

### Q: RKNN相关错误
A: 确保目标设备支持RKNN NPU，且驱动已正确安装

## 技术支持
如遇到问题，请检查：
1. 编译日志中的具体错误信息
2. 目标设备的系统架构和依赖库
3. 网络连接和文件传输是否正常

## 开发说明
- 项目使用Qt5框架
- 支持C++17标准
- 集成了OpenCV、RGA、RKNN等库
- 支持实时视频处理和AI目标检测
