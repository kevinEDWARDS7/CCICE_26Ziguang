#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QMainWindow>
#include <QUdpSocket>
#include <QDebug>
#include <QPainter>
#include <QImage>
#include <QDateTime>
#include <QThread>
#include <QLabel>
#include <QOpenGLWidget>
#include <QTimer>
#include <QDir>

#include "FPGA_pcie.h"
#include "data_receive_thread.h"
#include "rknn_object_detector.h"

namespace Ui {
class MainWindow; }

class MainWindow : public QMainWindow
{
    Q_OBJECT

signals:
    void newframe_ready(int index);

public:
    MainWindow(QWidget *parent = nullptr);
    ~MainWindow();
    int dma_len=0;
    uchar* recv_buf;
    uchar* img_buf;
    
public slots:
    void dada_recv_to_dis();
    void rate_cacul();
    void display_newframe(int index);

private slots:
    void on_Key1_clicked();
    void timerEvent(QTimerEvent *event);
    void on_Gray_clicked();
    void on_connect_clicked();
    void on_save_clicked();
    void on_save_video_clicked();
    void on_cam1_clicked();
    void on_cam2_clicked();
    void on_dma_write_clicked();
    void on_dma_read_clicked();
    void recv_img_dis(int index);
    void on_pushButton_clicked();
    void on_enable_detection_clicked();  // 启用/禁用目标检测

private:
    uchar* send_buf;
    FPGA_pcie *pango_device;
    DataReceiveThread *data_recv_thread;
    QImage My_Image;
    int recvImageNum=0;
    int recvImageNum_pre=0;
    int buffer_index=0;
    QTimer* timer;
    QTimer* fps_timer;
    QTimer* capture_img;
    QPixmap pixmap;
    QPainter *painter;
    
    // RKNN目标检测器
    RknnObjectDetector *object_detector;
    bool enable_detection = false;
    QString model_path = "models/yolo11.rknn";  // RKNN模型文件路径
    
    void paintEvent(QPaintEvent *event);
    void renderDetections(QImage &image, const std::vector<DetectionResult>& detections);
    QColor getClassColor(int class_id);
    
    Ui::MainWindow *ui;
    QUdpSocket *UDP_Socket;
    QUdpSocket *UDP_Socket2;
    QByteArray Picture_Data;
    uchar *RGB_Buff;
    uchar h_disp[2];
    uchar v_disp[2];
    int Len;
    QByteArray Rec_Data;
    int width;
    int length;
    int   display_h_disp;
    int   display_v_disp;
    uchar System_Mode;
    uchar System_Gray=1;
    uchar System_GrayScale=0;
    QString ip;
    QString port_buf;
    int port;
    int frameCount=0;
    unsigned int offset_addr=0;
    unsigned int send_offset_addr=0;
    unsigned int send_dma_times_cnt=0;
    unsigned int rd_dma_times_cnt=0;
};

class SaveImageThread : public QThread {
    Q_OBJECT

public:
    SaveImageThread(QLabel *label) : label(label) {}

protected:
    void run() override {
        QPixmap pixmap = label->grab();
        QString filePath = "D:/qt/prj/test_png";
        if (!filePath.isEmpty()) {
            static int num=0;
            filePath = filePath + "/pic_" + QString::number(num) + ".png";
            pixmap.save(filePath);
            num++;
            qDebug() << "保存成功：" << filePath;
        }
    }

private:
    QLabel *label;
};

#endif // MAINWINDOW_H