// YOLO检测框位置修复方案
// 添加到mainwindow.cpp中的dada_recv_to_dis()函数

void MainWindow::dada_recv_to_dis()
{
    recvImageNum++;
    ui->total_frame->setText(QString::number(recvImageNum));

    QImage My_Image(pango_device->img_buf,width,length,width*2,QImage::Format_RGB16);
    
    // 如果启用了目标检测
    if (detection_enabled && yolo_detector != nullptr) {
        try {
            // 将QImage转换为cv::Mat
            QImage rgb888 = My_Image.convertToFormat(QImage::Format_RGB888);
            cv::Mat frame(rgb888.height(), rgb888.width(), CV_8UC3, 
                         (void*)rgb888.bits(), rgb888.bytesPerLine());
            
            // 添加调试信息
            qDebug() << "原始图像尺寸:" << My_Image.width() << "x" << My_Image.height();
            qDebug() << "RGB888图像尺寸:" << rgb888.width() << "x" << rgb888.height();
            qDebug() << "cv::Mat尺寸:" << frame.cols << "x" << frame.rows;
            
            // 进行目标检测
            std::vector<ObjectInfo> detections;
            int ret = yolo_detector->Process(frame, detections);
            
            if (ret == 0 && !detections.empty()) {
                // 添加调试信息
                qDebug() << "检测到" << detections.size() << "个目标";
                for (size_t i = 0; i < detections.size(); i++) {
                    qDebug() << "目标" << i << ": 类别=" << detections[i].classid 
                             << " 置信度=" << detections[i].score
                             << " 位置=(" << detections[i].rect.x << "," << detections[i].rect.y 
                             << "," << detections[i].rect.width << "," << detections[i].rect.height << ")";
                }
                
                // 在图像上绘制检测结果
                drawDetections(My_Image, detections);
                
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

