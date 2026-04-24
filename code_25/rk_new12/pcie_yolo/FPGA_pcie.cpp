#include "FPGA_pcie.h"
#include "ui_mainwindow.h"
#include <unistd.h>
#include <stdbool.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <time.h>
#include <pthread.h>
#include <sys/mman.h>
#include <string.h>     // memset、memcpy需要这个头文件
#define PAGE_ROUND_DOWN(x)				((x) & ~(getpagesize() - 1))
#define PAGE_ROUND_UP(x)				(PAGE_ROUND_DOWN((x) + getpagesize() - 1))

#define BAR0_MAX                       0x500
void* FPGA_pcie::map_mem(unsigned long addr, unsigned int size, DEV_MEM *map_mem)
{
    int fd = -1;
    void *vaddr = NULL;
    off_t offset;
    size_t len;
    if(map_mem->vaddr != NULL)
    {
        //printf("Bar0 is busy, please release it first\n");
        qDebug()<<"Bar0 is busy, please release it first\n";
        return vaddr;
    }

    offset = PAGE_ROUND_DOWN(addr);
    len    = PAGE_ROUND_UP(size);
    if ((offset == map_mem->offset) && (len == map_mem->len))
        return map_mem->vaddr;

    fd = open(MEM_FILE_PATH, O_RDWR | O_SYNC);
    if(fd < 0)
    {
        //printf("open '%s' failed !!!\n", MEM_FILE_PATH);
        qDebug()<<"open failed !!!"<<MEM_FILE_PATH;
    }
    else
    {
        vaddr = mmap(NULL, len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, offset);
        close(fd);
    }
    if ((vaddr == NULL) || (vaddr == MAP_FAILED))
    {
        //printf("mmap '%s' failed !!!\n", MEM_FILE_PATH);
        qDebug()<<"mmap failed !!!"<<MEM_FILE_PATH;
    }
    else
    {
        map_mem->len 	= len;
        map_mem->offset = offset;
        map_mem->vaddr 	= vaddr;
    }
    //qDebug()<<"bar0 vir addr is at"<<vaddr;
    qDebug() << "bar0 vir addr is at" << Qt::hex << reinterpret_cast<quintptr>(vaddr);
    return vaddr;
}
//initial
FPGA_pcie::FPGA_pcie()
{
    dev_fd  =   -1;
}

// 添加析构函数实现
FPGA_pcie::~FPGA_pcie()
{
    // 如果有内存映射，释放
    if (map_dev_mem.vaddr && map_dev_mem.len > 0) {
        munmap(map_dev_mem.vaddr, map_dev_mem.len);
        map_dev_mem.vaddr = nullptr;
        map_dev_mem.len = 0;
    }
    // 释放img_buf
    if (img_buf) {
        delete[] img_buf;
        img_buf = nullptr;
    }
    // 关闭设备文件
    if (dev_fd > 0) {
        close(dev_fd);
        dev_fd = -1;
    }
}

int FPGA_pcie::nano_delay(long delay)
{
    struct timespec req, rem;
    long nano_delay = delay;
    int ret = 0;
    while(nano_delay > 0)
    {
        rem.tv_sec = 0;
        rem.tv_nsec = 0;
        req.tv_sec = 0;
        req.tv_nsec = nano_delay;
        if(ret = (nanosleep(&req, &rem) == -1))
        {
       //     printf_error("nanosleep failed !!!\n");
        }
        nano_delay = rem.tv_nsec;
    };

    return ret;
}




void FPGA_pcie::pio_write(unsigned int  write_data,int pio_bse_addr,int user_reg_addr)
{

    *((unsigned int *)mem_pio_addr + pio_bse_addr + user_reg_addr ) = write_data  ;


}

void FPGA_pcie::pio_read(unsigned char* read_buf,int pio_addr)
{

    *read_buf  =  *((unsigned char *)mem_pio_addr + pio_addr) ;
    //qDebug()<<"read data is"<<;


}

void FPGA_pcie::dma_write_test()
{
    dma_oper->current_len=(4>>2);
    memset(dma_oper->data.write_buf,0,DMA_MAX_PACKET_SIZE);
    dma_oper->data.write_buf[0]=0x31;
    ioctl(dev_fd,PCI_MAP_ADDR_CMD,dma_oper);
    ioctl(dev_fd,PCI_WRITE_TO_KERNEL_CMD,dma_oper);//write data to kernel
    ioctl(dev_fd,PCI_DMA_READ_CMD,dma_oper);//DMA read data to device
    for(int i =0; i<=1250;i++)
    {}
    ioctl(dev_fd,PCI_UMAP_ADDR_CMD,dma_oper);


}



void FPGA_pcie::dma_map(bool flag)
{
    if(flag)
    {
        ioctl(dev_fd,PCI_MAP_ADDR_CMD,dma_oper);
    }
    else
    {
        ioctl(dev_fd,PCI_UMAP_ADDR_CMD,dma_oper);
    }
}


void FPGA_pcie::dma_set_config(void)
{
    ioctl(dev_fd,PCI_SET_CONFIG,dma_oper);

}




void FPGA_pcie::dma_write_data(unsigned char cmd_in)
{
    ioctl(dev_fd,PCI_WRITE_TO_KERNEL_CMD,dma_oper);//write data to kernel
    for(int i =0; i<=1250;i++)
    {}
    ioctl(dev_fd,PCI_DMA_READ_CMD,dma_oper);//DMA read data to device

}



