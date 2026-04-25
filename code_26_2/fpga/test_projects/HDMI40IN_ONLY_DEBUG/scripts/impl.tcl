# PDS batch entry for the standalone HDMI40IN input debug project.
set project_dir [file normalize [file join [file dirname [info script]] ..]]
set rtl_dir     [file join $project_dir rtl]
set constr_dir  [file join $project_dir constraints]

set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG484

add_design [file join $rtl_dir ms7200_ctl.v]
add_design [file join $rtl_dir iic_dri.v]
add_design [file join $rtl_dir hdmi_in_debug.v]
add_design [file join $rtl_dir hdmi40in_only_debug_top.v]
add_constraint [file join $constr_dir hdmi40in_only_debug.fdc]

compile -top_module hdmi40in_only_debug_top
synthesize -ads -selected_syn_tool_opt 2
dev_map
pnr
report_timing
gen_bit_stream
