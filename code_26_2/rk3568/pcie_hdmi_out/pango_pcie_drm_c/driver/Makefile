CONFIG_MODULE_SIG=n

KDIR ?= /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

obj-m := pango_pci_driver.o

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean

.PHONY: all clean
