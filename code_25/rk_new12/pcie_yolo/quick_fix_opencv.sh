#!/bin/bash

# 快速修复OpenCV链接错误的脚本

set -e

print_info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

print_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

print_step() {
    echo -e "\033[0;34m[STEP]\033[0m $1"
}

print_step "创建最小化OpenCV配置..."

# 创建最小化的.pro文件
cat > ZYNQ_video_show_minimal.pro << 'EOF'
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

# 最小化OpenCV配置 - 只使用静态库
INCLUDEPATH += $$_PRO_FILE_PWD_/3rdparty/opencv/opencv-linux-aarch64/include

# 使用静态链接，避免动态库问题
LIBS += $$_PRO_FILE_PWD_/3rdparty/opencv/opencv-linux-aarch64/lib/libopencv_core.a
LIBS += $$_PRO_FILE_PWD_/3rdparty/opencv/opencv-linux-aarch64/lib/libopencv_imgproc.a
LIBS += $$_PRO_FILE_PWD_/3rdparty/opencv/opencv-linux-aarch64/lib/libopencv_imgcodecs.a

# RGA库配置
INCLUDEPATH += $$_PRO_FILE_PWD_/3rdparty/librga/include
LIBS += -L$$_PRO_FILE_PWD_/3rdparty/librga/Linux/aarch64 -lrga

# RKNN库配置
INCLUDEPATH += $$_PRO_FILE_PWD_/3rdparty/rknpu2/include
LIBS += -L$$_PRO_FILE_PWD_/3rdparty/rknpu2/Linux/aarch64 -lrknnrt

# 必要的系统库
LIBS += -lpthread -ldl -lm -lrt

# 部署配置
target.path = /opt/$${TARGET}/bin
INSTALLS += target

RC_ICONS = favicon.ico
EOF

print_info "最小化.pro文件创建完成"

print_step "尝试编译..."

# 清理并创建build目录
rm -rf build-minimal
mkdir build-minimal
cd build-minimal

# 设置环境变量
export CC=aarch64-linux-gnu-gcc
export CXX=aarch64-linux-gnu-g++

# 生成Makefile
print_info "生成Makefile..."
qmake ../ZYNQ_video_show_minimal.pro

# 编译
print_info "开始编译..."
make -j$(nproc)

if [ $? -eq 0 ]; then
    print_info "编译成功！"
    print_info "可执行文件: build-minimal/ZYNQ_video_show"
    
    # 显示文件信息
    file ZYNQ_video_show
    ls -lh ZYNQ_video_show
    
    # 创建部署包
    cd ..
    mkdir -p deploy-minimal
    cp build-minimal/ZYNQ_video_show deploy-minimal/
    cp -r 3rdparty deploy-minimal/
    cp models/*.rknn deploy-minimal/ 2>/dev/null || true
    
    cat > deploy-minimal/run.sh << 'EOF'
#!/bin/bash
export LD_LIBRARY_PATH=./3rdparty/opencv/opencv-linux-aarch64/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=./3rdparty/librga/Linux/aarch64:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=./3rdparty/rknpu2/Linux/aarch64:$LD_LIBRARY_PATH
./ZYNQ_video_show
EOF
    chmod +x deploy-minimal/run.sh
    
    print_info "部署包创建完成: deploy-minimal/"
else
    print_error "编译失败！"
    print_info "请检查错误信息，可能需要："
    print_info "1. 安装完整的OpenCV库"
    print_info "2. 使用Docker编译方案"
    print_info "3. 检查交叉编译工具链"
fi
