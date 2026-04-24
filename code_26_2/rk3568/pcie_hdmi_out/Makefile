CC ?= gcc
CFLAGS ?= -O2 -Wall -Wextra -Iinclude
LDFLAGS ?=
LDLIBS ?= -ldrm

TARGET := pcie_hdmi_out_drm_sync
SRC := src/main.c

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $@ $(SRC) $(LDFLAGS) $(LDLIBS)

clean:
	$(RM) $(TARGET)

.PHONY: all clean
