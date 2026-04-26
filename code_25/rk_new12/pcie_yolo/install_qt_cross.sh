#!/bin/bash

# Qt交叉编译环境安装脚本

echo "开始安装Qt交叉编译环境..."

# 设置Qt版本和安装路径
QT_VERSION="5.15.2"
QT_INSTALL_DIR="/opt/qt5-aarch64"
QT_SOURCE_DIR="/tmp/qt-source"

# 创建安装目录
sudo mkdir -p $QT_INSTALL_DIR
sudo chown $USER:$USER $QT_INSTALL_DIR

# 下载Qt源码
echo "下载Qt源码..."
cd /tmp
if [ ! -d "qt-everywhere-src-${QT_VERSION}" ]; then
    wget https://download.qt.io/archive/qt/5.15/${QT_VERSION}/single/qt-everywhere-src-${QT_VERSION}.tar.xz
    tar -xf qt-everywhere-src-${QT_VERSION}.tar.xz
fi

cd qt-everywhere-src-${QT_VERSION}

# 配置Qt交叉编译
echo "配置Qt交叉编译..."
./configure \
    -prefix $QT_INSTALL_DIR \
    -opensource \
    -confirm-license \
    -release \
    -shared \
    -xplatform linux-aarch64-gnu-g++ \
    -device-option CROSS_COMPILE=aarch64-linux-gnu- \
    -sysroot /usr/aarch64-linux-gnu \
    -qt-zlib \
    -qt-libpng \
    -qt-libjpeg \
    -qt-freetype \
    -qt-pcre \
    -qt-xcb \
    -qt-xkbcommon \
    -no-opengl \
    -no-openssl \
    -no-cups \
    -no-dbus \
    -no-feature-concurrent \
    -no-feature-sql \
    -no-feature-testlib \
    -no-feature-xml \
    -no-feature-network \
    -no-feature-widgets \
    -no-feature-gui \
    -skip qt3d \
    -skip qtactiveqt \
    -skip qtandroidextras \
    -skip qtcanvas3d \
    -skip qtcharts \
    -skip qtconnectivity \
    -skip qtdatavis3d \
    -skip qtdeclarative \
    -skip qtdoc \
    -skip qtgamepad \
    -skip qtgraphicaleffects \
    -skip qtlocation \
    -skip qtmacextras \
    -skip qtmultimedia \
    -skip qtnetworkauth \
    -skip qtpurchasing \
    -skip qtquickcontrols \
    -skip qtquickcontrols2 \
    -skip qtremoteobjects \
    -skip qtscxml \
    -skip qtsensors \
    -skip qtserialbus \
    -skip qtserialport \
    -skip qtspeech \
    -skip qtsvg \
    -skip qttools \
    -skip qttranslations \
    -skip qtvirtualkeyboard \
    -skip qtwayland \
    -skip qtwebchannel \
    -skip qtwebengine \
    -skip qtwebglplugin \
    -skip qtwebsockets \
    -skip qtwebview \
    -skip qtwinextras \
    -skip qtx11extras \
    -skip qtxmlpatterns

# 编译Qt
echo "开始编译Qt (这可能需要很长时间)..."
make -j$(nproc)

# 安装Qt
echo "安装Qt..."
make install

echo "Qt交叉编译环境安装完成！"
echo "Qt安装路径: $QT_INSTALL_DIR"
