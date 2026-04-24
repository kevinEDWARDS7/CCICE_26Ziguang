#!/bin/bash

# 修复OpenCV库符号链接的脚本
# 解决所有损坏的符号链接问题

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

# 进入OpenCV库目录
OPENCV_LIB_DIR="/home/wu/pg_qt_recv_720p_prj_v1_20251017/pg_qt_recv_720p_prj_v1_20251017/3rdparty/opencv_3.4.1/lib"
cd "$OPENCV_LIB_DIR"

print_step "修复OpenCV库符号链接..."

# 获取所有库文件列表
LIBRARIES=(
    "libopencv_calib3d"
    "libopencv_core"
    "libopencv_features2d"
    "libopencv_flann"
    "libopencv_highgui"
    "libopencv_imgcodecs"
    "libopencv_imgproc"
    "libopencv_ml"
    "libopencv_objdetect"
    "libopencv_photo"
    "libopencv_stitching"
)

# 修复每个库的符号链接
for lib in "${LIBRARIES[@]}"; do
    print_info "修复 $lib 的符号链接..."
    
    # 检查实际库文件是否存在
    if [ ! -f "${lib}.so.3.4.1" ]; then
        print_error "实际库文件不存在: ${lib}.so.3.4.1"
        continue
    fi
    
    # 删除损坏的符号链接文件
    if [ -f "${lib}.so" ]; then
        rm -f "${lib}.so"
    fi
    if [ -f "${lib}.so.3.4" ]; then
        rm -f "${lib}.so.3.4"
    fi
    
    # 创建正确的符号链接
    ln -s "${lib}.so.3.4.1" "${lib}.so.3.4"
    ln -s "${lib}.so.3.4" "${lib}.so"
    
    print_info "✓ ${lib} 符号链接修复完成"
done

print_step "验证符号链接..."

# 验证所有符号链接
for lib in "${LIBRARIES[@]}"; do
    if [ -L "${lib}.so" ] && [ -L "${lib}.so.3.4" ]; then
        print_info "✓ ${lib} 符号链接正确"
    else
        print_error "✗ ${lib} 符号链接仍有问题"
    fi
done

print_step "检查库文件类型..."

# 检查所有库文件类型
for lib in "${LIBRARIES[@]}"; do
    if [ -f "${lib}.so.3.4.1" ]; then
        file_type=$(file "${lib}.so.3.4.1")
        if [[ $file_type == *"ELF 64-bit LSB shared object, ARM aarch64"* ]]; then
            print_info "✓ ${lib}.so.3.4.1 是有效的ARM64共享库"
        else
            print_error "✗ ${lib}.so.3.4.1 不是有效的ARM64共享库: $file_type"
        fi
    fi
done

print_info "OpenCV库符号链接修复完成！"
print_info "现在可以尝试重新编译项目了。"

# 显示修复后的文件列表
print_step "修复后的文件列表:"
ls -la libopencv_*.so*

