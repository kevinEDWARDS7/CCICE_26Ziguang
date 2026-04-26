#include "pango_pci_driver.h"
#include "id_config.h"

#include <linux/delay.h>
#include <linux/err.h>
#include <linux/io.h>
#include <linux/slab.h>
#include <linux/string.h>

#define PCI_DRIVER_DEV_COUNT 1
#define PCI_DRIVER_DEV_NAME "pango_pci_driver"

#ifndef NDEBUG
#define LOG(fmt, ...) printk(KERN_INFO "pango_pci_driver: " fmt, ##__VA_ARGS__)
#else
#define LOG(fmt, ...)
#endif

static COMMAND_OPERATION command_operation;
static COMMAND_OPERATION config_operation;
static DMA_OPERATION dma_operation;
static DMA_INFO dma_info;
static DMA_PERFORMANCE_CONFIG performance_config;
static PERFORMANCE_OPERATION performance_operation;
static struct pci_dev *op_dev;

static int init_pango_cdev(struct cdev *pango_cdev);
static int init_pango_pci_driver(struct pci_driver *pango_pci_driver);
static int init_pango_cdev_class(struct class **pango_cdev_class);
static void exit_pango_cdev(struct cdev *pango_cdev);
static void exit_pango_pci_driver(struct pci_driver *pango_pci_driver);
static void exit_pango_cdev_class(struct class **pango_cdev_class);

static const struct file_operations pango_cdev_fops = {
	.owner = THIS_MODULE,
	.llseek = pango_cdev_llseek,
	.read = pango_cdev_read,
	.write = pango_cdev_write,
	.open = pango_cdev_open,
	.unlocked_ioctl = pango_cdev_ioctl,
	.release = pango_cdev_release,
};

static struct PciDriverDevInfo pci_dev_info = {
	.dev = 0,
	.firstminor = 0,
	.count = PCI_DRIVER_DEV_COUNT,
	.name = PCI_DRIVER_DEV_NAME,
};

static const struct pci_device_id pci_pango_device_ids[] = {
	{ PCI_DEVICE(PCI_PANGO_DEFAULT_VENDOR_ID, PCI_PANGO_DEFAULT_DEVICE_ID) },
	{ 0, }
};
MODULE_DEVICE_TABLE(pci, pci_pango_device_ids);

static struct PciPango pci_info = {
	.pango_pci_driver = {
		.pci_bar = 0,
		.pci_io_size = 0,
		.pci_io = NULL,
		.pci_io_buff = NULL,
		.pci_driver = {
			.name = PCI_DRIVER_DEV_NAME,
			.id_table = pci_pango_device_ids,
			.probe = pci_driver_probe,
			.remove = pci_driver_remove,
		},
	},
	.cdev_class = NULL,
};

static int dma_len_valid(unsigned int current_len)
{
	unsigned int bytes = current_len * 4U;

	if (current_len == 0 || bytes == 0)
		return 0;
	if (bytes > DMA_MAX_PACKET_SIZE)
		return 0;
	return 1;
}

static int hw_ready(struct PciPango *pci_pango)
{
	if (!op_dev)
		return -ENODEV;
	if (!pci_pango->pango_pci_driver.pci_io)
		return -ENODEV;
	return 0;
}

static void free_dma_buffers(void)
{
	if (!op_dev)
		return;

	if (dma_info.addr_r.data_buf) {
		dma_free_coherent(&op_dev->dev, dma_info.mapped_len_bytes,
				  dma_info.addr_r.data_buf, dma_info.addr_r.base_addr);
		dma_info.addr_r.data_buf = NULL;
	}
	if (dma_info.addr_w.data_buf) {
		dma_free_coherent(&op_dev->dev, dma_info.mapped_len_bytes,
				  dma_info.addr_w.data_buf, dma_info.addr_w.base_addr);
		dma_info.addr_w.data_buf = NULL;
	}
	dma_info.mapped_len_bytes = 0;
}

static void set_dma_w_r(unsigned int value, struct PciPango *pci_pango)
{
	iowrite32(value, pci_pango->pango_pci_driver.pci_io + CMD_REG_OFFSET);
}

static void set_dma_addr(const DMA_ADDR *dma_addr, struct PciPango *pci_pango)
{
	iowrite32(lower_32_bits(dma_addr->addr),
		  pci_pango->pango_pci_driver.pci_io + RW_ADDR_LO_OFFSET);
	if (dma_addr->addr_size)
		iowrite32(upper_32_bits(dma_addr->addr),
			  pci_pango->pango_pci_driver.pci_io + RW_ADDR_HI_OFFSET);
}

