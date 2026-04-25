#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

if lsmod | grep -q '^pango_pci_driver'; then
    echo "unloading existing pango_pci_driver"
    rmmod pango_pci_driver
fi

echo "loading ./driver/pango_pci_driver.ko"
insmod ./driver/pango_pci_driver.ko

if [ -e /dev/pango_pci_driver ]; then
    ls -l /dev/pango_pci_driver
else
    echo "error: /dev/pango_pci_driver was not created" >&2
    exit 1
fi

dmesg -T | egrep -i 'pango|pci_driver_probe|Vendor ID|Device ID|Link Speed|Link Width|MPS' | tail -80 || true
