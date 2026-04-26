# ZYNQ视频接收程序Docker交叉编译方案
# 使用Docker可以避免复杂的交叉编译环境配置

FROM ubuntu:20.04

# 设置非交互模式
ENV DEBIAN_FRONTEND=noninteractive

# 安装基础工具和交叉编译工具链
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

# 创建编译脚本
RUN echo '#!/bin/bash\n\
set -e\n\
echo "开始Docker内交叉编译..."\n\
\n\
# 设置交叉编译环境\n\
export CC=aarch64-linux-gnu-gcc\n\
export CXX=aarch64-linux-gnu-g++\n\
export AR=aarch64-linux-gnu-ar\n\
export STRIP=aarch64-linux-gnu-strip\n\
\n\
# 创建交叉编译.pro文件\n\
cat > ZYNQ_video_show_docker.pro << EOF\n\
QT       += core gui network\n\
greaterThan(QT_MAJOR_VERSION, 4): QT += widgets gui\n\
CONFIG += c++17\n\
TARGET = ZYNQ_video_show\n\
TEMPLATE = app\n\
DEFINES += QT_DEPRECATED_WARNINGS\n\
\n\
CONFIG += cross_compile\n\
QMAKE_CC = aarch64-linux-gnu-gcc\n\
QMAKE_CXX = aarch64-linux-gnu-g++\n\
QMAKE_LINK = aarch64-linux-gnu-g++\n\
QMAKE_AR = aarch64-linux-gnu-ar\n\
QMAKE_STRIP = aarch64-linux-gnu-strip\n\
\n\
SOURCES += \\\\\n\
    main.cpp \\\\\n\
    mainwindow.cpp \\\\\n\
    pango_fun.cpp \\\\\n\
    pcie_recv_thread.cpp \\\\\n\
    yolov11_detector.cpp \\\\\n\
    file_utils.c \\\\\n\
    image_utils.c\n\
\n\
HEADERS += \\\\\n\
    mainwindow.h \\\\\n\
    pango_fun.h \\\\\n\
    pcie_recv_thread.h \\\\\n\
    yolov11_detector.h \\\\\n\
    common.h \\\\\n\
    file_utils.h \\\\\n\
    image_utils.h \\\\\n\
    adc_draw_wave.h\n\
\n\
FORMS += \\\\\n\
    mainwindow.ui\n\
\n\
INCLUDEPATH += \$\$_PRO_FILE_PWD_/3rdparty/opencv/opencv-linux-aarch64/include\n\
LIBS += -L\$\$_PRO_FILE_PWD_/3rdparty/opencv/opencv-linux-aarch64/lib \\\\\n\
        -lopencv_core \\\\\n\
        -lopencv_imgcodecs \\\\\n\
        -lopencv_imgproc \\\\\n\
        -lopencv_highgui \\\\\n\
        -lopencv_videoio\n\
\n\
INCLUDEPATH += \$\$_PRO_FILE_PWD_/3rdparty/librga/include\n\
LIBS += -L\$\$_PRO_FILE_PWD_/3rdparty/librga/Linux/aarch64 -lrga\n\
\n\
INCLUDEPATH += \$\$_PRO_FILE_PWD_/3rdparty/rknpu2/include\n\
LIBS += -L\$\$_PRO_FILE_PWD_/3rdparty/rknpu2/Linux/aarch64 -lrknnrt\n\
\n\
QMAKE_LFLAGS += -Wl,-rpath-link,\$\$_PRO_FILE_PWD_/3rdparty/opencv/opencv-linux-aarch64/lib\n\
QMAKE_LFLAGS += -Wl,-rpath-link,\$\$_PRO_FILE_PWD_/3rdparty/librga/Linux/aarch64\n\
QMAKE_LFLAGS += -Wl,-rpath-link,\$\$_PRO_FILE_PWD_/3rdparty/rknpu2/Linux/aarch64\n\
\n\
target.path = /opt/\$\${TARGET}/bin\n\
INSTALLS += target\n\
\n\
RC_ICONS = favicon.ico\n\
EOF\n\
\n\
# 编译\n\
mkdir -p build-docker\n\
cd build-docker\n\
qmake ../ZYNQ_video_show_docker.pro\n\
make -j$(nproc)\n\
\n\
if [ $? -eq 0 ]; then\n\
    echo "编译成功！"\n\
    file ZYNQ_video_show\n\
    ls -lh ZYNQ_video_show\n\
    \n\
    # 创建部署包\n\
    cd ..\n\
    mkdir -p deploy-docker\n\
    cp build-docker/ZYNQ_video_show deploy-docker/\n\
    cp -r 3rdparty deploy-docker/\n\
    cp models/*.rknn deploy-docker/ 2>/dev/null || true\n\
    \n\
    echo "部署包已创建: deploy-docker/"\n\
else\n\
    echo "编译失败！"\n\
    exit 1\n\
fi' > /workspace/build.sh && chmod +x /workspace/build.sh

# 默认命令
CMD ["/workspace/build.sh"]
