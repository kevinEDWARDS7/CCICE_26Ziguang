#ifndef FPGA_PCIE_H
#define FPGA_PCIE_H

#include <QtWidgets>
#include <linux/ioctl.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <time.h>

#define BMP_HEADER_SIZE 54

#define PCIE_DRIVER_FILE_PATH           "/dev/pango_pci_driver"         /* pcie驱动文件目录 */
#define MEM_FILE_PATH                   "/dev/mem"                      /* mem驱动文件目录 */
#define VEISION                        "Pango PCIe Test v1.0"          /* 软件测试版本信息 */

// 修复：将字符常量改为整数，避免语法错误
#define PCIE_TYPE                       0x53  // 使用十六进制代替 'S'

// 修复：使用新的宏名称，避免与系统TYPE冲突
#define PCI_READ_DATA_CMD               _IOWR(PCIE_TYPE, 0, int)               /* 读数据指令 */
#define PCI_WRITE_DATA_CMD              _IOWR(PCIE_TYPE, 1, int)               /* 写数据指令 */
#define PCI_MAP_ADDR_CMD                _IOWR(PCIE_TYPE, 2, int)               /* DMA总线地址映射 */
#define PCI_WRITE_TO_KERNEL_CMD         _IOWR(PCIE_TYPE, 3, int)               /* 写内核数据操作 */
#define PCI_DMA_READ_CMD                _IOWR(PCIE_TYPE, 4, int)               /* DMA读操作 */
#define PCI_DMA_WRITE_CMD               _IOWR(PCIE_TYPE, 5, int)               /* DMA写操作 */
#define PCI_READ_FROM_KERNEL_CMD        _IOWR(PCIE_TYPE, 6, int)               /* 读取内核数据操作 */
#define PCI_UMAP_ADDR_CMD               _IOWR(PCIE_TYPE, 7, int)               /* 释放映射地址 */
#define PCI_PERFORMANCE_START_CMD       _IOWR(PCIE_TYPE, 8, int)               /* 性能测试开始操作 */
#define PCI_PERFORMANCE_END_CMD         _IOWR(PCIE_TYPE, 9, int)               /* 性能测试结束操作 */
#define PCI_MAP_BAR0_CMD                _IOWR(PCIE_TYPE,10, int)               /* 获取bar0信息*/
#define PCI_SET_CONFIG                  _IOWR(PCIE_TYPE,11, int)               /* 配置DMA控制*/

// 工程1图像参数：1280x720
#define IMAGE_WIDTH  1280
#define IMAGE_HEIGHT 720
#define LINE_BYTES   2560    // 每行字节数：1280 * 2 (RGB565)

#define MAX_BLOCK_SIZE                  1024                            /* 位流分块缓存区最大值 */
#define DMA_MAX_PACKET_SIZE             4096                            /* DMA包最大值 */
#define DMA_MIN_PACKET_SIZE             4                               /* DMA包最小值 */

//open pci driver
int open_pci_driver(void)   ;

//--------------struct---------------------------
typedef struct _BAR_INFO_
{
    unsigned long bar_base;
    unsigned long bar_len;
} BAR_BASE_INFO;

typedef struct _CAP_INFO_
{
    unsigned char flag;
    unsigned char id;
    unsigned char addr_offset;
    unsigned char next_offset;
} CAP_INFO;

typedef struct _CAP_LIST_
{
    unsigned char cap_status;
    unsigned char cap_error;
    CAP_INFO cap_buf[256];
} CAP_LIST;

typedef struct _PCI_INFO_
{
    unsigned int vendor_id;
    unsigned int device_id;
    unsigned int cmd_reg;
    unsigned int status_reg;
    unsigned int revision_id;
    unsigned int class_prog;
    unsigned int class_device;
    BAR_BASE_INFO bar[6];
    unsigned int min_gnt;
    unsigned int max_lat;
    unsigned int link_speed;
    unsigned int link_width;
    unsigned int mps;
    unsigned int mrrs;
    unsigned int data[1024];
} PCI_DEVICE_INFO;

typedef struct _LOAD_DATA_
{
    unsigned int num_words;
    unsigned int block_words[MAX_BLOCK_SIZE];
} LOAD_DATA_INFO;

typedef struct _PCI_LOAD_
{
    unsigned char link_status;
    unsigned int  crc;
    unsigned char axi_direction;
    unsigned char load_status;
    unsigned int total_num_words;
    LOAD_DATA_INFO data_block;
} PCI_LOAD_INFO;

typedef struct _COMMAND_
{
    unsigned char w_r;
    unsigned char step;
    unsigned int addr;
    unsigned int data;
    unsigned int cnt;
    unsigned int delay;
    PCI_DEVICE_INFO get_pci_dev_info;
    CAP_LIST cap_info;
    PCI_LOAD_INFO load_info;
} COMMAND_OPERATION;

typedef struct _DMA_DATA_
{
    unsigned char read_buf[DMA_MAX_PACKET_SIZE];
    unsigned char write_buf[DMA_MAX_PACKET_SIZE];
} DMA_DATA;

typedef struct _DMA_OPERATION_
{
    unsigned int current_len;
    unsigned int offset_addr;
    unsigned int cmd;
    DMA_DATA data;
} DMA_OPERATION;

typedef struct _DEV_MEM_
{
    off_t offset;
    size_t len;
    void *vaddr;
} DEV_MEM;

typedef struct _PERFORMANCE_OPERATION_
{
    unsigned int current_len;
    unsigned int cmd;
    unsigned char cmp_flag;
} PERFORMANCE_OPERATION;

class FPGA_pcie : public QThread
{
    Q_OBJECT

public:
    FPGA_pcie();
    ~FPGA_pcie(); // 添加析构函数声明
    int getDevice(void);
    void dma_config_init(unsigned int len);
    long long int dma_read(unsigned int len,unsigned char* img_buf);
    void dma_write_test();
    void dma_write_data(unsigned char cmd_in);
    void dma_read_test();
    void write_dw_data(uchar* send_buf);
    void dma_map(bool flag);
    void dma_set_config(void);
    DMA_OPERATION dma_operation;
    DMA_OPERATION *dma_oper=&dma_operation;
    COMMAND_OPERATION command_operation;
    void pio_write(unsigned int write_data,int pio_bse_addr,int user_reg_addr);
    void pio_read(unsigned char* read_buf,int pio_addr);
    int nano_delay(long delay);
    unsigned char *img_buf  = new uchar[IMAGE_WIDTH * IMAGE_HEIGHT * 2];  // 1280x720x2
    void *map_mem(unsigned long addr, unsigned int size, DEV_MEM *map_mem);
    bool stopped = true ;
    void *mem_pio_addr =NULL;//bar0 vir adddr
    DEV_MEM map_dev_mem = {0, 0, NULL};
    int dev_fd;
protected:
    void run(void);

private:
    struct timespec ns_sleep;

    int speedRuning;

Q_SIGNALS:
    void send_wr_done(int index);
};

#endif // FPGA_PCIE_H

