#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR/.."

APP=${APP:-./pango_pcie_drm_c}
APP_NAME=${APP_NAME:-pango_pcie_drm_c}
PROBE=${PROBE:-./pcie_probe_only}
DRIVER=${DRIVER:-./driver/pango_pci_driver.ko}
MODULE=${MODULE:-pango_pci_driver}
PCIE_DEV=${PCIE_DEV:-/dev/pango_pci_driver}
DRM_DEV=${DRM_DEV:-/dev/dri/card0}
WIDTH=${WIDTH:-1920}
HEIGHT=${HEIGHT:-1080}
LINE_BYTES=${LINE_BYTES:-3840}
DUMP_PATH=${DUMP_PATH:-/tmp/hdmi_pcie_sentinel.rgb565}
DUMP_LINES=${DUMP_LINES:-8}
DMA_SENTINEL=${DMA_SENTINEL:-0xa5}

usage() {
        printf '%s\n' \
                "Usage:" \
                "  $0 [app options]" \
                "  $0 -p|--probe-only" \
                "  $0 -t|--dump-test [dump path]" \
                "  $0 -c" \
                "  $0 -c all" \
                "" \
                "Commands:" \
                "  no command     Load this project's driver, probe PCIe, then start display." \
                "  -p, --probe-only" \
                "                 Load this project's driver, probe PCIe, then exit." \
                "  -t, --dump-test [dump path]" \
                "                 Load driver, probe PCIe, run one no-display DMA dump with sentinel." \
                "  -c             Stop the display application only." \
                "  -c all         Stop the display application and unload the driver module." \
                "" \
                "Environment overrides:" \
                "  DRIVER=$DRIVER" \
                "  PCIE_DEV=$PCIE_DEV" \
                "  DRM_DEV=$DRM_DEV" \
                "  WIDTH=$WIDTH HEIGHT=$HEIGHT LINE_BYTES=$LINE_BYTES" \
                "  DUMP_PATH=$DUMP_PATH DUMP_LINES=$DUMP_LINES DMA_SENTINEL=$DMA_SENTINEL"
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

check_programs() {
    if [ ! -x "$PROBE" ] || [ ! -x "$APP" ]; then
        echo "error: user programs not found; run ./scripts/build_on_rk3568.sh first" >&2
        echo "checked: $PROBE and $APP" >&2
        exit 1
    fi
}

find_pcie_bdf() {
    if command -v lspci >/dev/null 2>&1; then
        lspci -Dnn | awk '/0755:0755/{print $1; exit}'
    fi
}

print_pcie_status() {
    BDF="$(find_pcie_bdf)"

    echo
    echo "== PCIe status =="
    if [ -z "$BDF" ]; then
        echo "0755:0755 PCIe device not found by lspci"
        return 0
    fi

    echo "BDF=$BDF"
    SYS="/sys/bus/pci/devices/$BDF"
    if [ -r "$SYS/resource" ]; then
        echo "-- resources --"
        awk '{printf "BAR%d start=%s end=%s flags=%s\n", NR-1, $1, $2, $3}' "$SYS/resource"
    fi

    if command -v lspci >/dev/null 2>&1; then
        echo "-- link/driver --"
        lspci -s "$BDF" -vvv 2>/dev/null | grep -E "Control:|LnkSta:|Kernel driver|Region" || true
    fi

    echo "-- recent pango logs --"
    dmesg | grep -iE "pango|DMA control|BAR1|BAR0" | tail -40 || true
}

probe_pcie() {
    "$PROBE" --pcie "$PCIE_DEV"
    print_pcie_status
}

run_app() {
    exec "$APP" \
        --pcie "$PCIE_DEV" \
        --drm "$DRM_DEV" \
        --width "$WIDTH" \
        --height "$HEIGHT" \
        --line-bytes "$LINE_BYTES" \
        "$@"
}

run_dump_test() {
    echo "dumping one PCIe DMA frame to $DUMP_PATH"
    "$APP" \
        --pcie "$PCIE_DEV" \
        --drm "$DRM_DEV" \
        --width "$WIDTH" \
        --height "$HEIGHT" \
        --line-bytes "$LINE_BYTES" \
        --no-display \
        --frames 1 \
        --dump-lines "$DUMP_LINES" \
        --dump-frame "$DUMP_PATH" \
        --dma-sentinel "$DMA_SENTINEL"

    if [ -f "$DUMP_PATH" ]; then
        ls -l "$DUMP_PATH"
        if command -v hexdump >/dev/null 2>&1; then
            hexdump -C "$DUMP_PATH" | head -40
        fi
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

check_programs

load_driver
probe_pcie

if [ "${1:-}" = "-p" ] || [ "${1:-}" = "--probe-only" ]; then
    shift
    if [ "$#" -ne 0 ]; then
        usage >&2
        exit 2
    fi
    exit 0
fi

if [ "${1:-}" = "-t" ] || [ "${1:-}" = "--dump-test" ]; then
    shift
    if [ "${1:-}" != "" ]; then
        DUMP_PATH=$1
        shift
    fi
    if [ "$#" -ne 0 ]; then
        usage >&2
        exit 2
    fi
    run_dump_test
    exit 0
fi

run_app "$@"
