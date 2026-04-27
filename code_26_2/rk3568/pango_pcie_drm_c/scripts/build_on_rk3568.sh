#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "error: required command not found: $1" >&2
        exit 1
    fi
}

require_cmd make

if command -v nproc >/dev/null 2>&1; then
    JOBS="$(nproc)"
else
    JOBS=1
fi

echo "== build user programs =="
make clean
make -j"$JOBS"

echo
echo "== select kernel headers =="
if [ -d "/lib/modules/$(uname -r)/build" ]; then
    KDIR="/lib/modules/$(uname -r)/build"
elif [ -d "/usr/src/linux-headers-6.1-rockchip" ]; then
    KDIR="/usr/src/linux-headers-6.1-rockchip"
else
    echo "error: kernel headers not found." >&2
    echo "checked: /lib/modules/$(uname -r)/build" >&2
    echo "checked: /usr/src/linux-headers-6.1-rockchip" >&2
    exit 1
fi
echo "KDIR=$KDIR"

echo
echo "== build driver =="
cd driver
make KDIR="$KDIR" clean
make KDIR="$KDIR" -j"$JOBS"

echo
echo "== artifacts =="
cd ..
ls -l pcie_probe_only pango_pcie_drm_c driver/pango_pci_driver.ko
if command -v file >/dev/null 2>&1; then
    file pcie_probe_only pango_pcie_drm_c driver/pango_pci_driver.ko
else
    echo "file command not found; skipped artifact type summary"
fi
