# Constraints

No concrete `.fdc` or pin constraint file is generated yet.

Reason:

- The exact 40PIN-to-HDMI module pin map is board-specific.
- The copied historical projects include multiple boards and multi-input variants.
- Reusing the wrong pinout here would be more damaging than leaving this explicit.

Use this directory to place:

- Clock constraints for `sys_clk` and `hdmi_pix_clk`
- Reset constraints
- HDMI input pin bindings
- PCIe reference clock and lane bindings
- DDR3 pin constraints from the validated base project
