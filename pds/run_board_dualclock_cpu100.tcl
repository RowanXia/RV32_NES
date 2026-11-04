# Modified for RV32 NES integration, 2026-11-01. See License/ for project notices.
# Experimental fixed dual-clock build: 100 MHz CPU/cache/local-main island and
# the unchanged 42.8786 MHz NES/matrix/peripheral island.  This uses the real
# 100 MHz PLL ratios selected by CFG_CPU_100MHZ; it is not an over-constrained
# 80 MHz PLL build.
set SYN_TOP RV32_NES
set root [file normalize [file join [file dirname [info script]] ..]]
if {[info exists ::env(RV32_SOURCE_ROOT)]} {set root $::env(RV32_SOURCE_ROOT)}
set pdsdir [file join $root pds]
set build [file normalize $::env(RV32_PDS_BUILD_DIR)]
file mkdir $build
set init_dst [file join $build software board_app init]
file mkdir $init_dst
foreach init_file [glob -nocomplain [file join $root software board_app init bank*.mem]] {
  file copy -force $init_file $init_dst
}
create_project [file join $build board_dualclock_cpu100.pds] -project_type rtl -force -syn_tool ads -in_process

set fh [open [file join $root filelist rtl.f] r]
set lines [split [read $fh] "\n"]
close $fh
foreach line $lines {
  set rel [string trim $line]
  if {$rel eq "" || [string match "#*" $rel]} {continue}
  add_design [file join $root $rel]
}

set fh [open [file join $root filelist include_dirs.f] r]
set inc_lines [split [read $fh] "\n"]
close $fh
set inc {}
foreach line $inc_lines {
  set entry [string trim $line]
  if {[string match "+incdir+*" $entry]} {
    lappend inc [file join $root [string range $entry 8 end]]
  }
}

set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG676
set_option max_threads 0
add_constraint [file join $pdsdir board_compat.fdc]
compile -top_module $SYN_TOP -verilog_standard SystemVerilog -compiler_directives {SYNTHESIS CFG_BOARD_APP_PRIMITIVE_INIT CFG_CPU_100MHZ CFG_ILA_PROBES} -include_path $inc
synthesize -ads -selected_syn_tool_opt 2
launch_tasks [get_tasks {pnr_1}] -to_action dev_map
wait_on_tasks [get_tasks {pnr_1}] -to_action dev_map
launch_tasks [get_tasks {pnr_1}] -to_action place
wait_on_tasks [get_tasks {pnr_1}] -to_action place
launch_tasks [get_tasks {pnr_1}] -to_action route
wait_on_tasks [get_tasks {pnr_1}] -to_action route
launch_tasks [get_tasks {pnr_1}] -to_action route_optimize
wait_on_tasks [get_tasks {pnr_1}] -to_action route_optimize
launch_tasks [get_tasks {pnr_1}] -to_action report_timing
wait_on_tasks [get_tasks {pnr_1}] -to_action report_timing
launch_tasks [get_tasks {pnr_1}] -to_action gen_bit_stream
wait_on_tasks [get_tasks {pnr_1}] -to_action gen_bit_stream
puts "RV32_DUALCLOCK_CPU100_BITSTREAM_FINISHED"
