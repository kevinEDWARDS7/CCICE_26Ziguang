#!/bin/bash

# OpenCV交叉编译脚本 - 解决carotene库缺失问题

set -e

# 配置参数
OPENCV_VERSION="4.8.0"
OPENCV_BUILD_DIR="/tmp/opencv-build"
OPENCV_INSTALL_DIR="$(pwd)/3rdparty/opencv/opencv-linux-aarch64-new"
CROSS_COMPILE_PREFIX="aarch64-linux-gnu-"

print_info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

print_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

print_step() {
    echo -e "\033[0;34m[STEP]\033[0m $1"
}

# 检查依赖
check_dependencies() {
    print_step "检查交叉编译工具链..."
    
    if ! command -v ${CROSS_COMPILE_PREFIX}gcc &> /dev/null; then
        print_error "交叉编译工具链未安装"
        echo "安装命令: sudo apt install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu"
        exit 1
    fi
    
    # 安装必要的工具
    sudo apt update
    sudo apt install -y cmake git wget unzip pkg-config
    
    print_info "依赖检查完成"
}

# 下载OpenCV源码
download_opencv() {
    print_step "下载OpenCV源码..."
    
    cd /tmp
    if [ ! -d "opencv-${OPENCV_VERSION}" ]; then
        wget https://github.com/opencv/opencv/archive/${OPENCV_VERSION}.zip
        unzip ${OPENCV_VERSION}.zip
    fi
    
    if [ ! -d "opencv_contrib-${OPENCV_VERSION}" ]; then
        wget https://github.com/opencv/opencv_contrib/archive/${OPENCV_VERSION}.zip
        unzip opencv_contrib-${OPENCV_VERSION}.zip
    fi
    
    print_info "OpenCV源码下载完成"
}

# 配置OpenCV编译
configure_opencv() {
    print_step "配置OpenCV交叉编译..."
    
    rm -rf $OPENCV_BUILD_DIR
    mkdir -p $OPENCV_BUILD_DIR
    cd $OPENCV_BUILD_DIR
    
    # 设置环境变量
    export CC=${CROSS_COMPILE_PREFIX}gcc
    export CXX=${CROSS_COMPILE_PREFIX}g++
    export PKG_CONFIG_PATH="/usr/lib/aarch64-linux-gnu/pkgconfig"
    
    # CMake配置
    cmake \
        -DCMAKE_SYSTEM_NAME=Linux \
        -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
        -DCMAKE_C_COMPILER=${CROSS_COMPILE_PREFIX}gcc \
        -DCMAKE_CXX_COMPILER=${CROSS_COMPILE_PREFIX}g++ \
        -DCMAKE_INSTALL_PREFIX=$OPENCV_INSTALL_DIR \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTS=OFF \
        -DBUILD_PERF_TESTS=OFF \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_DOCS=OFF \
        -DOPENCV_EXTRA_MODULES_PATH=/tmp/opencv_contrib-${OPENCV_VERSION}/modules \
        -DWITH_OPENCL=OFF \
        -DWITH_OPENCLAMDFFT=OFF \
        -DWITH_OPENCLAMDBLAS=OFF \
        -DWITH_VA=OFF \
        -DWITH_VA_INTEL=OFF \
        -DWITH_GDAL=OFF \
        -DWITH_GSTREAMER=OFF \
        -DWITH_FFMPEG=OFF \
        -DWITH_1394=OFF \
        -DWITH_GTK=OFF \
        -DWITH_QT=OFF \
        -DWITH_V4L=OFF \
        -DWITH_LIBV4L=OFF \
        -DWITH_DSHOW=OFF \
        -DWITH_MSMF=OFF \
        -DWITH_XIMEA=OFF \
        -DWITH_XINE=OFF \
        -DWITH_CLP=OFF \
        -DWITH_HALIDE=OFF \
        -DWITH_CUDA=OFF \
        -DWITH_CUBLAS=OFF \
        -DWITH_CUFFT=OFF \
        -DWITH_NVCUVID=OFF \
        -DWITH_EIGEN=OFF \
        -DWITH_LAPACK=OFF \
        -DWITH_IPP=OFF \
        -DWITH_TBB=OFF \
        -DWITH_OPENMP=OFF \
        -DWITH_PTHREADS_PF=ON \
        -DWITH_CAROTENE=ON \
        -DWITH_NEON=ON \
        -DCMAKE_C_FLAGS="-O3 -fPIC" \
        -DCMAKE_CXX_FLAGS="-O3 -fPIC" \
        /tmp/opencv-${OPENCV_VERSION}
    
    print_info "OpenCV配置完成"
}

# 编译OpenCV
build_opencv() {
    print_step "开始编译OpenCV (这需要很长时间)..."
    
    make -j$(nproc)
    
    if [ $? -eq 0 ]; then
        print_info "OpenCV编译成功"
    else
        print_error "OpenCV编译失败"
        exit 1
    fi
}

# 安装OpenCV
install_opencv() {
    print_step "安装OpenCV..."
    
    make install
    
    print_info "OpenCV安装完成: $OPENCV_INSTALL_DIR"
}

# 更新项目配置
update_project_config() {
    print_step "更新项目配置..."
    
    cd $(dirname $0)
    
    # 备份原始OpenCV
    if [ -d "3rdparty/opencv/opencv-linux-aarch64" ]; then
        mv 3rdparty/opencv/opencv-linux-aarch64 3rdparty/opencv/opencv-linux-aarch64-backup
    fi
    
    # 使用新编译的OpenCV
    ln -sf $(basename $OPENCV_INSTALL_DIR) 3rdparty/opencv/opencv-linux-aarch64
    
    print_info "项目配置更新完成"
}

# 主函数
main() {
    print_info "开始OpenCV交叉编译..."
    
    check_dependencies
    download_opencv
    configure_opencv
    build_opencv
    install_opencv
    update_project_config
    
    print_info "OpenCV交叉编译完成！"
    print_info "现在可以重新编译你的项目了"
}

main "$@"
