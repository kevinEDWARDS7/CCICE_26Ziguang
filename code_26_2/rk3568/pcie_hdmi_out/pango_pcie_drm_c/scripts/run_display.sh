#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

./pcie_probe_only --pcie /dev/pango_pci_driver

exec ./pango_pcie_drm_c \
    --pcie /dev/pango_pci_driver \
    --drm /dev/dri/card0 \
    --width 1280 \
    --height 720 \
    --line-bytes 2560 \
    "$@"
