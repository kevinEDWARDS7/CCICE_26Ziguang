#!/bin/bash

# ZYNQ视频接收程序交叉编译脚本

set -e

# 配置参数
PROJECT_NAME="ZYNQ_video_show"
TARGET_ARCH="aarch64"
CROSS_COMPILE_PREFIX="aarch64-linux-gnu-"
QT_DIR="/opt/qt5-aarch64"  # 根据实际Qt安装路径调整
OPENCV_DIR="./3rdparty/opencv/opencv-linux-aarch64"
RGA_DIR="./3rdparty/librga/Linux/aarch64"
RKNN_DIR="./3rdparty/rknpu2/Linux/aarch64"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印函数
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查依赖
check_dependencies() {
    print_info "检查交叉编译工具链..."
    
    if ! command -v ${CROSS_COMPILE_PREFIX}gcc &> /dev/null; then
        print_error "交叉编译工具链未安装，请先运行 setup_cross_compile.sh"
        exit 1
    fi
    
    if [ ! -d "$QT_DIR" ]; then
        print_warning "Qt交叉编译库未找到，请先安装Qt交叉编译环境"
        print_warning "可以使用 setup_qt_simple.sh 或手动安装"
    fi
    
    if [ ! -d "$OPENCV_DIR" ]; then
        print_error "OpenCV库目录不存在: $OPENCV_DIR"
        exit 1
    fi
    
    if [ ! -d "$RGA_DIR" ]; then
        print_error "RGA库目录不存在: $RGA_DIR"
        exit 1
    fi
    
    if [ ! -d "$RKNN_DIR" ]; then
        print_error "RKNN库目录不存在: $RKNN_DIR"
        exit 1
    fi
    
    print_info "依赖检查完成"
}

# 设置环境变量
setup_environment() {
    print_info "设置交叉编译环境变量..."
    
    export CC=${CROSS_COMPILE_PREFIX}gcc
    export CXX=${CROSS_COMPILE_PREFIX}g++
    export AR=${CROSS_COMPILE_PREFIX}ar
    export STRIP=${CROSS_COMPILE_PREFIX}strip
    export PKG_CONFIG_PATH="/usr/lib/${TARGET_ARCH}-linux-gnu/pkgconfig"
    
    # Qt环境变量
    if [ -d "$QT_DIR" ]; then
        export QTDIR="$QT_DIR"
        export PATH="$QT_DIR/bin:$PATH"
        export LD_LIBRARY_PATH="$QT_DIR/lib:$LD_LIBRARY_PATH"
    fi
    
    print_info "环境变量设置完成"
}

# 创建交叉编译的.pro文件
create_cross_pro_file() {
    print_info "创建交叉编译配置文件..."
    
    cat > ${PROJECT_NAME}_cross.pro << EOF
QT       += core gui network

greaterThan(QT_MAJOR_VERSION, 4): QT += widgets gui

CONFIG += c++17

TARGET = ${PROJECT_NAME}
TEMPLATE = app

DEFINES += QT_DEPRECATED_WARNINGS

# 交叉编译配置
CONFIG += cross_compile
QMAKE_CC = ${CROSS_COMPILE_PREFIX}gcc
QMAKE_CXX = ${CROSS_COMPILE_PREFIX}g++
QMAKE_LINK = ${CROSS_COMPILE_PREFIX}g++
QMAKE_AR = ${CROSS_COMPILE_PREFIX}ar
QMAKE_STRIP = ${CROSS_COMPILE_PREFIX}strip

# 源文件
SOURCES += \\
    main.cpp \\
    mainwindow.cpp \\
    pango_fun.cpp \\
    pcie_recv_thread.cpp \\
    yolov11_detector.cpp \\
    file_utils.c \\
    image_utils.c

HEADERS += \\
    mainwindow.h \\
    pango_fun.h \\
    pcie_recv_thread.h \\
    yolov11_detector.h \\
    common.h \\
    file_utils.h \\
    image_utils.h \\
    adc_draw_wave.h

FORMS += \\
    mainwindow.ui

# OpenCV配置
INCLUDEPATH += \$\$_PRO_FILE_PWD_/3rdparty/opencv/opencv-linux-aarch64/include
LIBS += -L\$\$_PRO_FILE_PWD_/3rdparty/opencv/opencv-linux-aarch64/lib \\
        -lopencv_core \\
        -lopencv_imgcodecs \\
        -lopencv_imgproc \\
        -lopencv_highgui \\
        -lopencv_videoio

# RGA库配置
INCLUDEPATH += \$\$_PRO_FILE_PWD_/3rdparty/librga/include
LIBS += -L\$\$_PRO_FILE_PWD_/3rdparty/librga/Linux/aarch64 -lrga

# RKNN库配置
INCLUDEPATH += \$\$_PRO_FILE_PWD_/3rdparty/rknpu2/include
LIBS += -L\$\$_PRO_FILE_PWD_/3rdparty/rknpu2/Linux/aarch64 -lrknnrt

# 链接器配置
QMAKE_LFLAGS += -Wl,-rpath-link,\$\$_PRO_FILE_PWD_/3rdparty/opencv/opencv-linux-aarch64/lib
QMAKE_LFLAGS += -Wl,-rpath-link,\$\$_PRO_FILE_PWD_/3rdparty/librga/Linux/aarch64
QMAKE_LFLAGS += -Wl,-rpath-link,\$\$_PRO_FILE_PWD_/3rdparty/rknpu2/Linux/aarch64

# 部署配置
target.path = /opt/\$\${TARGET}/bin
INSTALLS += target

RC_ICONS = favicon.ico
EOF

    print_info "交叉编译配置文件创建完成: ${PROJECT_NAME}_cross.pro"
}

