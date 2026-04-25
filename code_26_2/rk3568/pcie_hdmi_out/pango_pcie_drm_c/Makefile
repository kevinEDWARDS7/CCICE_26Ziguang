CC ?= gcc
PKG_CONFIG ?= pkg-config

CFLAGS ?= -O2 -Wall -Wextra -std=c11
CPPFLAGS += -Iinclude
LDFLAGS ?=

DRM_CFLAGS := $(shell $(PKG_CONFIG) --cflags libdrm 2>/dev/null)
DRM_LIBS := $(shell $(PKG_CONFIG) --libs libdrm 2>/dev/null)

CPPFLAGS += $(DRM_CFLAGS)
LDLIBS += $(if $(DRM_LIBS),$(DRM_LIBS),-ldrm)

TARGETS := pcie_probe_only pango_pcie_drm_c

all: $(TARGETS)

pcie_probe_only: src/pcie_probe_only.c include/pango_pcie_abi.h
	$(CC) $(CFLAGS) $(CPPFLAGS) -o $@ src/pcie_probe_only.c $(LDFLAGS)

pango_pcie_drm_c: src/main.c include/pango_pcie_abi.h
	$(CC) $(CFLAGS) $(CPPFLAGS) -o $@ src/main.c $(LDFLAGS) $(LDLIBS)

clean:
	$(RM) $(TARGETS)

.PHONY: all clean
