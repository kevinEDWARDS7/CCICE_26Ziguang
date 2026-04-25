    #!/bin/sh
set -eu

if lsmod | grep -q '^pango_pci_driver'; then
    rmmod pango_pci_driver
else
    echo "pango_pci_driver is not loaded"
fi

lsmod | grep -i pango || true
