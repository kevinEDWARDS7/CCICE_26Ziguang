# PDS integration entry for the single-channel HDMI -> PCIe bridge.
# This script does not regenerate vendor IP. It assumes validated DDR and PCIe IP
# already exist and are imported separately in PDS.

set root_dir [file normalize [file dirname [info script]]/..]
set rtl_dir  [file join $root_dir rtl]
set imp_dir  [file join $root_dir .. imported]

puts "root_dir = $root_dir"

add_design [file join $rtl_dir traffic_hdmi_pcie_top.v]
add_design [file join $rtl_dir hdmi_frame_packetizer.v]
add_design [file join $rtl_dir stream_width_adapter_32to128.v]

add_include_path $rtl_dir

puts "Import the following copied reference directories in PDS if they are needed:"
puts "  $imp_dir/hdmi_video"
puts "  $imp_dir/frame_ddr3"
puts "  $imp_dir/pcie_dma"

puts "Top module suggestion: traffic_hdmi_pcie_top"
puts "Board constraints are not auto-added here because the exact 40PIN-to-HDMI pin map must match your hardware."
