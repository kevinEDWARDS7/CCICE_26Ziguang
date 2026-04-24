# PCIE

### 1. 枚举 PCIe 设备

```bash
# 1. 枚举 PCIe 设备
lspci -nn
lspci -nn | grep -E "0755:0755|21:00.0"
```

**解释**

查看系统当前 PCIe 设备，并快速筛选 FPGA endpoint。

**目的**

确认 FPGA 设备已被 RK3568 枚举。

**成功预期输出**

```
0002:21:00.0 Memory controller [0580]: Device [0755:0755]
```

**失败预期输出**

```
(无 0755:0755 相关行)
```

---

### 2. 查看枚举细节（BAR/驱动绑定）

```bash
# 2. 查看枚举细节（BAR/驱动绑定）
lspci -vv -s 0002:21:00.0
sudo sh -c 'cat /sys/bus/pci/devices/0002:21:00.0/resource'
lspci -k -s 0002:21:00.0
```

**解释**

查看该设备 BAR 资源分配与内核驱动绑定状态。

**目的**

确认 BAR0 可用、驱动绑定正确。

**成功预期输出**

```
Region 0: Memory at f0200000 ... [size=4K]
Kernel driver in use: pango_pci_driver
resource 第一行非0，其余行可为0
```

**失败预期输出**

```
resource 全0
Kernel driver in use: (空)
```

---

### 3. 编译驱动

```bash
# 3. 编译驱动
cd /home/linaro/test_demo/pango_pcie_dma_alloc/driver
make clean
make -C /usr/src/linux-headers-6.1-rockchip M=$(pwd) modules
ls -l pango_pci_driver.ko
```

**解释**

使用板端内核头文件重新编译 pango_pci_driver.ko。

**目的**

确保驱动与当前内核匹配并生成可加载模块。

**成功预期输出**

```
LD [M] .../pango_pci_driver.ko
-rw-r--r-- ... pango_pci_driver.ko
```

**失败预期输出**

```
make ... Error 1
make ... Error 2
ls: cannot access 'pango_pci_driver.ko'
```

---

### 4. 重载驱动并验证节点

```bash
# 4. 重载驱动并验证节点
sudo rmmod pango_pci_driver
sudo insmod ./pango_pci_driver.ko
lsmod | grep pango_pci_driver
ls -l /dev/pango_pci_driver
dmesg | grep -iE "pango_pci_driver|pci_driver_probe|probe of|sysfs|ioremap result|pci_request_region" | tail -n 40
```

**解释**

卸载旧驱动后加载新驱动，并检查字符设备节点和关键 probe 日志。

**目的**

确保驱动真正生效，用户态程序可访问 /dev/pango_pci_driver。

**成功预期输出**

```
pango_pci_driver ...
/dev/pango_pci_driver
... pci_driver_probe ...
... pci_request_region result : 0
... ioremap result : 0
```

**失败预期输出**

```
ls: cannot access '/dev/pango_pci_driver': No such file or directory
probe ... failed with error -1
sysfs: cannot create duplicate filename '/class/pango_pci_driver'
```

---

### 5. 编译应用程序

```bash
# 5. 编译应用程序
cd /home/linaro/test_demo/pango_pcie_dma_alloc/app_pcie
make clean
make
ls -l build/app
```

**解释**

编译 GTK 用户态测试程序。

**目的**

生成最终可执行程序 build/app。

**成功预期输出**

```
gcc ... -o build/app ...
-rwxr-xr-x ... build/app
```

**失败预期输出**

```
Package gtk+-2.0 was not found in the pkg-config search path
fatal error: gtk/gtk.h: No such file or directory
```

---

### 6. 放开设备节点权限（普通用户运行 GUI）

```bash
# 6. 放开设备节点权限（普通用户运行 GUI）
sudo chmod 666 /dev/pango_pci_driver
ls -l /dev/pango_pci_driver
```

**解释**

给普通用户可读写权限。

**目的**

避免 ./app 报 Permission denied。

**成功预期输出**

```
crw-rw-rw- ... /dev/pango_pci_driver
```

**失败预期输出**

```
chmod: cannot access '/dev/pango_pci_driver': No such file or directory
```

---

### 7. 运行程序

```bash
# 7. 运行程序
cd /home/linaro/test_demo/pango_pcie_dma_alloc/app_pcie/build
./app
```

**解释**

启动测试 GUI 并读取 PCIe 配置与链路状态。

**目的**

验证“枚举 + 驱动 + 用户态”全链路打通。

**成功预期输出**

```
[ INFO  ] PCIe link successful
Vendor ID = 0755
Device ID = 0755
Link Status = Up
```

**失败预期输出**

```
open fail
: Permission denied
[ ERROR ] PCIe link failure !!!
或
Gtk-WARNING **: cannot open display
```

---

### 8. 最终验收检查（可选）

```bash
# 8. 最终验收检查（可选）
lspci -nn | grep 0755:0755
lsmod | grep pango_pci_driver
ls -l /dev/pango_pci_driver
```

**解释**

(无额外解释)

**目的**

(无额外目的说明)

**成功预期输出**

```
有 0755:0755
有 pango_pci_driver
/dev/pango_pci_driver 存在且可访问
```

**失败预期输出**

```
任一项缺失
```