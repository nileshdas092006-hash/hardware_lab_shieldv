# synth_block.tcl - synthesise ONE block on its own and report its size
# Owner: Nilesh (G2), for everyone
#
#   python scripts/fpga.py block munit        (or shieldv, core_pipe, alu, ...)
#
# "Out-of-context" synthesis: the block is synthesised without pins or the
# rest of the SoC, so you see exactly how many LUTs, flip-flops, BRAMs and DSPs
# your module costs, and whether Vivado inferred any latches.
# Output: build/fpga/blocks/<top>_utilization.rpt and <top>_timing.rpt

set top [lindex $argv 0]
if {$top eq ""} { error "usage: -tclargs <module name>" }
set root [file normalize [file join [file dirname [info script]] .. .. ..]]
set out  [file join $root build fpga blocks]
file mkdir $out
set_part xc7a100tcsg324-1

foreach f [glob [file join $root G* * rtl *.v]] {
    if {[file tail $f] ni {core_single.v munit_stub.v shieldv_stub.v}} { read_verilog $f }
}
synth_design -top $top -mode out_of_context
create_clock -name clk -period 20.000 [get_ports -quiet clk]
report_utilization -file [file join $out ${top}_utilization.rpt]
report_timing_summary -file [file join $out ${top}_timing.rpt]

set latches [llength [get_cells -quiet -hierarchical -filter {PRIMITIVE_TYPE =~ REGISTER.LATCH.*}]]
puts "=========================================================="
puts " $top: [llength [get_cells -hierarchical -filter {PRIMITIVE_GROUP == LUT}]] LUT cells,\
 [llength [get_cells -hierarchical -filter {PRIMITIVE_GROUP == FLOP_LATCH}]] flip-flops/latches,\
 $latches latches"
puts " report: $out/${top}_utilization.rpt"
puts "=========================================================="
