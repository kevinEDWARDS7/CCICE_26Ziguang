#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${ROOT_DIR:-/home/linaro/test_demo/pango_pcie_dma_alloc}"
DRIVER_DIR="$ROOT_DIR/driver"
APP_PCIE_DIR="$ROOT_DIR/app_pcie"
APP_HDMI_DIR="$ROOT_DIR/pcie_hdmi_out"
KERNEL_HEADERS="${KERNEL_HEADERS:-/usr/src/linux-headers-6.1-rockchip}"
PCI_DEV_NODE="${PCI_DEV_NODE:-/dev/pango_pci_driver}"
DRM_DEV_NODE="${DRM_DEV_NODE:-/dev/dri/card0}"
DRM_CONNECTOR="${DRM_CONNECTOR:-HDMI-A-1}"
WIDTH="${WIDTH:-1280}"
HEIGHT="${HEIGHT:-720}"
LINE_BYTES="${LINE_BYTES:-2560}"
SRC_FORMAT="${SRC_FORMAT:-rgb565}"
FPS="${FPS:-30}"
PCIE_BDF="${PCIE_BDF:-0002:21:00.0}"
PCIE_ID_GREP="${PCIE_ID_GREP:-0755:0755}"
LIGHTDM_SERVICE="${LIGHTDM_SERVICE:-lightdm}"
RUN_SECONDS="${RUN_SECONDS:-8}"

LIGHTDM_STOPPED=0

log() {
    printf '[INFO] %s\n' "$*"
}

warn() {
    printf '[WARN] %s\n' "$*" >&2
}

die() {
    printf '[ERROR] %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
用法:
  bash rk3568_onekey_run.sh pcie_app
  bash rk3568_onekey_run.sh hdmi_out
  bash rk3568_onekey_run.sh hdmi_test

说明:
  pcie_app   编译并运行 GTK PCIe 测试程序 build/app
  hdmi_out   编译并持续运行 pcie_hdmi_out_drm
  hdmi_test  编译并运行 8 秒 HDMI 输出验证，超时退出算正常

可选环境变量:
  ROOT_DIR=/home/linaro/test_demo/pango_pcie_dma_alloc
  KERNEL_HEADERS=/usr/src/linux-headers-6.1-rockchip
  DRM_CONNECTOR=HDMI-A-1
  WIDTH=1280 HEIGHT=720 LINE_BYTES=2560 SRC_FORMAT=rgb565 FPS=30
  RUN_SECONDS=8
EOF
}

ensure_dir() {
    local path="$1"
    [[ -d "$path" ]] || die "目录不存在: $path"
}

check_pcie_enum() {
    log "检查 PCIe 枚举"
    if ! lspci -nn | grep -E "$PCIE_ID_GREP|${PCIE_BDF#*:}" >/dev/null; then
        die "未找到目标 PCIe 设备，先确认 FPGA 已上电且链路正常"
    fi
    lspci -nn | grep -E "$PCIE_ID_GREP|${PCIE_BDF#*:}" || true
}

build_driver() {
    ensure_dir "$DRIVER_DIR"
    [[ -d "$KERNEL_HEADERS" ]] || die "内核头目录不存在: $KERNEL_HEADERS"

    log "编译 PCIe 驱动"
    cd "$DRIVER_DIR"
    make clean
    make -C "$KERNEL_HEADERS" M="$PWD" modules
    [[ -f pango_pci_driver.ko ]] || die "驱动未生成: $DRIVER_DIR/pango_pci_driver.ko"
    ls -l pango_pci_driver.ko
}

reload_driver() {
    ensure_dir "$DRIVER_DIR"

    log "重载 PCIe 驱动"
    cd "$DRIVER_DIR"
    sudo rmmod pango_pci_driver 2>/dev/null || true
    sudo insmod ./pango_pci_driver.ko
    lsmod | grep pango_pci_driver || die "驱动未出现在 lsmod 中"
    [[ -e "$PCI_DEV_NODE" ]] || die "设备节点不存在: $PCI_DEV_NODE"
    sudo chmod 666 "$PCI_DEV_NODE"
    ls -l "$PCI_DEV_NODE"
}

build_pcie_app() {
    ensure_dir "$APP_PCIE_DIR"

    log "编译 PCIe GTK 程序"
    cd "$APP_PCIE_DIR"
    make clean
    make
    [[ -x build/app ]] || die "程序未生成: $APP_PCIE_DIR/build/app"
    ls -l build/app
}