void FPGA_pcie::write_dw_data(uchar* send_buf)
{
    dma_oper->current_len=(16>>2);
    memset(dma_oper->data.write_buf,0,DMA_MAX_PACKET_SIZE);
    dma_oper->data.write_buf[0]=send_buf[0];
    dma_oper->data.write_buf[1]=send_buf[1];
    dma_oper->data.write_buf[2]=send_buf[2];
    dma_oper->data.write_buf[3]=send_buf[3];
    ioctl(dev_fd,PCI_MAP_ADDR_CMD,dma_oper);
    ioctl(dev_fd,PCI_WRITE_TO_KERNEL_CMD,dma_oper);//write data to kernel
    ioctl(dev_fd,PCI_DMA_READ_CMD,dma_oper);//DMA read data to device
    for(int i =0; i<=1250;i++)
    {}
    ioctl(dev_fd,PCI_UMAP_ADDR_CMD,dma_oper);
}


long long int  FPGA_pcie::dma_read(unsigned int len,unsigned char* img_buf)
{
    //读取数据
    return read(dev_fd,img_buf,len);
}



void FPGA_pcie::dma_read_test()
{
    dma_oper->current_len=(4>>2);
    memset(dma_oper->data.read_buf,0,DMA_MAX_PACKET_SIZE);
    ioctl(dev_fd,PCI_MAP_ADDR_CMD,dma_oper);
    ioctl(dev_fd,PCI_DMA_WRITE_CMD,dma_oper);//write data to kernel from device
    nano_delay(8000);
    ioctl(dev_fd,PCI_READ_FROM_KERNEL_CMD,dma_oper);//read data to usr from kernel
    ioctl(dev_fd,PCI_UMAP_ADDR_CMD,dma_oper);
    for(int i=0;i<=3;i++)
    {
        qDebug()<<"data is "<<dma_oper->data.read_buf[i];
    }
}




COMMAND_OPERATION cmd_op ={};

//get device
int FPGA_pcie::getDevice()
{
    ns_sleep.tv_nsec = 1;//1ns
    dev_fd  =   open(PCIE_DRIVER_FILE_PATH, O_RDWR);
    if(dev_fd < 0)
    {
        return  -1  ;
    }
    else
    {
        //read(dev_fd, &command_operation, sizeof(command_operation));
        ioctl(dev_fd,PCI_READ_DATA_CMD,&command_operation);
        // 打印 vendor ID

        qDebug().nospace() << "vendor_id:"
                           << Qt::hex << qSetFieldWidth(4) << qSetPadChar('0')
                           << command_operation.get_pci_dev_info.vendor_id
                           << Qt::reset;

        // 打印 device ID
        qDebug().nospace() << "device_id:"
                           << Qt::hex << qSetFieldWidth(4) << qSetPadChar('0')
                           << command_operation.get_pci_dev_info.device_id
                           << Qt::reset;

        //打印 link speed and width
        qDebug().nospace()
            << "link up: gen"
            << command_operation.get_pci_dev_info.link_speed
            << " width x"
            << command_operation.get_pci_dev_info.link_width;
        //打印 max payload
        qDebug().nospace()
            << "max payload:"
            << command_operation.get_pci_dev_info.mps;


        dma_set_config();
        ioctl(dev_fd, PCI_MAP_BAR0_CMD, &cmd_op);						/*获取 bar0 地址映射 */
        mem_pio_addr = map_mem(cmd_op.get_pci_dev_info.bar[0].bar_base , BAR0_MAX , &map_dev_mem);


    }
    return  dev_fd  ;

}

//config dma
void FPGA_pcie::dma_config_init(unsigned int len)
{
     dma_oper->current_len=len>>2   ;   //DW
     dma_oper->offset_addr = 0      ;
}

//线程接收 - 工程1模式：逐行读取
void FPGA_pcie::run()
{
    qDebug() << "启动图像采集线程 - 工程1模式 (逐行读取)";
    qDebug() << "图像尺寸:" << IMAGE_WIDTH << "x" << IMAGE_HEIGHT;
    qDebug() << "每行字节:" << LINE_BYTES;
    
    while(!stopped)
    {
        // 参考工程1的读取方式（02_pcie_image_test_720p）
        dma_oper->current_len = LINE_BYTES / 4;  // 转换为DW（双字）= 640
        dma_oper->offset_addr = 0;
        memset(dma_oper->data.write_buf, 0, DMA_MAX_PACKET_SIZE);
        memset(dma_oper->data.read_buf, 0, DMA_MAX_PACKET_SIZE);
        
        // 映射DMA地址
        ioctl(dev_fd, PCI_MAP_ADDR_CMD, dma_oper);
        
        // 逐行读取（720行）
        for (int line = 0; line < IMAGE_HEIGHT; line++) {
            if(stopped) break;  // 检查停止标志
            
            memset(dma_oper->data.read_buf, 0, DMA_MAX_PACKET_SIZE);
            
            // 从FPGA读取一行数据到内核
            ioctl(dev_fd, PCI_DMA_WRITE_CMD, dma_oper);
            
            // 小延时（参考工程1：02_pcie_image_test_720p/main.cpp line 238）
            for(int k = 0; k < 4000; k++);
            
            // 从内核读取数据到用户空间
            ioctl(dev_fd, PCI_READ_FROM_KERNEL_CMD, dma_oper);
            
            // 拷贝到图像缓冲区
            memcpy(img_buf + line * LINE_BYTES, dma_oper->data.read_buf, LINE_BYTES);
        }
        
        // 解除映射
        ioctl(dev_fd, PCI_UMAP_ADDR_CMD, dma_oper);
        
        // 一帧读取完成，发送信号
        if(!stopped) {
            emit send_wr_done(1);
        }
        
        // 控制帧率，避免过快读取
        usleep(10000);  // 10ms延时
    }
    
    qDebug() << "图像采集线程已停止";
}

