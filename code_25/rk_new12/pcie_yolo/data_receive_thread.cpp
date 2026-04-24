#include "data_receive_thread.h"
#include "FPGA_pcie.h"

DataReceiveThread::DataReceiveThread(QObject *parent) : QThread(parent)
{

    recv_buf    =   new uchar[img_w_size*img_h_size*2]  ;

}




void DataReceiveThread::run()
{
    while(!stopped)
    {


    }
}




