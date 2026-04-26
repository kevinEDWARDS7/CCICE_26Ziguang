#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

APP=./pango_pcie_drm_c
APP_NAME=pango_pcie_drm_c
PROBE=./pcie_probe_only
DRIVER=./driver/pango_pci_driver.ko
MODULE=pango_pci_driver
PCIE_DEV=/dev/pango_pci_driver
DRM_DEV=/dev/dri/card0

usage() {
    cat <<EOF
Usage:
  $0 [app options]
  $0 -c
  $0 -c all

Commands:
  no -c      Load this project's driver, probe PCIe, then start display.
  -c         Stop the display application only.
  -c all     Stop the display application and unload the driver module.
EOF
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "error: run this script with sudo" >&2
        exit 1
    fi
}

app_pids() {
    if command -v pgrep >/dev/null 2>&1; then
        pgrep -f '(^|/| )pango_pcie_drm_c( |$)' 2>/dev/null || true
    elif command -v pidof >/dev/null 2>&1; then
        pidof "$APP_NAME" 2>/dev/null || true
    fi
}

stop_app() {
    PIDS="$(app_pids)"
    if [ -z "$PIDS" ]; then
        echo "$APP_NAME is not running"
        return 0
    fi

    echo "stopping $APP_NAME: $PIDS"
    kill $PIDS 2>/dev/null || true
    sleep 1
    PIDS="$(app_pids)"
    if [ -n "$PIDS" ]; then
        echo "forcing $APP_NAME to stop: $PIDS"
        kill -KILL $PIDS 2>/dev/null || true
    fi
}

unload_driver() {
    if lsmod | grep -q "^$MODULE"; then
        echo "unloading $MODULE"
        rmmod "$MODULE"
    else
        echo "$MODULE is not loaded"
    fi
}

load_driver() {
    if [ ! -f "$DRIVER" ]; then
        echo "error: $DRIVER not found; run ./scripts/build_on_rk3568.sh first" >&2
        exit 1
    fi

    if lsmod | grep -q "^$MODULE"; then
        unload_driver
    fi

    echo "loading $DRIVER"
    insmod "$DRIVER"

    if [ ! -e "$PCIE_DEV" ]; then
        echo "error: $PCIE_DEV was not created" >&2
        exit 1
    fi
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

if [ "${1:-}" = "-c" ]; then
    require_root
    shift
    CLEAN_MODE=app
    if [ "${1:-}" = "all" ]; then
        CLEAN_MODE=all
        shift
    fi
    if [ "$#" -ne 0 ]; then
        usage >&2
        exit 2
    fi

    stop_app
    if [ "$CLEAN_MODE" = "all" ]; then
        unload_driver
    fi
    exit 0
fi

require_root

if [ ! -x ./pcie_probe_only ] || [ ! -x ./pango_pcie_drm_c ]; then
    echo "error: user programs not found; run ./scripts/build_on_rk3568.sh first" >&2
    exit 1
fi

load_driver

"$PROBE" --pcie "$PCIE_DEV"

exec "$APP" \
    --pcie "$PCIE_DEV" \
    --drm "$DRM_DEV" \
    --width 1920 \
    --height 1080 \
    --line-bytes 3840 \
    "$@"