loff_t pango_cdev_llseek(struct file *filp, loff_t off, int whence)
{
	struct PciPango *pci_pango = &pci_info;
	loff_t newpos;

	switch (whence) {
	case SEEK_SET:
		newpos = off;
		break;
	case SEEK_CUR:
		newpos = filp->f_pos + off;
		break;
	case SEEK_END:
		newpos = pci_pango->pango_pci_driver.pci_io_size + off;
		break;
	default:
		return -EINVAL;
	}

	if (newpos < 0)
		return -EINVAL;
	filp->f_pos = newpos;
	return newpos;
}

static void read_config(struct pci_dev *pdev)
{
	u8 valb, id, next;
	u16 valw;
	u32 valdw;
	int pos;

	memset(&command_operation, 0, sizeof(command_operation));

	for (int i = 0; i < 1024; i++) {
		pci_read_config_dword(pdev, i * 4, &valdw);
		command_operation.get_pci_dev_info.data[i] = valdw;
	}

	pci_read_config_word(pdev, PCI_VENDOR_ID, &valw);
	command_operation.get_pci_dev_info.vendor_id = valw;
	printk(KERN_INFO "Vendor ID: 0x%x\n", valw);

	pci_read_config_word(pdev, PCI_DEVICE_ID, &valw);
	command_operation.get_pci_dev_info.device_id = valw;
	printk(KERN_INFO "Device ID: 0x%x\n", valw);

	pci_read_config_word(pdev, PCI_COMMAND, &valw);
	command_operation.get_pci_dev_info.cmd_reg = valw;
	pci_read_config_word(pdev, PCI_STATUS, &valw);
	command_operation.get_pci_dev_info.status_reg = valw;
	pci_read_config_byte(pdev, PCI_REVISION_ID, &valb);
	command_operation.get_pci_dev_info.revision_id = valb;
	pci_read_config_byte(pdev, PCI_CLASS_PROG, &valb);
	command_operation.get_pci_dev_info.class_prog = valb;
	pci_read_config_word(pdev, PCI_CLASS_DEVICE, &valw);
	command_operation.get_pci_dev_info.class_device = valw;

	for (int i = 0; i <= 5; i++) {
		command_operation.get_pci_dev_info.bar[i].bar_base = pci_resource_start(pdev, i);
		command_operation.get_pci_dev_info.bar[i].bar_len = pci_resource_len(pdev, i);
		printk(KERN_INFO "BAR%d: Addr:0x%lx Len:0x%lx\n",
		       i,
		       command_operation.get_pci_dev_info.bar[i].bar_base,
		       command_operation.get_pci_dev_info.bar[i].bar_len);
	}

	pci_read_config_byte(pdev, PCI_MIN_GNT, &valb);
	command_operation.get_pci_dev_info.min_gnt = valb;
	pci_read_config_byte(pdev, PCI_MAX_LAT, &valb);
	command_operation.get_pci_dev_info.max_lat = valb;

	pos = pci_find_capability(pdev, PCI_CAP_ID_EXP);
	if (pos) {
		pci_read_config_word(pdev, pos + PCI_EXP_LNKSTA, &valw);
		command_operation.get_pci_dev_info.link_speed = valw & 0x000f;
		command_operation.get_pci_dev_info.link_width = (valw & 0x03f0) >> 4;
		printk(KERN_INFO "Link Speed: %d\n",
		       command_operation.get_pci_dev_info.link_speed);
		printk(KERN_INFO "Link Width: x%d\n",
		       command_operation.get_pci_dev_info.link_width);

		pci_read_config_word(pdev, pos + PCI_EXP_DEVCTL, &valw);
		command_operation.get_pci_dev_info.mps =
			128 << ((valw & PCI_EXP_DEVCTL_PAYLOAD) >> 5);
		command_operation.get_pci_dev_info.mrrs =
			128 << ((valw & PCI_EXP_DEVCTL_READRQ) >> 12);
		printk(KERN_INFO "MPS: %d\n", command_operation.get_pci_dev_info.mps);
		printk(KERN_INFO "MRRS: %d\n", command_operation.get_pci_dev_info.mrrs);
	}

	pci_read_config_word(pdev, PCI_STATUS, &valw);
	command_operation.cap_info.cap_error = 0;
	if (!(valw & PCI_STATUS_CAP_LIST)) {
		command_operation.cap_info.cap_status = 0;
		return;
	}

	command_operation.cap_info.cap_status = 1;
	pci_read_config_byte(pdev, PCI_CAPABILITY_LIST, &valb);
	valb &= ~3;
	while (valb) {
		pci_read_config_byte(pdev, valb + PCI_CAP_LIST_ID, &id);
		pci_read_config_byte(pdev, valb + PCI_CAP_LIST_NEXT, &next);
		next &= ~3;
		command_operation.cap_info.cap_buf[valb].flag = 1;
		command_operation.cap_info.cap_buf[valb].id = id;
		command_operation.cap_info.cap_buf[valb].addr_offset = valb;
		command_operation.cap_info.cap_buf[valb].next_offset = next;
		if (id == 0xff) {
			command_operation.cap_info.cap_error = 1;
			break;
		}
		valb = next;
	}
}

