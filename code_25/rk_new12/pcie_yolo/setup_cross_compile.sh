#!/bin/bash

# ZYNQ交叉编译环境设置脚本
# 适用于Ubuntu系统

echo "开始设置ZYNQ交叉编译环境..."

# 更新系统包
sudo apt update

# 安装基础开发工具
sudo apt install -y \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    unzip \
    pkg-config \
    libtool \
    autoconf \
    automake \
    libssl-dev \
    libffi-dev \
    python3-dev \
    python3-pip

# 安装交叉编译工具链
echo "安装ARM交叉编译工具链..."
sudo apt install -y \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    binutils-aarch64-linux-gnu

# 验证工具链安装
echo "验证交叉编译工具链..."
aarch64-linux-gnu-gcc --version
aarch64-linux-gnu-g++ --version

echo "交叉编译环境设置完成！"
