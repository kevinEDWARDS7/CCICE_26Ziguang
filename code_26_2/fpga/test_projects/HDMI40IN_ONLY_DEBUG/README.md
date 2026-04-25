# HDMI40IN_ONLY_DEBUG

Standalone FPGA-side HDMI input test for the 40PIN HDMI IN daughter card / MS7200 path.

This project intentionally excludes PCIe DMA, RK3568 userspace, DDR frame buffers, RKNN/YOLO, and image processing. Its only purpose is to prove whether MS7200 RGB888 timing reaches the FPGA.

## Source Reference

Reused from `code_26_2/fpga/template_projects/DL_HDMI40IN_PCIE_RK3568`:

- HDMI input ports: `hdmi_pix_clk`, `hdmi_vs`, `hdmi_hs`, `hdmi_de`, `hdmi_r[7:0]`, `hdmi_g[7:0]`, `hdmi_b[7:0]`
- MS7200 init: `source/hdmi/ms7200_ctl.v`
- I2C engine: `source/hdmi/iic_dri.v`
- HDMI40IN constraints: copied from `project/project.fdc`

## Files

- `rtl/hdmi40in_only_debug_top.v`: top module, MS7200 I2C init and debug connection
- `rtl/hdmi_in_debug.v`: HDMI timing/data diagnostic counters and LED flags
- `rtl/ms7200_ctl.v`: copied MS7200 register sequence
- `rtl/iic_dri.v`: copied I2C controller
- `constraints/hdmi40in_only_debug.fdc`: sys_clk, HDMI40IN, I2C, and known LED constraints
- `scripts/impl.tcl`: PDS batch flow

## Build

Open this directory in PDS or run the script from a PDS Tcl shell:

```tcl
source scripts/impl.tcl
```

Top module:

```text
hdmi40in_only_debug_top
```

Target device copied from the reference project:

```text
Logos2 PG2L100H -6 FBG484
```

## HDMI Input Connection

Connect the HDMI source to the 40PIN HDMI IN daughter card. The source should output a normal RGB/HDMI mode such as 1280x720 or 1920x1080. Do not run `pango_pcie_drm_c`; this test does not use PCIe DMA or RK display.

MS7200 init completion is exposed as `hdmi_rx_init_done`. Add it to PDS online logic analyzer if the HDMI path is silent.

## LED Meaning

The diagnostic module outputs:

- `led_pclk_alive`: divided `hdmi_pix_clk`; blinking means pixel clock is present.
- `led_vsync_alive`: toggles on `hdmi_vs` rising edge; blinking/toggling means frame sync is present.
- `led_de_seen`: latches high after any `hdmi_de=1`.
- `led_rgb_nonzero`: latches high after any nonzero RGB pixel while `hdmi_de=1`.

Known LED constraints from the existing project only identify two output pins:

- `led_pclk_alive`: `M17`
- `led_vsync_alive`: `J16`

Missing physical LED constraints that must be confirmed from the board schematic before assigning:

- `led_de_seen`
- `led_rgb_nonzero`

These two signals are still top-level outputs and can be captured by PDS even before LED pin assignment.

## PDS Signals To Capture

Capture these top-level outputs or the matching nets inside `u_hdmi_in_debug`:

```text
hdmi_rx_init_done
hdmi_pix_clk
hdmi_vs
hdmi_hs
hdmi_de
hdmi_r[7:0]
hdmi_g[7:0]
hdmi_b[7:0]
frame_count
hsync_count
de_pixel_count_current_line
max_de_pixels_per_line
de_lines_per_frame
rgb_nonzero_count
led_de_seen
led_rgb_nonzero
```

## Expected Results

For 1280x720 input:

```text
max_de_pixels_per_line ~= 1280
de_lines_per_frame ~= 720
led_pclk_alive toggles
led_vsync_alive toggles
led_de_seen = 1
led_rgb_nonzero = 1 for non-black video
```

For 1920x1080 input:

```text
max_de_pixels_per_line ~= 1920
de_lines_per_frame ~= 1080
```

If the HDMI source is unplugged:

```text
led_vsync_alive should stop normal toggling
de_lines_per_frame should not keep reporting a valid active-video line count
frame_count should stop or become abnormal
```

## Constraint Notes

The copied reference constraint says V1.1 daughter card uses:

```text
hdmi_pix_clk = W19
hdmi_b[1]    = W20
```

It also states V1.0 swaps these two pins. If the board has a V1.0 HDMI40IN daughter card, edit `constraints/hdmi40in_only_debug.fdc` accordingly before implementation.
