# HDMI_MINLINK_QUICK

### 1. 快速重载驱动

```bash
set -e
cd /home/linaro/test_demo/pango_pcie_dma_alloc/driver
sudo rmmod pango_pci_driver 2>/dev/null || true
sudo insmod ./pango_pci_driver.ko
lsmod | grep pango_pci_driver
ls -l /dev/pango_pci_driver
```

### 2. 8 秒烟测（用于判断是否仍是全零）

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

sudo systemctl stop lightdm || true

sudo timeout 8s ./pcie_hdmi_out_drm \
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

echo "app_exit=$?"
```

### 3. 关键日志判据（直接看终端输出）

```text
1) all_zero 不再持续快速增长（或明显低于 dma_ok_lines）
2) late_ready > 0：说明轮询确实捕获到了“晚到数据”
3) boot_wait 启动后趋缓：说明已逐步锁定非零流
4) 画面从黑屏进入稳定非零图样
```

### 4. 恢复桌面（可选）

```bash
sudo systemctl start lightdm || true
```
