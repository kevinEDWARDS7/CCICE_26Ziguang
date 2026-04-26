#include "mainwindow.h"
#include "ui_mainwindow.h"
#include <QString>
#include <QApplication>
#include <QScreen>
#include <QPixmap>
#include <QFileDialog>
#include <QThread>
#include <QFile>
#include <QDir>
#include <uchar.h>
#include <iostream>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <time.h>
#include <pthread.h>
#include <sys/mman.h>

// 在.cpp文件中包含OpenCV头文件，避免头文件污染
//#define OPENCV_TRAITS_ENABLE_DEPRECATED
//#define CV_IGNORE_DEBUG_BUILD_GUARD
#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
    , ui(new Ui::MainWindow)
{
    ui->setupUi(this);
    ui->Label->setStyleSheet("QLabel{background-color:rgb(255,255,255);}");
    width = 1280;
    length = 720;
    ui->H_disp->setText("1280");
    ui->V_disp->setText("720");
    System_Mode=0;
    ui->total_frame->setText("0");
    this->setWindowTitle("PCIE视频传输系统 - FPGA我只用小眼睛");
    
    // 加载队徽图片
    QString logoPath = QApplication::applicationDirPath() + "/dl.jpg";
    // 如果应用程序目录下没有，尝试当前工作目录
    if (!QFile::exists(logoPath)) {
        logoPath = "./dl.jpg";
    }
    // 如果还是找不到，尝试项目根目录
    if (!QFile::exists(logoPath)) {
        logoPath = QDir::currentPath() + "/dl.jpg";
    }
    if (QFile::exists(logoPath)) {
        QPixmap logo(logoPath);
        if (!logo.isNull()) {
            // 缩放图片为150x150正方形，保持宽高比，居中显示
            QSize squareSize(150, 150);
            logo = logo.scaled(squareSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
            ui->teamLogo->setPixmap(logo);
            ui->teamLogo->setAlignment(Qt::AlignCenter);
            qDebug() << "队徽加载成功：" << logoPath << "，尺寸：150x150（正方形）";
        } else {
            qDebug() << "无法加载队徽图片（图片格式错误）：" << logoPath;
        }
    } else {
        qDebug() << "队徽文件不存在，尝试路径：" << logoPath;
        qDebug() << "当前工作目录：" << QDir::currentPath();
        qDebug() << "应用程序目录：" << QApplication::applicationDirPath();
    }
    
    // 设置队伍信息标签样式
    // 队伍名称使用较小的字体，确保在151像素宽度内能完整显示
    ui->teamName->setStyleSheet("QLabel { font-weight: bold; font-size: 9pt; color: #2c3e50; padding: 2px; }");
    ui->teamNumber->setStyleSheet("QLabel { font-size: 8pt; color: #7f8c8d; padding: 2px; }");
    
    // 加载logo.png图片
    QString logoPngPath = QApplication::applicationDirPath() + "/logo.png";
    if (!QFile::exists(logoPngPath)) {
        logoPngPath = "./logo.png";
    }
    if (!QFile::exists(logoPngPath)) {
        logoPngPath = QDir::currentPath() + "/logo.png";
    }
    if (QFile::exists(logoPngPath)) {
        QPixmap logoPng(logoPngPath);
        if (!logoPng.isNull()) {
            QSize labelSize = ui->logoLabel->size();
            logoPng = logoPng.scaled(labelSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
            ui->logoLabel->setPixmap(logoPng);
            ui->logoLabel->setAlignment(Qt::AlignCenter);
            qDebug() << "Logo加载成功：" << logoPngPath;
        } else {
            qDebug() << "无法加载Logo图片：" << logoPngPath;
        }
    } else {
        qDebug() << "Logo文件不存在：" << logoPngPath;
    }
    
    // 加载ziguang.png图片
    QString ziguangPath = QApplication::applicationDirPath() + "/ziguang.png";
    if (!QFile::exists(ziguangPath)) {
        ziguangPath = "./ziguang.png";
    }
    if (!QFile::exists(ziguangPath)) {
        ziguangPath = QDir::currentPath() + "/ziguang.png";
    }
    if (QFile::exists(ziguangPath)) {
        QPixmap ziguang(ziguangPath);
        if (!ziguang.isNull()) {
            QSize labelSize = ui->ziguangLabel->size();
            ziguang = ziguang.scaled(labelSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
            ui->ziguangLabel->setPixmap(ziguang);
            ui->ziguangLabel->setAlignment(Qt::AlignCenter);
            qDebug() << "紫光Logo加载成功：" << ziguangPath;
        } else {
            qDebug() << "无法加载紫光Logo图片：" << ziguangPath;
        }
    } else {
        qDebug() << "紫光Logo文件不存在：" << ziguangPath;
    }
    
    // 加载右上角的dl.jpg图片
    QString dlTopRightPath = QApplication::applicationDirPath() + "/dl.jpg";
    if (!QFile::exists(dlTopRightPath)) {
        dlTopRightPath = "./dl.jpg";
    }
    if (!QFile::exists(dlTopRightPath)) {
        dlTopRightPath = QDir::currentPath() + "/dl.jpg";
    }
    if (QFile::exists(dlTopRightPath)) {
        QPixmap dlTopRight(dlTopRightPath);
        if (!dlTopRight.isNull()) {
            // 缩放为150x150正方形，保持宽高比
            QSize squareSize(150, 150);
            dlTopRight = dlTopRight.scaled(squareSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
            ui->dlLogoTopRight->setPixmap(dlTopRight);
            ui->dlLogoTopRight->setAlignment(Qt::AlignCenter);
            qDebug() << "右上角dl.jpg加载成功：" << dlTopRightPath;
        } else {
            qDebug() << "无法加载右上角dl.jpg图片（图片格式错误）：" << dlTopRightPath;
        }
    } else {
        qDebug() << "右上角dl.jpg文件不存在，尝试路径：" << dlTopRightPath;
    }
    
    // 加载左下角和右下角的dl.jpg图片
    QString dlPath = QApplication::applicationDirPath() + "/dl.jpg";
    if (!QFile::exists(dlPath)) {
        dlPath = "./dl.jpg";
    }
    if (!QFile::exists(dlPath)) {
        dlPath = QDir::currentPath() + "/dl.jpg";
    }
    if (QFile::exists(dlPath)) {
        QPixmap dlLogo(dlPath);
        if (!dlLogo.isNull()) {
            // 缩放为120x120正方形，保持宽高比
            QSize squareSize(120, 120);
            dlLogo = dlLogo.scaled(squareSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
            
            // 设置左下角图片
            ui->dlLogoLeft->setPixmap(dlLogo);
            ui->dlLogoLeft->setAlignment(Qt::AlignCenter);
            
            // 设置右下角图片
            ui->dlLogoRight->setPixmap(dlLogo);
            ui->dlLogoRight->setAlignment(Qt::AlignCenter);
            
            qDebug() << "左下角和右下角dl.jpg加载成功：" << dlPath;
        } else {
            qDebug() << "无法加载dl.jpg图片（图片格式错误）：" << dlPath;
        }
    } else {
        qDebug() << "dl.jpg文件不存在，尝试路径：" << dlPath;
    }

    // 初始化RKNN检测器
    object_detector = new RknnObjectDetector();

    if (!QFile::exists(model_path)) 
    {
       qDebug() << "RKNN模型文件不存在：" << model_path;
       ui->statusbar->showMessage("模型文件不存在，无法加载目标检测功能");
    }
    
    // 尝试加载RKNN模型
    if (object_detector->InitResource(model_path.toLocal8Bit().data()) == 0) {
        qDebug() << "RKNN模型加载成功";
        ui->statusbar->showMessage("RKNN模型加载成功");
    } else {
        qDebug() << "RKNN模型加载失败";
        ui->statusbar->showMessage("RKNN模型加载失败 - 目标检测功能不可用");
    }

    //new thread
    pango_device = new FPGA_pcie();
    timer = new QTimer(this);
    fps_timer = new QTimer(this);
    capture_img = new QTimer(this);
    
    connect(pango_device,SIGNAL(send_wr_done(int)),this,SLOT(recv_img_dis(int)));
    connect(timer, SIGNAL(timeout()), this, SLOT(dada_recv_to_dis()));
    connect(fps_timer, SIGNAL(timeout()), this, SLOT(rate_cacul()));
    // connect(capture_img, SIGNAL(timeout()), this, SLOT(send_img_fun())); // 注释掉不存在的槽函数
    connect(this,&MainWindow::newframe_ready,this,&MainWindow::display_newframe,Qt::QueuedConnection);
    
    recv_buf    =   new uchar[img_w_size*img_h_size*2*2]  ;
    img_buf     =   new uchar[img_w_size*img_h_size*2]  ;
}

void MainWindow::recv_img_dis(int index)
{
    // 使用工程1的图像数据创建QImage
    // 1280x720, RGB565格式
    My_Image = QImage(pango_device->img_buf, width, length, width*2, QImage::Format_RGB16);
}

void MainWindow::dada_recv_to_dis()
{
    recvImageNum++;
    ui->total_frame->setText(QString::number(recvImageNum));

    QImage My_Image(pango_device->img_buf,width,length,width*2,QImage::Format_RGB16);
    
    // 如果启用了目标检测
    if (enable_detection && object_detector != nullptr) {
        try {
            // 将QImage转换为cv::Mat
            QImage rgb888 = My_Image.convertToFormat(QImage::Format_RGB888);
            cv::Mat frame(rgb888.height(), rgb888.width(), CV_8UC3, 
                         (void*)rgb888.bits(), rgb888.bytesPerLine());
            
            // 进行目标检测
            std::vector<DetectionResult> detections;
            int ret = object_detector->Process(frame, detections);
            
            if (ret == 0 && !detections.empty()) {
                // 在图像上绘制检测结果
                renderDetections(My_Image, detections);
                
                // 更新状态栏显示检测到的目标数量
                ui->statusbar->showMessage(QString("检测到 %1 个目标").arg(detections.size()));
            } else {
                ui->statusbar->showMessage("未检测到目标");
            }
            
        } catch (const cv::Exception& e) {
            qDebug() << "目标检测错误:" << e.what();
            ui->statusbar->showMessage("目标检测处理错误");
        }
    }
    
    QPixmap My_Pixmap = QPixmap::fromImage(My_Image);
    My_Pixmap=My_Pixmap.scaled(ui->Label->size(), Qt::KeepAspectRatio);
    ui->Label->setPixmap(My_Pixmap);
}

void MainWindow::display_newframe(int index)
{
    //memcpy(img_buf,recv_buf+index*img_w_size*img_h_size*2,img_w_size*img_h_size*2);
    QMutex imgBufMutex;
    {
        QMutexLocker locker(&imgBufMutex);
        memcpy(img_buf,recv_buf+index*img_w_size*img_h_size*2,img_w_size*img_h_size*2);
    }
    
    QImage My_Image(img_buf,width,length,width*2,QImage::Format_RGB16);
    
    // 如果启用了目标检测
    if (enable_detection && object_detector != nullptr) {
        try {
            QImage rgb888 = My_Image.convertToFormat(QImage::Format_RGB888);
            cv::Mat frame(rgb888.height(), rgb888.width(), CV_8UC3, 
                         (void*)rgb888.bits(), rgb888.bytesPerLine());
            
            std::vector<DetectionResult> detections;
            int ret = object_detector->Process(frame, detections);
            
            if (ret == 0 && !detections.empty()) {
                renderDetections(My_Image, detections);
                ui->statusbar->showMessage(QString("检测到 %1 个目标").arg(detections.size()));
            } else {
                ui->statusbar->showMessage("未检测到目标");
            }
            
        } catch (const cv::Exception& e) {
            qDebug() << "目标检测错误:" << e.what();
        }
    }
    
    QPixmap My_Pixmap = QPixmap::fromImage(My_Image);
    ui->Label->setPixmap(My_Pixmap);
}

QColor MainWindow::getClassColor(int class_id)
{
    // 为不同类别生成不同的颜色
    static QVector<QColor> colors = {
        QColor(255, 0, 0),     // 红色
        QColor(0, 255, 0),     // 绿色
        QColor(0, 0, 255),     // 蓝色
        QColor(255, 255, 0),   // 黄色
        QColor(255, 0, 255),   // 紫色
        QColor(0, 255, 255),   // 青色
        QColor(255, 128, 0),   // 橙色
        QColor(128, 0, 255),   // 紫红色
        QColor(0, 255, 128),   // 春绿色
        QColor(128, 255, 0)    // 黄绿色
    };
    
    // 添加边界检查，防止越界访问
    if (colors.isEmpty()) {
        return QColor(255, 255, 255); // 默认白色
    }
    
    int index = abs(class_id) % colors.size();
    return colors[index];
}

void MainWindow::renderDetections(QImage &image, const std::vector<DetectionResult>& detections)
{
    QPainter painter(&image);
    
    // 设置字体
    QFont font = painter.font();
    font.setPointSize(12);
    painter.setFont(font);
    
    for (const auto& detection : detections) 
    {
        // 获取类别颜色
        QColor color = getClassColor(detection.classid);
        QPen pen(color, 3);
        painter.setPen(pen);
        
        // 将 cv::Rect 转换为 QRect
        QRect qrect(detection.rect.x, 
                   detection.rect.y, 
                   detection.rect.width, 
                   detection.rect.height);
        
        // 绘制边界框
        painter.drawRect(qrect);
        
        // 创建标签文本
        QString label = QString("%1: %2%")
                           .arg(object_detector->getClassName(detection.classid))
                           .arg(static_cast<int>(detection.score * 100));
        
        // 计算文本尺寸
        QFontMetrics fm(font);
        int textWidth = fm.horizontalAdvance(label) + 10;
        int textHeight = fm.height() + 4;
        
        // 绘制标签背景 - 使用 cv::Rect 的成员变量而不是函数调用
        QRect textRect(detection.rect.x, 
                       detection.rect.y - textHeight, 
                       textWidth, textHeight);
        
        painter.fillRect(textRect, color);
        
        // 绘制标签文本
        painter.setPen(Qt::black);
        painter.drawText(textRect, Qt::AlignCenter, label);
    }
}

void MainWindow::rate_cacul()
{
    frameCount=recvImageNum-recvImageNum_pre;
    recvImageNum_pre = recvImageNum;
    ui->frame->setText(QString::number(frameCount));
}

void  MainWindow::paintEvent(QPaintEvent *event)
{
    Q_UNUSED(event);
}

// 启用/禁用目标检测
void MainWindow::on_enable_detection_clicked()
{
    enable_detection = !enable_detection;
    
    if (enable_detection) {
        ui->enable_detection->setText("Disable Detection");
        ui->statusbar->showMessage("RKNN目标检测已启用");
        qDebug() << "RKNN目标检测已启用";
    } else {
        ui->enable_detection->setText("Enable Detection");
        ui->statusbar->showMessage("目标检测已禁用");
        qDebug() << "RKNN目标检测已禁用";
    }
}

// 其他现有函数保持不变...
void MainWindow::on_Gray_clicked()
{
    // Gray button has been removed from UI
    // Keeping this function to avoid signal connection errors
    /*
    if(System_Gray == 0)
    {
        ui->Gray->setText("灰度化");
        System_GrayScale=0;
        System_Gray = 1;
    }
    else if(System_Gray == 1)
    {
        ui->Gray->setText("关闭灰度化");
        System_GrayScale=1;
        System_Gray = 0;
    }
    */
}

void MainWindow::on_Key1_clicked()
{
    QByteArray send;

    if(System_Mode == 0)
    {
        int dev_pg = -1;
        ui->Key1->setText("Close");
        System_Mode = 1;

        dev_pg = pango_device->getDevice();
        qDebug() << "dev_pg is  "<<dev_pg ;
        if(dev_pg !=-1)
        {
            qDebug() << "open success\n " ;
            ui->HostAddress->setText((QString("%1").arg(pango_device->command_operation.get_pci_dev_info.vendor_id, 4, 16,QLatin1Char('0')).toUpper()));
            ui->HostPort->setText(QString("GEN%1").arg(pango_device->command_operation.get_pci_dev_info.link_speed,0,10));
            ui->RemAddress->setText(QString("%1").arg(pango_device->command_operation.get_pci_dev_info.link_width,0,10));
            ui->RemPort->setText(QString("%1").arg(pango_device->command_operation.get_pci_dev_info.mps,0,10));
            
            // 工程1配置：每行2560字节
            pango_device->dma_oper->current_len = 2560 >> 2;  // 转换为DW（双字）= 640
            pango_device->dma_oper->offset_addr = 0;
            
            // 工程1不需要在这里映射，每帧读取时会自动映射/解映射
            // pango_device->dma_map(1);  // 工程2的代码，工程1不需要
            
            qDebug() << "PCIe设备打开成功 - 工程1模式";
            qDebug() << "DMA配置: current_len =" << pango_device->dma_oper->current_len << "DW";
        }
        else
        {
            qDebug() << "open faile\n " ;
            ui->HostAddress->setText("error");
            ui->HostPort->setText("error");
            ui->RemAddress->setText("error");
            ui->RemPort->setText("error");
        }
    }
    else if(System_Mode == 1)
    {
        ui->Key1->setText("Open");
        
        // 工程1不需要解除映射（每帧已自动处理）
        // pango_device->dma_map(0);  // 工程2的代码，工程1不需要
        
        System_Mode = 0;
        ui->Label->clear();
        ui->Label->setText("图像显示区域");
        ui->frame->setText("0");
        recvImageNum=0;
        QFont font;
        font.setPointSize(72);
        ui->Label->setFont(font);
        ui->Label->show();
    }
}

MainWindow::~MainWindow()
{
    delete ui;
    //delete UDP_Socket;
    if (UDP_Socket) 
    {
        delete UDP_Socket;
        UDP_Socket = nullptr;
    }
    delete object_detector;  // 释放检测器
}

void MainWindow::timerEvent(QTimerEvent *event)
{
    Q_UNUSED(event);
    ui->frame->clear();
    ui->frame->setText(QString("%1 FPS").arg(frameCount));
    frameCount=0;
}

void MainWindow::on_connect_clicked()
{
    if(ui->connect->text() == "Capture Video")
    {
        qDebug() << "开始采集图像 - 工程1模式";
        
        // 工程1模式：FPGA自动运行，无需PIO启动命令
        pango_device->stopped = false;
        pango_device->start();  // 启动读取线程
        
        timer->start(5);        // 5ms刷新显示
        fps_timer->start(1000); // 1s计算帧率
        ui->connect->setText("Stop Capture");
        
        // 工程1不需要PIO启动命令，已注释掉工程2的代码：
        // pango_device->pio_write(0xffffffe5,0,0);
    }
    else
    {
        qDebug() << "停止采集图像";
        
        pango_device->stopped = true;
        
        // 等待线程结束
        if(pango_device->isRunning()) {
            pango_device->wait(1000);
        }
        
        timer->stop();
        fps_timer->stop();
        ui->connect->setText("Capture Video");
        
        // 工程1不需要PIO停止命令，已注释掉工程2的代码：
        // pango_device->pio_write(0xffffff00,0,0);
        // pango_device->dma_map(0);
    }
}

void MainWindow::on_save_clicked()
{
    QPixmap pixmap = ui->Label->grab();
    QString filePath = "/home/linaro/img";  // RK3568开发板上的路径
    
    // 确保目录存在
    QDir dir;
    if (!dir.exists(filePath)) {
        if (dir.mkpath(filePath)) {
            qDebug() << "创建目录成功：" << filePath;
        } else {
            qDebug() << "创建目录失败：" << filePath;
        }
    }
    
    if (!filePath.isEmpty()) {
        static int num=0;
        QString fullPath = filePath + "/pic_" + QString::number(num) + ".jpg";
        if (pixmap.save(fullPath, "JPEG", 95)) {  // 保存为JPG格式，质量95
            num++;
            qDebug() << "保存成功：" << fullPath;
        } else {
            qDebug() << "保存失败：" << fullPath;
        }
    }
}

// 其他按钮的空实现保持不变...
void MainWindow::on_save_video_clicked() { }
void MainWindow::on_cam1_clicked() { }
void MainWindow::on_cam2_clicked() { }
void MainWindow::on_dma_write_clicked() { }
void MainWindow::on_dma_read_clicked() { }
void MainWindow::on_pushButton_clicked() { }
