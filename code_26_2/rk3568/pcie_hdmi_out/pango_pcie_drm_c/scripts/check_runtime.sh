#!/bin/sh
set -u

cd "$(dirname "$0")/.."

echo "== local files =="
for f in ./pcie_probe_only ./pango_pcie_drm_c ./driver/pango_pci_driver.ko; do
    if [ -e "$f" ]; then
        ls -l "$f"
    else
        echo "missing: $f"
    fi
done

echo
echo "== device nodes =="
if [ -e /dev/pango_pci_driver ]; then
    ls -l /dev/pango_pci_driver
else
    echo "missing: /dev/pango_pci_driver"
fi
if [ -e /dev/dri/card0 ]; then
    ls -l /dev/dri/card0
else
    echo "missing: /dev/dri/card0"
fi
ls -l /dev/dri/* 2>/dev/null || true

echo
echo "== pci endpoint 0755 =="
lspci -nn 2>/dev/null | grep -i '0755' || echo "lspci did not show 0755 endpoint"

echo
echo "== loaded modules =="
lsmod | grep -i pango || echo "pango module is not loaded"

echo
echo "== ko metadata =="
modinfo ./driver/pango_pci_driver.ko 2>/dev/null || echo "modinfo failed for ./driver/pango_pci_driver.ko"

echo
echo "== recent dmesg =="
dmesg -T 2>/dev/null | egrep -i 'pango|pci_driver_probe|Vendor ID|Device ID|Link Speed|Link Width|MPS' | tail -80 || true

echo
echo "== libdrm pkg-config =="
pkg-config --cflags libdrm 2>/dev/null || echo "pkg-config --cflags libdrm failed"

echo
echo "Confirm the loaded pango_pci_driver module came from this project's ./driver/pango_pci_driver.ko, not an old code_26 driver."
