QT       += core gui network

greaterThan(QT_MAJOR_VERSION, 4): QT += widgets gui

CONFIG += c++17

TARGET = RK3568_PCIE_SHOW
TEMPLATE = app

DEFINES += QT_DEPRECATED_WARNINGS



SOURCES += \
    main.cpp \
    mainwindow.cpp \
    FPGA_pcie.cpp \
    data_receive_thread.cpp \
    file_utils.c \
    image_utils.c \
    rknn_object_detector.cpp

HEADERS += \
    mainwindow.h \
    FPGA_pcie.h \
    data_receive_thread.h \
    common.h \
    file_utils.h \
    image_utils.h \
    rknn_object_detector.h

FORMS += \
    mainwindow.ui

# OpenCV配置
unix {
    INCLUDEPATH += $$_PRO_FILE_PWD_/3rdparty/opencv_3.4.1/include

    LIBS += -L$$_PRO_FILE_PWD_/3rdparty/opencv_3.4.1/lib \
            -lopencv_core \
            -lopencv_imgcodecs \
            -lopencv_highgui \
            -lopencv_imgproc

   

    
    # 系统库
    LIBS += -ldl -lpthread

}

# RKNN库配置（根据实际RKNN SDK路径调整）
unix {
     #librga
     INCLUDEPATH += $$_PRO_FILE_PWD_/3rdparty/librga/include
     LIBS += -L$$_PRO_FILE_PWD_/3rdparty/librga/Linux/aarch64 -lrga
}

unix {
    # 假设RKNN SDK安装在/opt/rknn目录
    INCLUDEPATH += $$_PRO_FILE_PWD_/3rdparty/rknpu2/include
    LIBS += -L$$_PRO_FILE_PWD_/3rdparty/rknpu2/Linux/aarch64 -lrknnrt
}

# Default rules for deployment.
qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target

RC_ICONS = favicon.ico
