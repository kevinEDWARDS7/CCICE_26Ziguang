/********************************************************************************
** Form generated from reading UI file 'mainwindow.ui'
**
** Created by: Qt User Interface Compiler version 5.15.3
**
** WARNING! All changes made in this file will be lost when recompiling UI file!
********************************************************************************/

#ifndef UI_MAINWINDOW_H
#define UI_MAINWINDOW_H

#include <QtCore/QVariant>
#include <QtWidgets/QApplication>
#include <QtWidgets/QGridLayout>
#include <QtWidgets/QGroupBox>
#include <QtWidgets/QLabel>
#include <QtWidgets/QLineEdit>
#include <QtWidgets/QMainWindow>
#include <QtWidgets/QMenuBar>
#include <QtWidgets/QPushButton>
#include <QtWidgets/QSpacerItem>
#include <QtWidgets/QStatusBar>
#include <QtWidgets/QVBoxLayout>
#include <QtWidgets/QWidget>

QT_BEGIN_NAMESPACE

class Ui_MainWindow
{
public:
    QWidget *centralwidget;
    QGroupBox *groupBox;
    QVBoxLayout *verticalLayout;
    QPushButton *enable_detection;
    QLabel *label;
    QLineEdit *HostAddress;
    QLabel *label_2;
    QLineEdit *HostPort;
    QLabel *label_3;
    QLineEdit *RemAddress;
    QLabel *label_4;
    QLineEdit *RemPort;
    QLabel *label_7;
    QSpacerItem *verticalSpacer;
    QLineEdit *dma_len;
    QPushButton *Key1;
    QPushButton *connect;
    QPushButton *pushButton;
    QPushButton *Gray;
    QPushButton *cam1;
    QPushButton *cam2;
    QPushButton *save;
    QPushButton *save_video;
    QSpacerItem *verticalSpacer_2;
    QLabel *Label;
    QWidget *gridLayoutWidget;
    QGridLayout *gridLayout;
    QLabel *frame;
    QLabel *H_disp;
    QLabel *label_6;
    QLabel *label_5;
    QLabel *V_disp;
    QLabel *framecount;
    QLabel *label_9;
    QLabel *total_frame;
    QPushButton *dma_write;
    QPushButton *dma_read;
    QMenuBar *menubar;
    QStatusBar *statusbar;

