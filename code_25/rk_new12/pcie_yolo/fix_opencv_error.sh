#!/bin/bash

# OpenCV链接错误修复脚本
# 解决carotene库缺失问题

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

# 检查OpenCV库
check_opencv_libs() {
    print_step "检查OpenCV库完整性..."
    
    OPENCV_LIB_DIR="3rdparty/opencv/opencv-linux-aarch64/lib"
    OPENCV_3RDPARTY_DIR="3rdparty/opencv/opencv-linux-aarch64/share/OpenCV/3rdparty/lib"
    
    if [ ! -d "$OPENCV_LIB_DIR" ]; then
        print_error "OpenCV库目录不存在: $OPENCV_LIB_DIR"
        exit 1
    fi
    
    print_info "OpenCV库文件列表:"
    ls -la "$OPENCV_LIB_DIR"
    
    print_info "OpenCV第三方库文件列表:"
    ls -la "$OPENCV_3RDPARTY_DIR"
    
    # 检查是否缺少carotene库
    if [ ! -f "$OPENCV_3RDPARTY_DIR/libcarotene.a" ]; then
        print_warning "缺少carotene库，这可能导致链接错误"
    fi
}

# 创建修复后的.pro文件
create_fixed_pro_file() {
    print_step "创建修复后的.pro文件..."
    
    cat > ZYNQ_video_show_opencv_fixed.pro << 'EOF'
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

# OpenCV配置 - 修复版本
INCLUDEPATH += $$_PRO_FILE_PWD_/3rdparty/opencv/opencv-linux-aarch64/include

# 按正确顺序链接OpenCV库
LIBS += -L$$_PRO_FILE_PWD_/3rdparty/opencv/opencv-linux-aarch64/lib \
        -lopencv_imgproc \
        -lopencv_imgcodecs \
        -lopencv_core \
        -lopencv_highgui \
        -lopencv_videoio

# 添加OpenCV第三方库
LIBS += -L$$_PRO_FILE_PWD_/3rdparty/opencv/opencv-linux-aarch64/share/OpenCV/3rdparty/lib \
        -ltegra_hal \
        -lquirc \
        -lwebp \
        -ltiff \
        -ljpeg-turbo \
        -lpng \
        -ljasper \
        -lIlmImf \
        -lprotobuf \
        -lz

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

# 添加必要的系统库
LIBS += -lpthread -ldl -lm

# 部署配置
target.path = /opt/$${TARGET}/bin
INSTALLS += target

RC_ICONS = favicon.ico
EOF

    print_info "修复后的.pro文件创建完成"
}

# 创建简化的OpenCV配置
create_simple_opencv_config() {
    print_step "创建简化的OpenCV配置..."
    
    cat > ZYNQ_video_show_simple.pro << 'EOF'
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

# 简化的OpenCV配置 - 只使用核心库
INCLUDEPATH += $$_PRO_FILE_PWD_/3rdparty/opencv/opencv-linux-aarch64/include
LIBS += -L$$_PRO_FILE_PWD_/3rdparty/opencv/opencv-linux-aarch64/lib \
        -lopencv_core \
        -lopencv_imgproc \
        -lopencv_imgcodecs

# RGA库配置
INCLUDEPATH += $$_PRO_FILE_PWD_/3rdparty/librga/include
LIBS += -L$$_PRO_FILE_PWD_/3rdparty/librga/Linux/aarch64 -lrga

# RKNN库配置
INCLUDEPATH += $$_PRO_FILE_PWD_/3rdparty/rknpu2/include
LIBS += -L$$_PRO_FILE_PWD_/3rdparty/rknpu2/Linux/aarch64 -lrknnrt

# 系统库
LIBS += -lpthread -ldl -lm

# 部署配置
target.path = /opt/$${TARGET}/bin
INSTALLS += target

RC_ICONS = favicon.ico
EOF

    print_info "简化的.pro文件创建完成"
}

# 尝试编译
try_compile() {
    print_step "尝试编译..."
    
    # 清理之前的编译文件
    if [ -d "build-opencv-fix" ]; then
        rm -rf build-opencv-fix
    fi
    mkdir build-opencv-fix
    cd build-opencv-fix
    
    # 设置环境变量
    export CC=aarch64-linux-gnu-gcc
    export CXX=aarch64-linux-gnu-g++
    export PKG_CONFIG_PATH="/usr/lib/aarch64-linux-gnu/pkgconfig"
    
    # 首先尝试简化版本
    print_info "尝试简化版本编译..."
    qmake ../ZYNQ_video_show_simple.pro
    make -j$(nproc) 2>&1 | tee compile.log
    
    if [ $? -eq 0 ]; then
        print_info "简化版本编译成功！"
        return 0
    else
        print_warning "简化版本编译失败，尝试完整版本..."
        make clean
        
        # 尝试完整版本
        qmake ../ZYNQ_video_show_opencv_fixed.pro
        make -j$(nproc) 2>&1 | tee compile_full.log
        
        if [ $? -eq 0 ]; then
            print_info "完整版本编译成功！"
            return 0
        else
            print_error "编译失败，请检查日志文件"
            return 1
        fi
    fi
}

# 创建OpenCV替代方案
create_opencv_alternative() {
    print_step "创建OpenCV替代方案..."
    
    cat > opencv_alternative.cpp << 'EOF'
// OpenCV替代方案 - 简化版本
// 如果OpenCV库有问题，可以使用这个简化版本

#include <opencv2/opencv.hpp>

// 简化的图像处理函数
namespace SimpleOpenCV {
    // 简化的图像读取
    cv::Mat imread_simple(const std::string& filename) {
        // 使用基本的imread，避免复杂的优化
        return cv::imread(filename, cv::IMREAD_COLOR);
    }
    
    // 简化的图像显示
    void imshow_simple(const std::string& winname, const cv::Mat& mat) {
        // 使用基本的imshow
        cv::imshow(winname, mat);
    }
    
    // 简化的图像保存
    bool imwrite_simple(const std::string& filename, const cv::Mat& img) {
        // 使用基本的imwrite
        return cv::imwrite(filename, img);
    }
}
EOF

    print_info "OpenCV替代方案创建完成"
}

# 主函数
main() {
    print_info "开始修复OpenCV链接错误..."
    
    check_opencv_libs
    create_fixed_pro_file
    create_simple_opencv_config
    create_opencv_alternative
    
    if try_compile; then
        print_info "编译成功！"
        print_info "可执行文件位置: build-opencv-fix/ZYNQ_video_show"
    else
        print_error "编译失败，请查看日志文件"
        print_info "建议："
        print_info "1. 检查OpenCV库是否完整"
        print_info "2. 尝试使用系统安装的OpenCV"
        print_info "3. 考虑使用Docker编译方案"
    fi
}

# 运行主函数
main "$@"