ssize_t pango_cdev_read(struct file *filp, char __user *buf, size_t count, loff_t *f_pos)
{
	(void)filp;
	(void)count;
	(void)f_pos;

	if (copy_to_user(buf, &command_operation, sizeof(COMMAND_OPERATION)))
		return -EFAULT;
	return 1;
}

ssize_t pango_cdev_write(struct file *filp, const char __user *buf, size_t count, loff_t *f_pos)
{
	(void)filp;
	(void)buf;
	(void)f_pos;
	return count;
}

long pango_cdev_ioctl(struct file *file, unsigned int cmd, unsigned long arg)
{
	struct PciPango *pci_pango = &pci_info;
	unsigned int len_bytes;
	int ret = 0;

	(void)file;

	if (down_interruptible(&pci_pango->sem))
		return -ERESTARTSYS;

	switch (cmd) {
	case PCI_READ_DATA_CMD:
		if (!op_dev) {
			ret = -ENODEV;
			break;
		}
		if (copy_from_user(&config_operation, (COMMAND_OPERATION __user *)arg,
				   sizeof(COMMAND_OPERATION))) {
			ret = -EFAULT;
			break;
		}
		if (config_operation.addr)
			pci_read_config_dword(op_dev, config_operation.addr,
					      &config_operation.data);
		config_operation.get_pci_dev_info = command_operation.get_pci_dev_info;
		config_operation.cap_info = command_operation.cap_info;
		config_operation.load_info = command_operation.load_info;
		if (copy_to_user((COMMAND_OPERATION __user *)arg, &config_operation,
				 sizeof(COMMAND_OPERATION)))
			ret = -EFAULT;
		break;

	case PCI_WRITE_DATA_CMD:
		if (!op_dev) {
			ret = -ENODEV;
			break;
		}
		if (copy_from_user(&config_operation, (COMMAND_OPERATION __user *)arg,
				   sizeof(COMMAND_OPERATION))) {
			ret = -EFAULT;
			break;
		}
		pci_write_config_dword(op_dev, config_operation.addr, config_operation.data);
		break;

	case PCI_MAP_ADDR_CMD:
		ret = hw_ready(pci_pango);
		if (ret)
			break;
		if (copy_from_user(&dma_operation, (DMA_OPERATION __user *)arg,
				   sizeof(DMA_OPERATION))) {
			ret = -EFAULT;
			break;
		}
		if (!dma_len_valid(dma_operation.current_len)) {
			ret = -EINVAL;
			break;
		}
		free_dma_buffers();
		len_bytes = dma_operation.current_len * 4U;
		dma_info.addr_r.data_buf = dma_alloc_coherent(&op_dev->dev, len_bytes,
							       &dma_info.addr_r.base_addr,
							       GFP_KERNEL);
		dma_info.addr_w.data_buf = dma_alloc_coherent(&op_dev->dev, len_bytes,
							       &dma_info.addr_w.base_addr,
							       GFP_KERNEL);
		if (!dma_info.addr_r.data_buf || !dma_info.addr_w.data_buf) {
			dma_info.mapped_len_bytes = len_bytes;
			free_dma_buffers();
			ret = -ENOMEM;
			break;
		}
		dma_info.mapped_len_bytes = len_bytes;
		dma_info.addr_r.addr = dma_info.addr_r.base_addr + dma_operation.offset_addr;
		dma_info.addr_w.addr = dma_info.addr_w.base_addr + dma_operation.offset_addr;
		dma_info.addr_r.addr_size = upper_32_bits(dma_info.addr_r.addr) ? 1 : 0;
		dma_info.addr_w.addr_size = upper_32_bits(dma_info.addr_w.addr) ? 1 : 0;
		dma_info.cmd.value = 0;
		dma_info.cmd.data.length = dma_operation.current_len - 1;
		dma_info.cmd.data.addr_type = dma_info.addr_r.addr_size;
		LOG("DMA map len=%u bytes r=%pad w=%pad offset=0x%x\n",
		    len_bytes, &dma_info.addr_r.base_addr, &dma_info.addr_w.base_addr,
		    dma_operation.offset_addr);
		break;

	case PCI_WRITE_TO_KERNEL_CMD:
		if (!dma_info.addr_r.data_buf || !dma_len_valid(dma_operation.current_len)) {
			ret = -EINVAL;
			break;
		}
		if (copy_from_user(&dma_operation, (DMA_OPERATION __user *)arg,
				   sizeof(DMA_OPERATION))) {
			ret = -EFAULT;
			break;
		}
		len_bytes = dma_operation.current_len * 4U;
		if (len_bytes > dma_info.mapped_len_bytes) {
			ret = -EINVAL;
			break;
		}
		memcpy(dma_info.addr_r.data_buf, dma_operation.data.write_buf, len_bytes);
		memset(dma_info.addr_w.data_buf, 0, len_bytes);
		break;

	case PCI_DMA_READ_CMD:
		ret = hw_ready(pci_pango);
		if (ret)
			break;
		if (!dma_info.addr_r.data_buf || !dma_len_valid(dma_operation.current_len)) {
			ret = -EINVAL;
			break;
		}
		dma_info.cmd.data.op_type = 0;
		dma_info.cmd.data.addr_type = dma_info.addr_r.addr_size;
		set_dma_addr(&dma_info.addr_r, pci_pango);
		set_dma_w_r(dma_info.cmd.value, pci_pango);
		break;

	case PCI_DMA_WRITE_CMD:
		ret = hw_ready(pci_pango);
		if (ret)
			break;
		if (!dma_info.addr_w.data_buf || !dma_len_valid(dma_operation.current_len)) {
			ret = -EINVAL;
			break;
		}
		memset(dma_info.addr_w.data_buf, 0, dma_operation.current_len * 4U);
		dma_info.cmd.data.op_type = 1;
		dma_info.cmd.data.addr_type = dma_info.addr_w.addr_size;
		set_dma_addr(&dma_info.addr_w, pci_pango);
		set_dma_w_r(dma_info.cmd.value, pci_pango);
		break;

	case PCI_READ_FROM_KERNEL_CMD:
		if (!dma_info.addr_w.data_buf || !dma_len_valid(dma_operation.current_len)) {
			ret = -EINVAL;
			break;
		}
		len_bytes = dma_operation.current_len * 4U;
		if (len_bytes > dma_info.mapped_len_bytes) {
			ret = -EINVAL;
			break;
		}
		memcpy(dma_operation.data.read_buf, dma_info.addr_w.data_buf, len_bytes);
		if (copy_to_user((DMA_OPERATION __user *)arg, &dma_operation,
				 sizeof(DMA_OPERATION)))
			ret = -EFAULT;
		break;

	case PCI_UMAP_ADDR_CMD:
		free_dma_buffers();
		break;

	case PCI_PERFORMANCE_START_CMD:
		ret = hw_ready(pci_pango);
		if (ret)
			break;
		if (copy_from_user(&performance_operation, (PERFORMANCE_OPERATION __user *)arg,
				   sizeof(PERFORMANCE_OPERATION))) {
			ret = -EFAULT;
			break;
		}
		if (!dma_len_valid(performance_operation.current_len)) {
			ret = -EINVAL;
			break;
		}
		performance_config.mapped_len_bytes = DMA_MAX_PACKET_SIZE * 20U;
		performance_config.addr.data_buf =
			dma_alloc_coherent(&op_dev->dev, performance_config.mapped_len_bytes,
					   &performance_config.addr.base_addr, GFP_KERNEL);
		if (!performance_config.addr.data_buf) {
			ret = -ENOMEM;
			break;
		}
		performance_config.addr.addr = performance_config.addr.base_addr;
		performance_config.addr.addr_size =
			upper_32_bits(performance_config.addr.addr) ? 1 : 0;
		performance_config.cmd.value = 0;
		performance_config.cmd.data.length = performance_operation.current_len - 1;
		performance_config.cmd.data.addr_type = performance_config.addr.addr_size;
		performance_config.cmd.data.op_type = performance_operation.cmd;
		set_dma_addr(&performance_config.addr, pci_pango);
		set_dma_w_r(performance_config.cmd.value, pci_pango);
		break;

	case PCI_PERFORMANCE_END_CMD:
		if (performance_config.addr.data_buf) {
			performance_operation.cmp_flag =
				!memcmp(performance_config.addr.data_buf,
					performance_config.addr.data_buf + DMA_MAX_PACKET_SIZE * 10,
					DMA_MAX_PACKET_SIZE * 10);
			if (copy_to_user((PERFORMANCE_OPERATION __user *)arg,
					 &performance_operation,
					 sizeof(PERFORMANCE_OPERATION)))
				ret = -EFAULT;
			dma_free_coherent(&op_dev->dev, performance_config.mapped_len_bytes,
					  performance_config.addr.data_buf,
					  performance_config.addr.base_addr);
			performance_config.addr.data_buf = NULL;
			performance_config.mapped_len_bytes = 0;
		}
		break;

	case PCI_MAP_BAR0_CMD:
		if (!op_dev) {
			ret = -ENODEV;
			break;
		}
		if (copy_to_user((COMMAND_OPERATION __user *)arg, &command_operation,
				 sizeof(COMMAND_OPERATION)))
			ret = -EFAULT;
		break;

	case PCI_SET_CONFIG:
		ret = hw_ready(pci_pango);
		break;

	default:
		ret = -ENOTTY;
		break;
	}

	up(&pci_pango->sem);
	return ret;
}

