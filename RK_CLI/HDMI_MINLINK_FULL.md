# HDMI_MINLINK_FULL

### 1. 进入工程目录并定位 HDMI_OUT 源码目录

```bash
set -e
BASE=/home/linaro/test_demo/pango_pcie_dma_alloc
if [ -d "$BASE/pcie_hdmi_out" ]; then
  APPDIR="$BASE/pcie_hdmi_out"
elif [ -d "$BASE/pcie_hdmi_out_sync" ]; then
  APPDIR="$BASE/pcie_hdmi_out_sync"
else
  echo "[ERR] pcie_hdmi_out directory not found under $BASE"
  exit 1
fi

echo "APPDIR=$APPDIR"
cd "$APPDIR"
pwd
ls -l
```

### 2. 编译 PCIe 驱动并加载

```bash
set -e
cd /home/linaro/test_demo/pango_pcie_dma_alloc/driver
make clean
make -C /usr/src/linux-headers-6.1-rockchip M=$(pwd) modules
sudo rmmod pango_pci_driver 2>/dev/null || true
sudo insmod ./pango_pci_driver.ko
lsmod | grep pango_pci_driver
ls -l /dev/pango_pci_driver
```

### 3. 编译 HDMI_OUT 程序（自动选择 sync 或原版源码）

```bash
set -e
BASE=/home/linaro/test_demo/pango_pcie_dma_alloc
if [ -d "$BASE/pcie_hdmi_out" ]; then
  APPDIR="$BASE/pcie_hdmi_out"
elif [ -d "$BASE/pcie_hdmi_out_sync" ]; then
  APPDIR="$BASE/pcie_hdmi_out_sync"
else
  echo "[ERR] app dir not found"
  exit 1
fi
cd "$APPDIR"

SRC=""
if [ -f pcie_hdmi_out_drm_sync.c ]; then
  SRC=pcie_hdmi_out_drm_sync.c
elif [ -f pcie_hdmi_out_drm.c ]; then
  SRC=pcie_hdmi_out_drm.c
else
  echo "[ERR] no drm source file found"
  exit 1
fi

echo "using source: $SRC"

gcc -O2 -Wall -Wextra $(pkg-config --cflags libdrm) -o pcie_hdmi_out_drm "$SRC" -ldrm
ls -l pcie_hdmi_out_drm
file pcie_hdmi_out_drm
```

### 4. 释放 DRM 设备占用（如启用桌面）

```bash
sudo systemctl stop lightdm || true
sudo fuser -v /dev/dri/card0 || true
```

### 5. 运行最小链路（增强读回轮询版）

```bash
set -e
BASE=/home/linaro/test_demo/pango_pcie_dma_alloc
if [ -d "$BASE/pcie_hdmi_out" ]; then
  APPDIR="$BASE/pcie_hdmi_out"
elif [ -d "$BASE/pcie_hdmi_out_sync" ]; then
  APPDIR="$BASE/pcie_hdmi_out_sync"
else
  echo "[ERR] app dir not found"
  exit 1
fi
cd "$APPDIR"

sudo ./pcie_hdmi_out_drm \
  --pcie /dev/pango_pci_driver \
  --drm /dev/dri/card0 \
  --connector HDMI-A-1 \
  --width 1280 \
  --height 720 \
  --line-bytes 2560 \
  --src-format rgb565 \
  --rgb565-order normal \
  --fps 0 \
  --busy-wait 4000 \
  --dma-retries 8 \
  --retry-sleep-us 100 \
  --readback-polls 8 \
  --readback-poll-sleep-us 50 \
  --bootstrap-require-nonzero 1 \
  --debug \
  --debug-interval 1
```

### 6. 退出后恢复桌面（可选）

```bash
sudo systemctl start lightdm || true
```
