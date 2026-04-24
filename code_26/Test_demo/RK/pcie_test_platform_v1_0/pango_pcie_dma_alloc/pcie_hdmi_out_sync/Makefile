CC ?= gcc
PKG_CONFIG ?= pkg-config

CFLAGS ?= -O2 -Wall -Wextra
DRM_CFLAGS := $(shell $(PKG_CONFIG) --cflags libdrm)
DRM_LIBS := $(shell $(PKG_CONFIG) --libs libdrm)

SRC := pcie_hdmi_out_drm_sync.c
TARGET := pcie_hdmi_out_drm
COMPAT_TARGET := pcie_hdmi_out_drm_sync

all: $(TARGET) $(COMPAT_TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) $(DRM_CFLAGS) -o $@ $< $(DRM_LIBS)

$(COMPAT_TARGET): $(SRC)
	$(CC) $(CFLAGS) $(DRM_CFLAGS) -o $@ $< $(DRM_LIBS)

clean:
	rm -f $(TARGET) $(COMPAT_TARGET)

.PHONY: all clean