int pango_cdev_open(struct inode *inode, struct file *filp)
{
	(void)inode;
	(void)filp;
	return 0;
}

int pango_cdev_release(struct inode *inode, struct file *filp)
{
	(void)inode;
	(void)filp;
	return 0;
}

static int set_dma_mask(struct pci_dev *pdev)
{
	if (!pdev)
		return -EINVAL;
	if (!dma_set_mask_and_coherent(&pdev->dev, DMA_BIT_MASK(64)))
		return 0;
	if (!dma_set_mask_and_coherent(&pdev->dev, DMA_BIT_MASK(32)))
		return 0;
	return -EINVAL;
}

static void pci_keep_intx_enabled(struct pci_dev *pdev)
{
	u16 pcmd, pcmd_new;

	pci_read_config_word(pdev, PCI_COMMAND, &pcmd);
	pcmd_new = pcmd & ~PCI_COMMAND_INTX_DISABLE;
	if (pcmd_new != pcmd)
		pci_write_config_word(pdev, PCI_COMMAND, pcmd_new);
}

int pci_driver_probe(struct pci_dev *dev, const struct pci_device_id *device_id)
{
	struct PangoPciDriver *drv = &pci_info.pango_pci_driver;
	unsigned long bar_address;
	int result;

	(void)device_id;
	LOG("pci_driver_probe vendor=0x%x device=0x%x\n", dev->vendor, dev->device);

	result = pci_enable_device(dev);
	if (result)
		return result;

	result = set_dma_mask(dev);
	if (result)
		goto fail_disable;

	op_dev = dev;
	read_config(dev);
	pci_set_master(dev);

	result = pci_request_region(dev, drv->pci_bar, PCI_DRIVER_DEV_NAME);
	if (result)
		goto fail_master;

	drv->pci_io_size = pci_resource_len(dev, drv->pci_bar);
	bar_address = pci_resource_start(dev, drv->pci_bar);
	drv->pci_io = ioremap(bar_address, drv->pci_io_size);
	if (!drv->pci_io) {
		result = -ENOMEM;
		goto fail_region;
	}

	drv->pci_io_buff = kzalloc(drv->pci_io_size, GFP_KERNEL);
	if (!drv->pci_io_buff) {
		result = -ENOMEM;
		goto fail_iounmap;
	}

	spin_lock_init(&dma_info.addr_r.lock);
	spin_lock_init(&dma_info.addr_w.lock);
	spin_lock_init(&performance_config.addr.lock);
	pci_keep_intx_enabled(dev);
	return 0;

fail_iounmap:
	iounmap(drv->pci_io);
	drv->pci_io = NULL;
fail_region:
	pci_release_region(dev, drv->pci_bar);
fail_master:
	pci_clear_master(dev);
	op_dev = NULL;
fail_disable:
	pci_disable_device(dev);
	return result;
}

