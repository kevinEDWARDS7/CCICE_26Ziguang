#!/bin/bash

# 简化的OpenCV交叉编译脚本 - 快速版本

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

# 快速OpenCV交叉编译
quick_build_opencv() {
    print_step "快速OpenCV交叉编译..."
    
    # 安装依赖
    sudo apt update
    sudo apt install -y cmake git wget unzip pkg-config gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
    
    # 下载OpenCV
    cd /tmp
    if [ ! -d "opencv-4.8.0" ]; then
        wget https://github.com/opencv/opencv/archive/4.8.0.zip
        unzip 4.8.0.zip
    fi
    
    # 创建构建目录
    rm -rf opencv-build
    mkdir opencv-build
    cd opencv-build
    
    # 设置环境变量
    export CC=aarch64-linux-gnu-gcc
    export CXX=aarch64-linux-gnu-g++
    
    # 配置CMake
    cmake \
        -DCMAKE_SYSTEM_NAME=Linux \
        -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
        -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
        -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
        -DCMAKE_INSTALL_PREFIX=$(pwd)/../opencv-install \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTS=OFF \
        -DBUILD_EXAMPLES=OFF \
        -DWITH_OPENCL=OFF \
        -DWITH_CUDA=OFF \
        -DWITH_IPP=OFF \
        -DWITH_TBB=OFF \
        -DWITH_CAROTENE=ON \
        -DWITH_NEON=ON \
        -DCMAKE_C_FLAGS="-O3 -fPIC" \
        -DCMAKE_CXX_FLAGS="-O3 -fPIC" \
        ../opencv-4.8.0
    
    # 编译
    make -j$(nproc)
    make install
    
    print_info "OpenCV编译完成"
}

# 更新项目
update_project() {
    print_step "更新项目配置..."
    
    cd $(dirname $0)
    
    # 备份原始OpenCV
    if [ -d "3rdparty/opencv/opencv-linux-aarch64" ]; then
        mv 3rdparty/opencv/opencv-linux-aarch64 3rdparty/opencv/opencv-linux-aarch64-backup
    fi
    
    # 使用新编译的OpenCV
    cp -r /tmp/opencv-install 3rdparty/opencv/opencv-linux-aarch64
    
    print_info "项目配置更新完成"
}

# 重新编译项目
rebuild_project() {
    print_step "重新编译项目..."
    
    rm -rf build-new
    mkdir build-new
    cd build-new
    
    export CC=aarch64-linux-gnu-gcc
    export CXX=aarch64-linux-gnu-g++
    
    qmake ../ZYNQ_video_show.pro
    make -j$(nproc)
    
    if [ $? -eq 0 ]; then
        print_info "项目编译成功！"
        print_info "可执行文件: build-new/ZYNQ_video_show"
    else
        print_error "项目编译失败"
    fi
}

# 主函数
main() {
    print_info "开始OpenCV交叉编译和项目重建..."
    
    quick_build_opencv
    update_project
    rebuild_project
    
    print_info "所有步骤完成！"
}

main "$@"
