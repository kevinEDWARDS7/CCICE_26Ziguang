#ifndef PANGO_PCI_DRIVER_H
#define PANGO_PCI_DRIVER_H

#include <linux/cdev.h>
#include <linux/dma-mapping.h>
#include <linux/fs.h>
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/semaphore.h>
#include <linux/spinlock.h>
#include <linux/types.h>
#include <linux/uaccess.h>
#include <linux/version.h>

#define TYPE 'S'
#define PCI_READ_DATA_CMD             _IOWR(TYPE, 0, int)
#define PCI_WRITE_DATA_CMD            _IOWR(TYPE, 1, int)
#define PCI_MAP_ADDR_CMD              _IOWR(TYPE, 2, int)
#define PCI_WRITE_TO_KERNEL_CMD       _IOWR(TYPE, 3, int)
#define PCI_DMA_READ_CMD              _IOWR(TYPE, 4, int)
#define PCI_DMA_WRITE_CMD             _IOWR(TYPE, 5, int)
#define PCI_READ_FROM_KERNEL_CMD      _IOWR(TYPE, 6, int)
#define PCI_UMAP_ADDR_CMD             _IOWR(TYPE, 7, int)
#define PCI_PERFORMANCE_START_CMD     _IOWR(TYPE, 8, int)
#define PCI_PERFORMANCE_END_CMD       _IOWR(TYPE, 9, int)
#define PCI_MAP_BAR0_CMD              _IOWR(TYPE, 10, int)
#define PCI_SET_CONFIG                _IOWR(TYPE, 11, int)
#define PCI_DMA_SYNC_CMD              _IOWR(TYPE, 12, int)

#define MAX_BLOCK_SIZE                1024
#define DMA_MAX_PACKET_SIZE           4096
#define DMA_MIN_PACKET_SIZE           4

#define DMA_CMD_SENTINEL_ENABLE       0x80000000U
#define DMA_CMD_SENTINEL_MASK         0x000000ffU
#define DMA_CMD_SYNC_TIMEOUT_MASK     0x00ffff00U
#define DMA_CMD_SYNC_TIMEOUT_SHIFT    8U
#define DMA_CMD_SYNC_TIMEOUT_DEFAULT  10000U

#define CMD_REG_OFFSET                0x100
#define RW_ADDR_LO_OFFSET             0x110
#define RW_ADDR_HI_OFFSET             0x120

struct PciDriverDevInfo {
	dev_t dev;
	unsigned int firstminor;
	unsigned int count;
	const char *name;
};

struct PangoPciDriver {
	int pci_bar;
	int pci_ctrl_bar;
	resource_size_t pci_io_size;
	resource_size_t pci_ctrl_io_size;
	void __iomem *pci_io;
	void __iomem *pci_ctrl_io;
	void *pci_io_buff;
	struct pci_driver pci_driver;
};

struct PciPango {
	struct cdev cdev;
	struct PangoPciDriver pango_pci_driver;
	struct semaphore sem;
	struct class *cdev_class;
};

typedef struct _BAR_INFO_ {
	unsigned long bar_base;
	unsigned long bar_len;
} BAR_BASE_INFO;

typedef struct _CAP_INFO_ {
	unsigned char flag;
	unsigned char id;
	unsigned char addr_offset;
	unsigned char next_offset;
} CAP_INFO;

typedef struct _CAP_LIST_ {
	unsigned char cap_status;
	unsigned char cap_error;
	CAP_INFO cap_buf[256];
} CAP_LIST;

typedef struct _PCI_INFO_ {
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

typedef struct _LOAD_DATA_ {
	unsigned int num_words;
	unsigned int block_words[MAX_BLOCK_SIZE];
} LOAD_DATA_INFO;

typedef struct _PCI_LOAD_ {
	unsigned char link_status;
	unsigned int crc;
	unsigned char axi_direction;
	unsigned char load_status;
	unsigned int total_num_words;
	LOAD_DATA_INFO data_block;
} PCI_LOAD_INFO;

typedef struct _COMMAND_ {
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

typedef struct _CONFIG_ {
	unsigned int addr;
	unsigned int data;
} CONFIG_OPERATION;

typedef struct _DMA_DATA_ {
	unsigned char read_buf[DMA_MAX_PACKET_SIZE];
	unsigned char write_buf[DMA_MAX_PACKET_SIZE];
} DMA_DATA;

typedef struct _DMA_OPERATION_ {
	unsigned int current_len;
	unsigned int offset_addr;
	unsigned int cmd;
	DMA_DATA data;
} DMA_OPERATION;

typedef union _DMA_CMD_ {
	struct _cmd1_ {
		unsigned short length : 10;
		unsigned char reserved1 : 6;
		unsigned char addr_type : 1;
		unsigned char reserved2 : 7;
		unsigned char op_type : 1;
		unsigned char reserved3 : 7;
	} data;
	unsigned int value;
} DMA_CMD;

typedef struct _DMA_ADDR_ {
	char addr_size;
	dma_addr_t addr;
	dma_addr_t base_addr;
	void *data_buf;
	spinlock_t lock;
} DMA_ADDR;

typedef struct _DMA_INFO_ {
	DMA_CMD cmd;
	DMA_ADDR addr_r;
	DMA_ADDR addr_w;
	unsigned int mapped_len_bytes;
} DMA_INFO;

typedef union _DMA_PERFORMANCE_CMD_ {
	struct _cmd2_ {
		unsigned short length : 10;
		unsigned char reserved1 : 6;
		unsigned char addr_type : 1;
		unsigned char reserved2 : 7;
		unsigned char op_type : 2;
		unsigned char reserved3 : 6;
	} data;
	unsigned int value;
} DMA_PERFORMANCE_CMD;

typedef struct _DMA_PERFORMANCE_CONFIG_ {
	DMA_PERFORMANCE_CMD cmd;
	DMA_ADDR addr;
	unsigned int mapped_len_bytes;
} DMA_PERFORMANCE_CONFIG;

typedef struct _PERFORMANCE_OPERATION_ {
	unsigned int current_len;
	unsigned int cmd;
	unsigned char cmp_flag;
} PERFORMANCE_OPERATION;

loff_t pango_cdev_llseek(struct file *filp, loff_t off, int whence);
ssize_t pango_cdev_read(struct file *filp, char __user *buf, size_t count, loff_t *f_pos);
ssize_t pango_cdev_write(struct file *filp, const char __user *buf, size_t count, loff_t *f_pos);
int pango_cdev_open(struct inode *inode, struct file *filp);
long pango_cdev_ioctl(struct file *file, unsigned int cmd, unsigned long arg);
int pango_cdev_release(struct inode *inode, struct file *filp);

int pci_driver_probe(struct pci_dev *dev, const struct pci_device_id *device_id);
void pci_driver_remove(struct pci_dev *dev);

#endif