void pci_driver_remove(struct pci_dev *dev)
{
	struct PangoPciDriver *drv = &pci_info.pango_pci_driver;

	free_dma_buffers();
	if (performance_config.addr.data_buf) {
		dma_free_coherent(&dev->dev, performance_config.mapped_len_bytes,
				  performance_config.addr.data_buf,
				  performance_config.addr.base_addr);
		performance_config.addr.data_buf = NULL;
		performance_config.mapped_len_bytes = 0;
	}

	kfree(drv->pci_io_buff);
	drv->pci_io_buff = NULL;
	if (drv->pci_io) {
		iounmap(drv->pci_io);
		drv->pci_io = NULL;
	}
	pci_release_region(dev, drv->pci_bar);
	pci_clear_master(dev);
	pci_disable_device(dev);
	op_dev = NULL;
	LOG("pci_driver_remove\n");
}

static int init_pango_cdev(struct cdev *pango_cdev)
{
	int result;

	result = alloc_chrdev_region(&pci_dev_info.dev, pci_dev_info.firstminor,
				     pci_dev_info.count, pci_dev_info.name);
	if (result < 0)
		return result;

	cdev_init(pango_cdev, &pango_cdev_fops);
	pango_cdev->owner = THIS_MODULE;
	result = cdev_add(pango_cdev, pci_dev_info.dev, pci_dev_info.count);
	if (result < 0)
		unregister_chrdev_region(pci_dev_info.dev, pci_dev_info.count);
	return result;
}