run_pcie_app() {
    build_pcie_app

    log "运行 PCIe GTK 程序"
    cd "$APP_PCIE_DIR/build"
    ./app
}

build_hdmi_app() {
    ensure_dir "$APP_HDMI_DIR"

    log "编译 HDMI DRM 程序"
    cd "$APP_HDMI_DIR"
    make clean
    make CFLAGS="-O2 -Wall -Wextra $(pkg-config --cflags libdrm)"
    [[ -x pcie_hdmi_out_drm ]] || die "程序未生成: $APP_HDMI_DIR/pcie_hdmi_out_drm"
    ls -l pcie_hdmi_out_drm
    file pcie_hdmi_out_drm
}

check_hdmi_status() {
    local base="/sys/class/drm/card0-${DRM_CONNECTOR}"
    [[ -d "$base" ]] || die "DRM connector 不存在: $base"

    log "检查 HDMI 连接状态"
    for f in status enabled dpms modes; do
        printf '== %s ==\n' "$f"
        cat "$base/$f" 2>/dev/null || echo "N/A"
    done

    grep -qx 'connected' "$base/status" || die "HDMI 未连接: $DRM_CONNECTOR"
}

stop_lightdm() {
    if systemctl is-active --quiet "$LIGHTDM_SERVICE"; then
        log "停止桌面服务: $LIGHTDM_SERVICE"
        sudo systemctl stop "$LIGHTDM_SERVICE"
        LIGHTDM_STOPPED=1
    else
        warn "$LIGHTDM_SERVICE 未运行，跳过 stop"
    fi

    if sudo fuser -v "$DRM_DEV_NODE"; then
        die "$DRM_DEV_NODE 仍被占用，无法直接接管 DRM"
    fi
}

restore_lightdm() {
    if [[ "$LIGHTDM_STOPPED" -eq 1 ]]; then
        log "恢复桌面服务: $LIGHTDM_SERVICE"
        sudo systemctl start "$LIGHTDM_SERVICE" || warn "恢复 $LIGHTDM_SERVICE 失败，请手动执行 sudo systemctl start $LIGHTDM_SERVICE"
    fi
}

run_hdmi_app() {
    local mode="$1"
    local app_exit=0

    build_hdmi_app
    check_hdmi_status
    stop_lightdm

    trap restore_lightdm EXIT

    log "运行 HDMI DRM 程序"
    cd "$APP_HDMI_DIR"

    if [[ "$mode" == "test" ]]; then
        set +e
        sudo timeout "${RUN_SECONDS}s" ./pcie_hdmi_out_drm \
            --pcie "$PCI_DEV_NODE" \
            --drm "$DRM_DEV_NODE" \
            --connector "$DRM_CONNECTOR" \
            --width "$WIDTH" \
            --height "$HEIGHT" \
            --line-bytes "$LINE_BYTES" \
            --src-format "$SRC_FORMAT" \
            --fps "$FPS"
        app_exit=$?
        set -e
        if [[ "$app_exit" -ne 124 ]]; then
            die "HDMI 测试异常退出，退出码: $app_exit"
        fi
        log "HDMI 测试结束，timeout 退出码 124 属于预期"
    else
        sudo ./pcie_hdmi_out_drm \
            --pcie "$PCI_DEV_NODE" \
            --drm "$DRM_DEV_NODE" \
            --connector "$DRM_CONNECTOR" \
            --width "$WIDTH" \
            --height "$HEIGHT" \
            --line-bytes "$LINE_BYTES" \
            --src-format "$SRC_FORMAT" \
            --fps "$FPS"
    fi
}

main() {
    local cmd="${1:-}"
    [[ -n "$cmd" ]] || {
        usage
        exit 1
    }

    case "$cmd" in
        -h|--help|help)
            usage
            exit 0
            ;;
    esac

    check_pcie_enum
    build_driver
    reload_driver

    case "$cmd" in
        pcie_app)
            run_pcie_app
            ;;
        hdmi_out)
            run_hdmi_app run
            ;;
        hdmi_test)
            run_hdmi_app test
            ;;
        *)
            usage
            die "不支持的子命令: $cmd"
            ;;
    esac
}

main "$@"