# 编译项目
build_project() {
    print_info "开始编译项目..."
    
    # 清理之前的编译文件
    if [ -d "build-cross" ]; then
        rm -rf build-cross
    fi
    mkdir build-cross
    cd build-cross
    
    # 生成Makefile
    print_info "生成Makefile..."
    qmake ../${PROJECT_NAME}_cross.pro
    
    # 编译
    print_info "开始编译..."
    make -j\$(nproc)
    
    if [ $? -eq 0 ]; then
        print_info "编译成功！"
        print_info "可执行文件位置: build-cross/${PROJECT_NAME}"
        
        # 显示文件信息
        file ${PROJECT_NAME}
        ls -lh ${PROJECT_NAME}
    else
        print_error "编译失败！"
        exit 1
    fi
}

# 创建部署包
create_deployment_package() {
    print_info "创建部署包..."
    
    DEPLOY_DIR="deploy-${TARGET_ARCH}"
    rm -rf $DEPLOY_DIR
    mkdir -p $DEPLOY_DIR
    
    # 复制可执行文件
    cp build-cross/${PROJECT_NAME} $DEPLOY_DIR/
    
    # 复制依赖库
    mkdir -p $DEPLOY_DIR/lib
    cp -r 3rdparty/opencv/opencv-linux-aarch64/lib/* $DEPLOY_DIR/lib/ 2>/dev/null || true
    cp -r 3rdparty/librga/Linux/aarch64/* $DEPLOY_DIR/lib/ 2>/dev/null || true
    cp -r 3rdparty/rknpu2/Linux/aarch64/* $DEPLOY_DIR/lib/ 2>/dev/null || true
    
    # 复制模型文件
    mkdir -p $DEPLOY_DIR/models
    cp models/*.rknn $DEPLOY_DIR/models/ 2>/dev/null || true
    
    # 创建启动脚本
    cat > $DEPLOY_DIR/run.sh << 'EOF'
#!/bin/bash
export LD_LIBRARY_PATH=./lib:$LD_LIBRARY_PATH
./ZYNQ_video_show
EOF
    chmod +x $DEPLOY_DIR/run.sh
    
    # 创建README
    cat > $DEPLOY_DIR/README.md << EOF
# ZYNQ视频接收程序部署包

## 文件说明
- ZYNQ_video_show: 主程序可执行文件
- lib/: 依赖库目录
- models/: AI模型文件目录
- run.sh: 启动脚本

## 运行方法
\`\`\`bash
./run.sh
\`\`\`

## 系统要求
- ARM64架构 (aarch64)
- Linux系统
- 支持RKNN NPU的设备
EOF
    
    print_info "部署包创建完成: $DEPLOY_DIR"
    print_info "可以将整个 $DEPLOY_DIR 目录复制到目标设备运行"
}

# 主函数
main() {
    print_info "开始交叉编译 ZYNQ视频接收程序..."
    
    check_dependencies
    setup_environment
    create_cross_pro_file
    build_project
    create_deployment_package
    
    print_info "交叉编译完成！"
    print_info "部署包位置: deploy-${TARGET_ARCH}/"
}

# 运行主函数
main "$@"
