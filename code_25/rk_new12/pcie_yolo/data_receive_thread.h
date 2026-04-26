#ifndef DATA_RECV_THREAD_H
#define DATA_RECV_THREAD_H

#include "FPGA_pcie.h"



#define img_w_size 1920
#define img_h_size 1080

#define mig_base_addr 0x00000000
#define mig_buf_size 3


class DataReceiveThread:public QThread
{
    Q_OBJECT
public:
    void run();
    explicit    DataReceiveThread(QObject *parent = nullptr);
    bool stopped = false;
    FPGA_pcie *pango_device;
    uchar* recv_buf;

    long mig_addr = 0;

    int img_index = 0;

    int inlen = 0;
    int outlen = 0;

    ushort* img_frame_ptr;
    ushort img_frame;


    unsigned int offset_addr=0;
    unsigned int rd_dma_times_cnt=0;


    //no use now
    uint wr_index = 0;
    uint rd_index = 0;
private:

protected:

    private slots:

signals:
    void recivok(int index);




};





#endif // DATA_RECV_THREAD_H

