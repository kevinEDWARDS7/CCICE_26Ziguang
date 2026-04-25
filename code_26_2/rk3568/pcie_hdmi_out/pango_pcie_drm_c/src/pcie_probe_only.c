#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "pango_pcie_abi.h"

static int pci_info_valid(const PCI_DEVICE_INFO *info)
{
    if (!info) {
        return 0;
    }
    if (info->vendor_id == 0U || info->device_id == 0U) {
        return 0;
    }
    if (info->link_speed == 0U || info->link_width == 0U) {
        return 0;
    }
    return 1;
}

static void print_pci_info(const PCI_DEVICE_INFO *info)
{
    printf("vendor=0x%04x device=0x%04x revision=0x%02x class=0x%04x prog=0x%02x\n",
           info->vendor_id,
           info->device_id,
           info->revision_id,
           info->class_device,
           info->class_prog);
    printf("link=gen%u x%u mps=%u mrrs=%u cmd=0x%04x status=0x%04x\n",
           info->link_speed,
           info->link_width,
           info->mps,
           info->mrrs,
           info->cmd_reg,
           info->status_reg);
    for (unsigned int i = 0; i < 6U; ++i) {
        printf("bar%u base=0x%lx len=0x%lx\n", i, info->bar[i].bar_base, info->bar[i].bar_len);
    }
}

static void usage(const char *prog)
{
    fprintf(stderr, "Usage: %s [--pcie /dev/pango_pci_driver]\n", prog);
}

int main(int argc, char **argv)
{
    const char *pcie_path = PCIE_DRIVER_FILE_PATH;

    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--pcie") == 0 && i + 1 < argc) {
            pcie_path = argv[++i];
        } else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            usage(argv[0]);
            return 0;
        } else {
            usage(argv[0]);
            return 2;
        }
    }

    int fd = open(pcie_path, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "open %s failed: %s\n", pcie_path, strerror(errno));
        return 1;
    }

    COMMAND_OPERATION cmd;
    memset(&cmd, 0, sizeof(cmd));

    ssize_t n = read(fd, &cmd, sizeof(cmd));
    if (n < 0) {
        fprintf(stderr, "read PCIe device info failed: %s\n", strerror(errno));
        close(fd);
        return 1;
    }

    printf("read_return=%zd expected_struct_size=%zu\n", n, sizeof(cmd));
    print_pci_info(&cmd.get_pci_dev_info);

    if (!pci_info_valid(&cmd.get_pci_dev_info)) {
        fprintf(stderr,
                "PCIe probe invalid. Refuse DMA. Check lspci, FPGA bitstream, driver probe, and PCIe reset.\n");
        close(fd);
        return 3;
    }

    printf("PCIe probe OK. It is safe to run the DMA display program.\n");
    close(fd);
    return 0;
}
