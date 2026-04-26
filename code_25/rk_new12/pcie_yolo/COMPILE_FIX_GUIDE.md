# ZYNQ视频接收程序编译错误修复指南

## 问题描述
你遇到的编译错误：
```
pango_fun.h:14: error: expected identifier before 'S'
#define TYPE        'S'
```

## 错误原因
在C++中，`_IOWR` 宏的第一个参数需要是一个数字，而不是字符字面量 `'S'`。

## 解决方案

### 方案1: 手动修复 (推荐)
我已经为你修复了 `pango_fun.h` 文件中的错误：

1. **修复TYPE定义**：
   ```cpp
   // 错误的定义
   #define TYPE        'S'
   
   // 正确的定义
   #define TYPE        0x53
   ```

2. **添加必要的头文件**：
   ```cpp
   #include <linux/ioctl.h>
   #include <sys/ioctl.h>
   #include <unistd.h>
   #include <fcntl.h>
   #include <sys/mman.h>
   #include <time.h>
   ```

### 方案2: 使用自动修复脚本
运行我创建的修复脚本：

```bash
chmod +x fix_and_compile.sh
./fix_and_compile.sh
```

## 编译步骤

### 1. 安装交叉编译工具链
```bash
sudo apt update
sudo apt install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
```

### 2. 使用修复后的.pro文件编译
```bash
# 创建build目录
mkdir build
cd build

# 设置环境变量
export CC=aarch64-linux-gnu-gcc
export CXX=aarch64-linux-gnu-g++

# 生成Makefile (使用修复后的.pro文件)
qmake ../ZYNQ_video_show_fixed.pro

# 编译
make -j$(nproc)
```

### 3. 验证编译结果
```bash
# 检查可执行文件
file ZYNQ_video_show
ls -lh ZYNQ_video_show
```

## 常见问题

### Q: 仍然出现ioctl相关错误
A: 确保包含了 `<linux/ioctl.h>` 和 `<sys/ioctl.h>` 头文件

### Q: 缺少Qt相关头文件
A: 确保安装了Qt开发包：
```bash
sudo apt install qt5-default qtbase5-dev
```

### Q: OpenCV库找不到
A: 检查 `3rdparty/opencv/opencv-linux-aarch64/` 目录是否存在

### Q: RKNN库错误
A: 确保 `3rdparty/rknpu2/Linux/aarch64/` 目录存在且包含 `librknnrt.so`

## 修复后的文件
- `pango_fun.h`: 修复了TYPE定义和添加了必要头文件
- `ZYNQ_video_show_fixed.pro`: 修复后的Qt项目文件
- `fix_and_compile.sh`: 自动修复和编译脚本

## 下一步
编译成功后，你可以：
1. 将可执行文件复制到目标ARM64设备
2. 设置正确的库路径
3. 运行程序进行测试

如果还有其他编译错误，请提供具体的错误信息，我会继续帮你解决。