static void exit_pango_cdev(struct cdev *pango_cdev)
{
	cdev_del(pango_cdev);
	unregister_chrdev_region(pci_dev_info.dev, pci_dev_info.count);
}

static int init_pango_pci_driver(struct pci_driver *pango_pci_driver)
{
	return pci_register_driver(pango_pci_driver);
}

static void exit_pango_pci_driver(struct pci_driver *pango_pci_driver)
{
	pci_unregister_driver(pango_pci_driver);
}

static int init_pango_cdev_class(struct class **pango_cdev_class)
{
	struct device *pdev;

	if (!pango_cdev_class)
		return -EINVAL;

#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 4, 0)
	*pango_cdev_class = class_create(pci_dev_info.name);
#else
	*pango_cdev_class = class_create(THIS_MODULE, pci_dev_info.name);
#endif
	if (IS_ERR(*pango_cdev_class))
		return PTR_ERR(*pango_cdev_class);

	pdev = device_create(*pango_cdev_class, NULL, pci_dev_info.dev, NULL,
			     "%s", pci_dev_info.name);
	if (IS_ERR(pdev)) {
		int result = PTR_ERR(pdev);
		class_destroy(*pango_cdev_class);
		*pango_cdev_class = NULL;
		return result;
	}
	return 0;
}

static void exit_pango_cdev_class(struct class **pango_cdev_class)
{
	if (!pango_cdev_class || !*pango_cdev_class)
		return;
	device_destroy(*pango_cdev_class, pci_dev_info.dev);
	class_destroy(*pango_cdev_class);
	*pango_cdev_class = NULL;
}

static int __init init_pci_pango(void)
{
	int result;

	sema_init(&pci_info.sem, 1);

	result = init_pango_cdev(&pci_info.cdev);
	if (result)
		return result;

	result = init_pango_pci_driver(&pci_info.pango_pci_driver.pci_driver);
	if (result)
		goto fail_cdev;

	result = init_pango_cdev_class(&pci_info.cdev_class);
	if (result)
		goto fail_pci;

	return 0;

fail_pci:
	exit_pango_pci_driver(&pci_info.pango_pci_driver.pci_driver);
fail_cdev:
	exit_pango_cdev(&pci_info.cdev);
	return result;
}

static void __exit exit_pci_pango(void)
{
	exit_pango_cdev_class(&pci_info.cdev_class);
	exit_pango_pci_driver(&pci_info.pango_pci_driver.pci_driver);
	exit_pango_cdev(&pci_info.cdev);
}

module_init(init_pci_pango);
module_exit(exit_pci_pango);

MODULE_AUTHOR("Pango, lxg.; code_26_2 port");
MODULE_DESCRIPTION("Pango PCIe DMA driver for RK3568 HDMI output path");
MODULE_LICENSE("GPL v2");
MODULE_ALIAS("pango pci driver");
