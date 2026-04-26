#!/bin/bash

# 修复编译错误并交叉编译ZYNQ视频接收程序

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 修复编译错误
fix_compile_errors() {
    print_step "修复编译错误..."
    
    # 检查pango_fun.h中的TYPE定义
    if grep -q "#define TYPE.*'S'" pango_fun.h; then
        print_info "修复pango_fun.h中的TYPE定义..."
        sed -i "s/#define TYPE.*'S'/#define TYPE\t\t\t\t\t0x53/" pango_fun.h
    fi
    
    # 检查是否包含必要的头文件
    if ! grep -q "#include <linux/ioctl.h>" pango_fun.h; then
        print_info "添加必要的头文件到pango_fun.h..."
        sed -i '/#include <QtWidgets>/a #include <linux/ioctl.h>\n#include <sys/ioctl.h>\n#include <unistd.h>\n#include <fcntl.h>\n#include <sys/mman.h>\n#include <time.h>' pango_fun.h
    fi
    
    # 检查mainwindow.h中是否包含必要的头文件
    if ! grep -q "#include <QTimer>" mainwindow.h; then
        print_info "添加QTimer头文件到mainwindow.h..."
        sed -i '/#include <QOpenGLWidget>/a #include <QTimer>' mainwindow.h
    fi
    
    print_info "编译错误修复完成"
}

# 检查依赖
check_dependencies() {
    print_step "检查交叉编译工具链..."
    
    if ! command -v aarch64-linux-gnu-gcc &> /dev/null; then
        print_error "交叉编译工具链未安装"
        echo "请运行以下命令安装："
        echo "sudo apt update"
        echo "sudo apt install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu"
        exit 1
    fi
    
    if [ ! -d "3rdparty/opencv/opencv-linux-aarch64" ]; then
        print_error "OpenCV库目录不存在"
        exit 1
    fi
    
    if [ ! -d "3rdparty/librga/Linux/aarch64" ]; then
        print_error "RGA库目录不存在"
        exit 1
    fi
    
    if [ ! -d "3rdparty/rknpu2/Linux/aarch64" ]; then
        print_error "RKNN库目录不存在"
        exit 1
    fi
    
    print_info "依赖检查通过"
}

# 创建修复后的.pro文件
create_fixed_pro_file() {
    print_step "创建修复后的.pro文件..."
    
    cat > ZYNQ_video_show_fixed.pro << 'EOF'
QT       += core gui network

greaterThan(QT_MAJOR_VERSION, 4): QT += widgets gui

CONFIG += c++17

TARGET = ZYNQ_video_show
TEMPLATE = app

DEFINES += QT_DEPRECATED_WARNINGS

# 交叉编译配置
CONFIG += cross_compile
QMAKE_CC = aarch64-linux-gnu-gcc
QMAKE_CXX = aarch64-linux-gnu-g++
QMAKE_LINK = aarch64-linux-gnu-g++
QMAKE_AR = aarch64-linux-gnu-ar
QMAKE_STRIP = aarch64-linux-gnu-strip

# 源文件
SOURCES += \
    main.cpp \
    mainwindow.cpp \
    pango_fun.cpp \
    pcie_recv_thread.cpp \
    yolov11_detector.cpp \
    file_utils.c \
    image_utils.c \
    adc_draw_wave.cpp

HEADERS += \
    mainwindow.h \
    pango_fun.h \
    pcie_recv_thread.h \
    yolov11_detector.h \
    common.h \
    file_utils.h \
    image_utils.h \
    adc_draw_wave.h

FORMS += \
    mainwindow.ui

# OpenCV配置
INCLUDEPATH += $$_PRO_FILE_PWD_/3rdparty/opencv/opencv-linux-aarch64/include
LIBS += -L$$_PRO_FILE_PWD_/3rdparty/opencv/opencv-linux-aarch64/lib \
        -lopencv_core \
        -lopencv_imgcodecs \
        -lopencv_imgproc \
        -lopencv_highgui \
        -lopencv_videoio

# RGA库配置
INCLUDEPATH += $$_PRO_FILE_PWD_/3rdparty/librga/include
LIBS += -L$$_PRO_FILE_PWD_/3rdparty/librga/Linux/aarch64 -lrga

# RKNN库配置
INCLUDEPATH += $$_PRO_FILE_PWD_/3rdparty/rknpu2/include
LIBS += -L$$_PRO_FILE_PWD_/3rdparty/rknpu2/Linux/aarch64 -lrknnrt

# 链接器配置
QMAKE_LFLAGS += -Wl,-rpath-link,$$_PRO_FILE_PWD_/3rdparty/opencv/opencv-linux-aarch64/lib
QMAKE_LFLAGS += -Wl,-rpath-link,$$_PRO_FILE_PWD_/3rdparty/librga/Linux/aarch64
QMAKE_LFLAGS += -Wl,-rpath-link,$$_PRO_FILE_PWD_/3rdparty/rknpu2/Linux/aarch64

# 部署配置
target.path = /opt/$${TARGET}/bin
INSTALLS += target

RC_ICONS = favicon.ico
EOF

    print_info "修复后的.pro文件创建完成"
}

# 编译项目
build_project() {
    print_step "开始编译项目..."
    
    # 清理之前的编译文件
    if [ -d "build-fixed" ]; then
        rm -rf build-fixed
    fi
    mkdir build-fixed
    cd build-fixed
    
    # 设置环境变量
    export CC=aarch64-linux-gnu-gcc
    export CXX=aarch64-linux-gnu-g++
    export PKG_CONFIG_PATH="/usr/lib/aarch64-linux-gnu/pkgconfig"
    
    # 生成Makefile
    print_info "生成Makefile..."
    qmake ../ZYNQ_video_show_fixed.pro
    
    # 编译
    print_info "开始编译..."
    make -j$(nproc)
    
    if [ $? -eq 0 ]; then
        print_info "编译成功！"
        print_info "可执行文件位置: build-fixed/ZYNQ_video_show"
        
        # 显示文件信息
        file ZYNQ_video_show
        ls -lh ZYNQ_video_show
    else
        print_error "编译失败！"
        exit 1
    fi
}

# 创建部署包
create_deployment_package() {
    print_step "创建部署包..."
    
    DEPLOY_DIR="deploy-fixed"
    rm -rf $DEPLOY_DIR
    mkdir -p $DEPLOY_DIR
    
    # 复制可执行文件
    cp build-fixed/ZYNQ_video_show $DEPLOY_DIR/
    
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
    
    print_info "部署包创建完成: $DEPLOY_DIR"
}

# 主函数
main() {
    print_info "开始修复编译错误并交叉编译..."
    
    fix_compile_errors
    check_dependencies
    create_fixed_pro_file
    build_project
    create_deployment_package
    
    print_info "编译完成！"
    print_info "部署包位置: deploy-fixed/"
}

# 运行主函数
main "$@"