    void setupUi(QMainWindow *MainWindow)
    {
        if (MainWindow->objectName().isEmpty())
            MainWindow->setObjectName(QString::fromUtf8("MainWindow"));
        MainWindow->resize(1800, 944);
        MainWindow->setMinimumSize(QSize(1800, 900));
        centralwidget = new QWidget(MainWindow);
        centralwidget->setObjectName(QString::fromUtf8("centralwidget"));
        centralwidget->setMinimumSize(QSize(1800, 900));
        groupBox = new QGroupBox(centralwidget);
        groupBox->setObjectName(QString::fromUtf8("groupBox"));
        groupBox->setGeometry(QRect(10, 10, 151, 481));
        verticalLayout = new QVBoxLayout(groupBox);
        verticalLayout->setObjectName(QString::fromUtf8("verticalLayout"));
        enable_detection = new QPushButton(groupBox);
        enable_detection->setObjectName(QString::fromUtf8("enable_detection"));

        verticalLayout->addWidget(enable_detection);

        label = new QLabel(groupBox);
        label->setObjectName(QString::fromUtf8("label"));

        verticalLayout->addWidget(label);

        HostAddress = new QLineEdit(groupBox);
        HostAddress->setObjectName(QString::fromUtf8("HostAddress"));

        verticalLayout->addWidget(HostAddress);

        label_2 = new QLabel(groupBox);
        label_2->setObjectName(QString::fromUtf8("label_2"));

        verticalLayout->addWidget(label_2);

        HostPort = new QLineEdit(groupBox);
        HostPort->setObjectName(QString::fromUtf8("HostPort"));

        verticalLayout->addWidget(HostPort);

        label_3 = new QLabel(groupBox);
        label_3->setObjectName(QString::fromUtf8("label_3"));

        verticalLayout->addWidget(label_3);

        RemAddress = new QLineEdit(groupBox);
        RemAddress->setObjectName(QString::fromUtf8("RemAddress"));

        verticalLayout->addWidget(RemAddress);

        label_4 = new QLabel(groupBox);
        label_4->setObjectName(QString::fromUtf8("label_4"));

        verticalLayout->addWidget(label_4);

        RemPort = new QLineEdit(groupBox);
        RemPort->setObjectName(QString::fromUtf8("RemPort"));

        verticalLayout->addWidget(RemPort);

        label_7 = new QLabel(groupBox);
        label_7->setObjectName(QString::fromUtf8("label_7"));

        verticalLayout->addWidget(label_7);

        verticalSpacer = new QSpacerItem(20, 30, QSizePolicy::Minimum, QSizePolicy::Expanding);

        verticalLayout->addItem(verticalSpacer);

        dma_len = new QLineEdit(groupBox);
        dma_len->setObjectName(QString::fromUtf8("dma_len"));

        verticalLayout->addWidget(dma_len);

        Key1 = new QPushButton(groupBox);
        Key1->setObjectName(QString::fromUtf8("Key1"));

        verticalLayout->addWidget(Key1);

        connect = new QPushButton(groupBox);
        connect->setObjectName(QString::fromUtf8("connect"));

        verticalLayout->addWidget(connect);

        pushButton = new QPushButton(groupBox);
        pushButton->setObjectName(QString::fromUtf8("pushButton"));

        verticalLayout->addWidget(pushButton);

        Gray = new QPushButton(groupBox);
        Gray->setObjectName(QString::fromUtf8("Gray"));

        verticalLayout->addWidget(Gray);

        cam1 = new QPushButton(groupBox);
        cam1->setObjectName(QString::fromUtf8("cam1"));

        verticalLayout->addWidget(cam1);

        cam2 = new QPushButton(groupBox);
        cam2->setObjectName(QString::fromUtf8("cam2"));

        verticalLayout->addWidget(cam2);

        save = new QPushButton(groupBox);
        save->setObjectName(QString::fromUtf8("save"));

        verticalLayout->addWidget(save);

        save_video = new QPushButton(groupBox);
        save_video->setObjectName(QString::fromUtf8("save_video"));

        verticalLayout->addWidget(save_video);

        verticalSpacer_2 = new QSpacerItem(20, 40, QSizePolicy::Minimum, QSizePolicy::Expanding);

        verticalLayout->addItem(verticalSpacer_2);

        Label = new QLabel(centralwidget);
        Label->setObjectName(QString::fromUtf8("Label"));
        Label->setGeometry(QRect(209, 10, 1280, 720));
        Label->setMinimumSize(QSize(1280, 720));
        Label->setMaximumSize(QSize(1280, 720));
        gridLayoutWidget = new QWidget(centralwidget);
        gridLayoutWidget->setObjectName(QString::fromUtf8("gridLayoutWidget"));
        gridLayoutWidget->setGeometry(QRect(10, 500, 152, 121));
        gridLayout = new QGridLayout(gridLayoutWidget);
        gridLayout->setObjectName(QString::fromUtf8("gridLayout"));
        gridLayout->setContentsMargins(0, 0, 0, 0);
        frame = new QLabel(gridLayoutWidget);
        frame->setObjectName(QString::fromUtf8("frame"));

        gridLayout->addWidget(frame, 0, 1, 1, 1);

        H_disp = new QLabel(gridLayoutWidget);
        H_disp->setObjectName(QString::fromUtf8("H_disp"));

        gridLayout->addWidget(H_disp, 2, 1, 1, 1);

        label_6 = new QLabel(gridLayoutWidget);
        label_6->setObjectName(QString::fromUtf8("label_6"));

        gridLayout->addWidget(label_6, 4, 0, 1, 1);

        label_5 = new QLabel(gridLayoutWidget);
        label_5->setObjectName(QString::fromUtf8("label_5"));

        gridLayout->addWidget(label_5, 2, 0, 1, 1);

        V_disp = new QLabel(gridLayoutWidget);
        V_disp->setObjectName(QString::fromUtf8("V_disp"));

        gridLayout->addWidget(V_disp, 4, 1, 1, 1);

        framecount = new QLabel(gridLayoutWidget);
        framecount->setObjectName(QString::fromUtf8("framecount"));

        gridLayout->addWidget(framecount, 0, 0, 1, 1);

        label_9 = new QLabel(gridLayoutWidget);
        label_9->setObjectName(QString::fromUtf8("label_9"));

        gridLayout->addWidget(label_9, 1, 0, 1, 1);

        total_frame = new QLabel(gridLayoutWidget);
        total_frame->setObjectName(QString::fromUtf8("total_frame"));

        gridLayout->addWidget(total_frame, 1, 1, 1, 1);

        dma_write = new QPushButton(centralwidget);
        dma_write->setObjectName(QString::fromUtf8("dma_write"));
        dma_write->setGeometry(QRect(10, 660, 141, 23));
        dma_read = new QPushButton(centralwidget);
        dma_read->setObjectName(QString::fromUtf8("dma_read"));
        dma_read->setGeometry(QRect(10, 690, 141, 23));
        MainWindow->setCentralWidget(centralwidget);
        menubar = new QMenuBar(MainWindow);
        menubar->setObjectName(QString::fromUtf8("menubar"));
        menubar->setGeometry(QRect(0, 0, 1800, 22));
        MainWindow->setMenuBar(menubar);
        statusbar = new QStatusBar(MainWindow);
        statusbar->setObjectName(QString::fromUtf8("statusbar"));
        MainWindow->setStatusBar(statusbar);

        retranslateUi(MainWindow);

        QMetaObject::connectSlotsByName(MainWindow);
    } // setupUi

