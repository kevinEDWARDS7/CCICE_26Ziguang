#!/bin/bash

# 简化的Qt交叉编译环境设置
# 使用预编译的Qt库或Docker方案

echo "设置简化的Qt交叉编译环境..."

# 方案1: 使用Docker (推荐)
echo "方案1: 使用Docker进行交叉编译"
cat > Dockerfile << 'EOF'
FROM ubuntu:20.04

# 设置非交互模式
ENV DEBIAN_FRONTEND=noninteractive

# 安装基础工具
RUN apt-get update && apt-get install -y \
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
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    binutils-aarch64-linux-gnu \
    qt5-default \
    qtbase5-dev \
    qtbase5-dev-tools \
    qttools5-dev \
    qttools5-dev-tools \
    libqt5opengl5-dev \
    libqt5svg5-dev \
    libqt5webkit5-dev \
    libqt5x11extras5-dev \
    libqt5xmlpatterns5-dev \
    libqt5qml5 \
    libqt5quick5 \
    qtdeclarative5-dev \
    qtmultimedia5-dev \
    libqt5multimedia5-dev \
    libqt5multimediawidgets5 \
    libqt5serialport5-dev \
    libqt5sql5-dev \
    libqt5test5-dev \
    libqt5xml5-dev \
    libqt5xmlpatterns5-dev \
    libqt5opengl5-dev \
    libqt5svg5-dev \
    libqt5webkit5-dev \
    libqt5x11extras5-dev \
    libqt5xmlpatterns5-dev \
    libqt5qml5 \
    libqt5quick5 \
    qtdeclarative5-dev \
    qtmultimedia5-dev \
    libqt5multimedia5-dev \
    libqt5multimediawidgets5 \
    libqt5serialport5-dev \
    libqt5sql5-dev \
    libqt5test5-dev \
    libqt5xml5-dev \
    libqt5xmlpatterns5-dev \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /workspace

# 复制项目文件
COPY . /workspace/

# 设置环境变量
ENV CC=aarch64-linux-gnu-gcc
ENV CXX=aarch64-linux-gnu-g++
ENV PKG_CONFIG_PATH=/usr/lib/aarch64-linux-gnu/pkgconfig
ENV QT_SELECT=5

CMD ["/bin/bash"]
EOF

echo "Dockerfile已创建"

# 方案2: 使用预编译的Qt库
echo "方案2: 下载预编译的Qt库"
mkdir -p qt-cross-compile
cd qt-cross-compile

# 下载预编译的Qt库 (需要根据实际情况调整URL)
echo "请手动下载适合的Qt交叉编译库，或使用以下命令："
echo "wget https://download.qt.io/archive/qt/5.15/5.15.2/qt-opensource-linux-x64-5.15.2.run"
echo "chmod +x qt-opensource-linux-x64-5.15.2.run"
echo "./qt-opensource-linux-x64-5.15.2.run"

echo "简化Qt交叉编译环境设置完成！"
