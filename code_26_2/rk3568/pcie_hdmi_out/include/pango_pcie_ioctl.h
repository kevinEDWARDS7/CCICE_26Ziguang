#ifndef PANGO_PCIE_IOCTL_H
#define PANGO_PCIE_IOCTL_H

#include <linux/ioctl.h>

#define PANGO_PCIE_IOCTL_TYPE 'S'

#define PCI_MAP_ADDR_CMD          _IOWR(PANGO_PCIE_IOCTL_TYPE, 2, int)
#define PCI_DMA_READ_CMD          _IOWR(PANGO_PCIE_IOCTL_TYPE, 4, int)
#define PCI_DMA_WRITE_CMD         _IOWR(PANGO_PCIE_IOCTL_TYPE, 5, int)
#define PCI_READ_FROM_KERNEL_CMD  _IOWR(PANGO_PCIE_IOCTL_TYPE, 6, int)
#define PCI_UMAP_ADDR_CMD         _IOWR(PANGO_PCIE_IOCTL_TYPE, 7, int)

#endif
