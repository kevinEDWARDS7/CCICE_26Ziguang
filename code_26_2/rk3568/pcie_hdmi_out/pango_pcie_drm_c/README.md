# pango_pcie_drm_c

## 工程目标

本工程实现 RK3568 侧基础图像链路：

```text
HDMI IN -> FPGA -> PCIe DMA -> RK3568 -> DRM/KMS -> HDMI OUT
```

当前只移植基础通信、收帧、格式转换和 HDMI OUT 显示，不移植 YOLO、RKNN、LPRNet、OpenCV 后处理和 Qt UI。

## code_25 参考来源

重点参考文件：

- `code_25/rk_new12/pcie_yolo/FPGA_pcie.h`
- `code_25/rk_new12/pcie_yolo/FPGA_pcie.cpp`
- `code_25/rk_new12/pcie_yolo/mainwindow.cpp`
- `code_25/rk_new12/pcie_yolo/mainwindow.h`
- `code_25/rk_new12/pcie_yolo/main.cpp`
- `code_25/rk_new12/pcie_yolo/RK3568_PCIE_SHOW.pro`
- `code_25/README_dl_pcie_yolo_notes.md`

仓库中的 `code_25` 没有找到可直接复制的 `pango_pci_driver.c/.h` 源码目录，只找到已编译的 `code_25/dl.ko` 和 `FPGA_pcie.*` 中暴露的 ioctl/结构体 ABI。因此本工程 driver 以 code_25 用户态 ABI 和 `dl.ko` 符号中可见的 Pango 驱动接口为准，补齐独立源码；不要把 code_26 旧驱动作为运行标准加载。

## 移植内容

已移植/保留：

- `/dev/pango_pci_driver` 设备路径。
- code_25 `FPGA_pcie.h` 中的 ioctl 编号。
- `COMMAND_OPERATION`、`DMA_OPERATION`、`PCI_DEVICE_INFO` 等用户态 ABI。
- `IMAGE_WIDTH=1280`、`IMAGE_HEIGHT=720`、`LINE_BYTES=2560`。
- `FPGA_pcie.cpp::getDevice()` 的 `PCI_READ_DATA_CMD`、`PCI_SET_CONFIG`、`PCI_MAP_BAR0_CMD` 准备流程。
- `FPGA_pcie.cpp::run()` 的逐行 DMA 收帧流程。
- `mainwindow.cpp` 中 RGB565 显示语义，对应这里的 RGB565 -> XRGB8888 DRM 输出。

未移植：

- Qt UI。
- RKNN/YOLO。
- OpenCV/RGA 推理与后处理。
- 车牌识别相关逻辑。

## ABI 一致性

`include/pango_pcie_abi.h` 只包含用户态需要的宏和结构体。`driver/pango_pci_driver.h` 中对应的 ioctl 编号、`BAR_BASE_INFO`、`CAP_INFO`、`CAP_LIST`、`PCI_DEVICE_INFO`、`LOAD_DATA_INFO`、`PCI_LOAD_INFO`、`COMMAND_OPERATION`、`CONFIG_OPERATION`、`DMA_DATA`、`DMA_OPERATION`、`PERFORMANCE_OPERATION` 与用户态头文件保持一致。

`src/main.c` 调用的 ioctl：

- `PCI_READ_DATA_CMD`
- `PCI_SET_CONFIG`
- `PCI_MAP_BAR0_CMD`
- `PCI_MAP_ADDR_CMD`
- `PCI_DMA_WRITE_CMD`
- `PCI_READ_FROM_KERNEL_CMD`
- `PCI_UMAP_ADDR_CMD`

这些在 `driver/pango_pci_driver.c` 的 `pango_cdev_ioctl()` 中都有对应 `case`。未知 ioctl 返回 `-ENOTTY`。

## 收帧对应关系

`src/main.c::pcie_read_frame_rgb565()` 对应 code_25 `FPGA_pcie.cpp::run()`：

```c
dma.current_len = line_bytes / 4;
dma.offset_addr = 0;
ioctl(fd, PCI_MAP_ADDR_CMD, &dma);

for each line:
    memset(dma.data.read_buf, 0, DMA_MAX_PACKET_SIZE);
    ioctl(fd, PCI_DMA_WRITE_CMD, &dma);
    busy_delay(delay_loops);
    ioctl(fd, PCI_READ_FROM_KERNEL_CMD, &dma);
    memcpy(frame + line * line_bytes, dma.data.read_buf, line_bytes);

ioctl(fd, PCI_UMAP_ADDR_CMD, &dma);
```

默认 `--delay-loops 4000`，与 code_25 注释中的逐行延时一致。

## 编译依赖

用户态：

- `gcc`
- `make`
- `pkg-config`
- `libdrm-dev` 或等价开发包

驱动：

- RK3568 当前内核对应 headers
- 默认路径 `/lib/modules/$(uname -r)/build`
- 如果板端 `/lib/modules/$(uname -r)/build` 不存在，但 `/usr/src/linux-headers-6.1-rockchip` 存在，驱动编译必须显式指定 `KDIR=/usr/src/linux-headers-6.1-rockchip`。

## 编译

驱动在 RK3568 板端编译：

```sh
cd pango_pcie_drm_c/driver
make KDIR=/usr/src/linux-headers-6.1-rockchip clean
make KDIR=/usr/src/linux-headers-6.1-rockchip -j$(nproc)
```