    void retranslateUi(QMainWindow *MainWindow)
    {
        MainWindow->setWindowTitle(QCoreApplication::translate("MainWindow", "MainWindow", nullptr));
        groupBox->setTitle(QCoreApplication::translate("MainWindow", "PCIE\345\217\202\346\225\260", nullptr));
        enable_detection->setText(QCoreApplication::translate("MainWindow", "\345\220\257\347\224\250\347\233\256\346\240\207\346\243\200\346\265\213", nullptr));
        label->setText(QCoreApplication::translate("MainWindow", "Vender ID", nullptr));
        HostAddress->setText(QString());
        label_2->setText(QCoreApplication::translate("MainWindow", "Link Speed", nullptr));
        label_3->setText(QCoreApplication::translate("MainWindow", "Lane Width", nullptr));
        label_4->setText(QCoreApplication::translate("MainWindow", "Max Payload", nullptr));
        label_7->setText(QCoreApplication::translate("MainWindow", "DMA_Len", nullptr));
        Key1->setText(QCoreApplication::translate("MainWindow", "\346\211\223\345\274\200", nullptr));
        connect->setText(QCoreApplication::translate("MainWindow", "\351\207\207\351\233\206\350\247\206\351\242\221", nullptr));
        pushButton->setText(QCoreApplication::translate("MainWindow", "none", nullptr));
        Gray->setText(QCoreApplication::translate("MainWindow", "none", nullptr));
        cam1->setText(QCoreApplication::translate("MainWindow", "noe", nullptr));
        cam2->setText(QCoreApplication::translate("MainWindow", "none", nullptr));
        save->setText(QCoreApplication::translate("MainWindow", "\344\277\235\345\255\230\345\233\276\347\211\207", nullptr));
        save_video->setText(QCoreApplication::translate("MainWindow", "none", nullptr));
        Label->setText(QCoreApplication::translate("MainWindow", "<html><head/><body><p><span style=\" font-size:72pt;\">\345\233\276\345\203\217\346\230\276\347\244\272\345\214\272\345\237\237</span></p></body></html>", nullptr));
        frame->setText(QCoreApplication::translate("MainWindow", "TextLabel", nullptr));
        H_disp->setText(QString());
        label_6->setText(QCoreApplication::translate("MainWindow", "\345\236\202\347\233\264\345\210\206\350\276\250\347\216\207:", nullptr));
        label_5->setText(QCoreApplication::translate("MainWindow", "\346\260\264\345\271\263\345\210\206\350\276\250\347\216\207:", nullptr));
        V_disp->setText(QString());
        framecount->setText(QCoreApplication::translate("MainWindow", "\345\270\247\347\216\207\357\274\210fps):\357\274\211", nullptr));
        label_9->setText(QCoreApplication::translate("MainWindow", "\346\200\273\345\270\247\346\225\260:", nullptr));
        total_frame->setText(QCoreApplication::translate("MainWindow", "TextLabel", nullptr));
        dma_write->setText(QCoreApplication::translate("MainWindow", "test_dma_write", nullptr));
        dma_read->setText(QCoreApplication::translate("MainWindow", "test_dma_read", nullptr));
    } // retranslateUi

};

namespace Ui {
    class MainWindow: public Ui_MainWindow {};
} // namespace Ui

QT_END_NAMESPACE

#endif // UI_MAINWINDOW_H
