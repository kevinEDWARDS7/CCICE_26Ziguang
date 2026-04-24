# HDMI

### **1. 编译 PCIe 内核驱动**

```bash
# 在干什么：进入驱动目录，使用当前板子上可用的内核头目录 /usr/src/linux-headers-6.1-rockchip 编译 PCIe 驱动。
cd /home/linaro/test_demo/pango_pcie_dma_alloc/driver
make clean
make -C /usr/src/linux-headers-6.1-rockchip M=$(pwd) modules
ls -l pango_pci_driver.ko
```

**预期成功输出**

```
... CC [M] ...
... LD [M] .../pango_pci_driver.ko
-rw-r--r-- ... pango_pci_driver.ko
```

**预期失败输出**

```
make[1]: *** No rule to make target 'modules'. Stop.
```

或

```
ls: cannot access 'pango_pci_driver.ko': No such file or directory
```

---

### **2. 加载 PCIe 驱动**

```bash
# 在干什么：卸载旧驱动并加载新编译的 pango_pci_driver.ko，确认设备节点存在。
cd /home/linaro/test_demo/pango_pcie_dma_alloc/driver
sudo rmmod pango_pci_driver 2>/dev/null || true
sudo insmod ./pango_pci_driver.ko
echo "insmod_exit=$?"
lsmod | grep pango_pci_driver
ls -l /dev/pango_pci_driver
```

**预期成功输出**

```
insmod_exit=0
pango_pci_driver ...
crw-rw-rw- ... /dev/pango_pci_driver
```

**预期失败输出**

```
insmod: ERROR: could not load module ./pango_pci_driver.ko: Invalid module format
insmod_exit=1
```

或

```
ls: cannot access '/dev/pango_pci_driver': No such file or directory
```

---

### **3. 编译 HDMI_OUT 用户态程序**

```bash
# 在干什么：编译 pcie_hdmi_out_drm，它才是真正运行的程序，不是 .c 文件本身。
cd /home/linaro/test_demo/pango_pcie_dma_alloc/pcie_hdmi_out
make clean
make CFLAGS="-O2 -Wall -Wextra $(pkg-config --cflags libdrm)"
ls -l pcie_hdmi_out_drm
file pcie_hdmi_out_drm
```

**预期成功输出**

```
... cc ... -o pcie_hdmi_out_drm ...
-rwxr-xr-x ... pcie_hdmi_out_drm
pcie_hdmi_out_drm: ELF 64-bit ... aarch64 ...
```

**预期失败输出**

```
... fatal error: drm.h: No such file or directory
```

或

```
ls: cannot access 'pcie_hdmi_out_drm': No such file or directory
```

---

### **4. 检查 HDMI 连接状态**

```bash
# 在干什么：确认 HDMI 已连接，否则即使程序启动，也不会是有效 HDMI 输出。
for f in status enabled dpms modes; do
    echo "==$f =="
    cat /sys/class/drm/card0-HDMI-A-1/$f 2>/dev/null || echo "N/A"
done
```

**预期成功输出**

```
== status ==
connected
== enabled ==
enabled
== dpms ==
On
== modes ==
1920x1080
1280x720
...
```

**预期失败输出**

```
== status ==
disconnected
```

---

### **5. 关闭桌面显示服务**

```bash
# 在干什么：停止 lightdm/Xorg，释放 /dev/dri/card0 给 FPGA 直出程序。
sudo systemctl stop lightdm
echo "stop_lightdm_exit=$?"
sudo fuser -v /dev/dri/card0
echo "fuser_exit=$?"
```

**预期成功输出**

```
stop_lightdm_exit=0
fuser_exit=1
```

**预期失败输出**

```
Failed to stop lightdm.service: ...
stop_lightdm_exit=1
```

或

```
/dev/dri/card0: ... Xorg ...
fuser_exit=0
```

---

### **6. 运行 HDMI_OUT 程序（持续运行）**

```bash
# 在干什么：启动 FPGA 到 HDMI 的 DRM 输出。
cd /home/linaro/test_demo/pango_pcie_dma_alloc/pcie_hdmi_out
sudo ./pcie_hdmi_out_drm \
    --pcie /dev/pango_pci_driver \
    --drm /dev/dri/card0 \
    --connector HDMI-A-1 \
    --width 1280 \
    --height 720 \
    --line-bytes 2560 \
    --src-format rgb565 \
    --fps 30
```

**预期成功输出**

```
DRM set: connector=... mode=1280x720 1280x720, crtc=..., pitch=...
start: src=1280x720 RGB565, display=1280x720, fps_limit=30, ...
```

**预期失败输出**

```
open pcie: Permission denied
```

或

```
connector HDMI-A-1 not found
```

或

```
warning: requested display mode ... not found ...
```

---

### **7. 运行 HDMI_OUT 程序（8 秒验证版）**

```bash
# 在干什么：如果你只想快速判断程序有没有持续跑起来，用 timeout 版本。
cd /home/linaro/test_demo/pango_pcie_dma_alloc/pcie_hdmi_out
sudo timeout 8s ./pcie_hdmi_out_drm \
    --pcie /dev/pango_pci_driver \
    --drm /dev/dri/card0 \
    --connector HDMI-A-1 \
    --width 1280 \
    --height 720 \
    --line-bytes 2560 \
    --src-format rgb565 \
    --fps 30
echo "app_exit=$?"
```

**预期成功输出**

```
DRM set: ...
start: ...
app_exit=124
```

**预期失败输出**

```
... error ...
app_exit=1
```

---

### **8. 恢复桌面显示服务**

```bash
# 在干什么：运行结束后重新启动图形桌面。
sudo systemctl start lightdm
echo "start_lightdm_exit=$?"
```

**预期成功输出**

```
start_lightdm_exit=0
```

**预期失败输出**

```
Failed to start lightdm.service: ...
start_lightdm_exit=1
```