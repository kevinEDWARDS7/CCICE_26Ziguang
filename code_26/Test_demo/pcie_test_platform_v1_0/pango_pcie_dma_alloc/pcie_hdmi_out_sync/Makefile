CC ?= gcc
CFLAGS ?= -O2 -Wall -Wextra

TARGET_FB = pcie_hdmi_out
TARGET_DRM = pcie_hdmi_out_drm

all: $(TARGET_FB) $(TARGET_DRM)

$(TARGET_FB): pcie_hdmi_out.c
	$(CC) $(CFLAGS) -o $@ $<

$(TARGET_DRM): pcie_hdmi_out_drm_sync.c
	$(CC) $(CFLAGS) -o $@ $< -ldrm

clean:
	rm -f $(TARGET_FB) $(TARGET_DRM)

.PHONY: all clean