如 headers 在自定义路径：

```sh
make KDIR=/path/to/linux-headers clean
make KDIR=/path/to/linux-headers -j$(nproc)
```

用户态：

```sh
cd pango_pcie_drm_c
make clean
make
```

生成：

- `pcie_probe_only`
- `pango_pcie_drm_c`
- `driver/pango_pci_driver.ko`

## 加载/卸载驱动

如果脚本没有执行权限：

```sh
chmod +x scripts/*.sh
```

卸载旧驱动：

```sh
sudo ./scripts/unload_driver.sh
```

加载本工程驱动：

```sh
sudo ./scripts/load_driver.sh
```

必须确认当前加载的是本目录 `./driver/pango_pci_driver.ko`，不是 code_26 旧驱动。

## 运行前检查

```sh
sudo ./scripts/check_runtime.sh
```

该脚本只检查环境，不启动 DMA。

## PCIe 安全探测

```sh
sudo ./pcie_probe_only
```

输出包括 vendor_id、device_id、revision_id、class、link_speed、link_width、mps、mrrs、BAR0-BAR5。若 vendor/device/link/mps 无效，会打印：

```text
PCIe probe invalid. Refuse DMA.
```

probe 无效时禁止运行 DMA 显示程序。

## 显示程序

单帧安全测试：

```sh
sudo ./pango_pcie_drm_c --frames 1
```

连续显示：

```sh
sudo ./pango_pcie_drm_c
```

也可以使用脚本，脚本会先运行 `pcie_probe_only`：

```sh
sudo ./scripts/run_display.sh --frames 1
sudo ./scripts/run_display.sh
```

参数：

- `--pcie PATH`，默认 `/dev/pango_pci_driver`
- `--drm PATH`，默认 `/dev/dri/card0`
- `--width N`，默认 `1280`
- `--height N`，默认 `720`
- `--line-bytes N`，默认 `2560`
- `--frames N`，默认 `0`，表示 Ctrl+C 前持续运行
- `--delay-loops N`，默认 `4000`

DRM/KMS 会自动选择 connected connector，优先 1280x720；如果没有该模式，选择 preferred mode。显示 buffer 为 XRGB8888 dumb buffer。

## 常见问题

`lspci` 看不到 `0755:0755`：

- 检查 FPGA bitstream 是否加载。
- 检查 PCIe reset、时钟、电源和端点模式。
- 重新上电后再 `lspci -nn`。

`insmod` 失败：

- 确认 ko 与当前 RK3568 内核版本匹配。
- 用 `dmesg -T` 查看 vermagic、符号或签名错误。

`/dev/pango_pci_driver` 不存在：

- 检查 `lsmod | grep pango`。
- 检查 `dmesg -T | grep -i pango`。
- 确认 udev/devtmpfs 正常。

`PCIe probe invalid`：

- 先确认 `lspci -nn` 中有 `0755:0755`。
- 检查 dmesg 中 Vendor ID、Device ID、Link Speed、Link Width、MPS。
- probe 无效时不要继续 DMA。

`PCI_DMA_WRITE_CMD` 失败：

- 检查驱动是否为本工程 ko。
- 检查 line-bytes 是否超过 `DMA_MAX_PACKET_SIZE=4096`。
- 检查 FPGA 侧是否已准备好响应 DMA 写请求。

`PCI_READ_FROM_KERNEL_CMD` 失败：

- 检查是否先成功执行了 `PCI_MAP_ADDR_CMD`。
- 检查驱动日志中是否存在 DMA buffer 分配失败。

`drmModeSetCrtc failed`：

- 常见原因是 Weston/X11/桌面占用了 DRM master。
- 停止显示服务，或切到可获取 DRM master 的 tty 运行。

`no connected DRM connector`：

- 检查 HDMI OUT 线缆和显示器。
- 用 `modetest` 或 `/sys/class/drm` 查看 connector 状态。

画面颜色异常：

- 当前按小端 RGB565 解析：低字节在前。
- 如果 FPGA 输出为 BGR565 或字节序相反，需要调整 `rgb565_to_xrgb8888()` 的位域或读取顺序。

画面错行/撕裂：

- 确认 FPGA 每行输出为 2560 字节。
- 调整 `--delay-loops`。
- 确认 FPGA 端帧/行同步和 DMA 请求节拍。

RK3568 卡死或 Oops：

- 先只跑 `pcie_probe_only`。
- 再跑 `--frames 1`。
- 检查 DMA 长度、BAR0 映射、驱动 remove 资源释放。

## 推荐验证顺序

```sh
cd pango_pcie_drm_c/driver
make KDIR=/usr/src/linux-headers-6.1-rockchip clean
make KDIR=/usr/src/linux-headers-6.1-rockchip -j$(nproc)
sudo ./../scripts/unload_driver.sh
sudo ./../scripts/load_driver.sh
cd ..
make clean
make
chmod +x scripts/*.sh
sudo ./scripts/check_runtime.sh
sudo ./pcie_probe_only
sudo ./pango_pcie_drm_c --frames 1
sudo ./pango_pcie_drm_c
```

## FPGA 侧依赖

本工程默认 FPGA 侧 bitstream 已正确完成 HDMI IN/图像输入、RGB565 组织、PCIe endpoint 枚举、DMA 请求响应和每行 2560 字节输出。RK3568 侧无法替代 FPGA 侧时序、帧同步和数据格式保证。
