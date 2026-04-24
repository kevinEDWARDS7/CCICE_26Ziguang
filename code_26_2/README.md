# code_26_2

This directory is the only writable integration workspace for the current stage.

Current target:

`HDMI IN -> FPGA -> PCIe -> RK3568 -> HDMI OUT`

Current principle:

- Reuse official demos first.
- Reuse prior project code second.
- Add only the minimum glue code needed for the single-channel pipeline.
- Do not modify `code_25` or `code_26`.

## Directory layout

- `docs/`
  - Read-only inventory and integration notes.
- `fpga/imported/`
  - Snapshot copies of reusable FPGA reference code.
- `fpga/hdmi_pcie_bridge/`
  - New single-channel FPGA integration layer and build script.
- `rk3568/pcie_hdmi_out/`
  - RK3568 user-space PCIe receive + DRM HDMI out app.

## Reused source baseline

- HDMI input and video timing:
  - `code_25/four_pinjie_video/four_pinjie_video/HDMI_DDR3_OV5640/source`
- DDR frame buffer:
  - `code_25/dl/dl/source/frame_ddr3`
- PCIe DMA controller:
  - `code_26/Test_demo/pcie_test_platform_v1_0/pango_pcie_dma_alloc/pcie_test_rtl/PG2L100H_PCIe_DMA/ipcore/pcie/example_design/rtl/pcie_dma_ctrl`
- RK3568 HDMI out demo:
  - `code_26/Test_demo/RK/pcie_test_platform_v1_0/pango_pcie_dma_alloc/pcie_hdmi_out_sync/pcie_hdmi_out_drm_sync.c`

## What is generated here

This workspace currently contains an initial integration baseline, not a fully board-closed final bitstream project.

Included:

- A curated local copy of reusable RTL and RK code.
- A new FPGA packet format definition and packetizer.
- A 32-bit to 128-bit stream combiner for PCIe-side adaptation.
- A new top-level integration shell for the single HDMI-to-PCIe path.
- A local RK3568 buildable DRM application wrapper.

Not included yet:

- Final board pin constraints for your exact 40PIN-to-HDMI hardware.
- Final PDS IP re-generation.
- Verified end-to-end timing closure.
- Final kernel driver changes.

## Immediate next use

1. Use `docs/reference_inventory.md` to identify which copied modules stay in the mainline.
2. Use `fpga/hdmi_pcie_bridge/rtl/traffic_hdmi_pcie_top.v` as the new FPGA integration entry.
3. Use `rk3568/pcie_hdmi_out/Makefile` to build the RK user-space display app.
4. In PDS, import the local RTL plus your existing validated PCIe and DDR IP.
