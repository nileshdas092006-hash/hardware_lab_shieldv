# build.tcl - one-command Vivado build (block B11)
# Owner: Nilesh (G2)
#
#   make fpga PROG=attack                         (from the repo root)
#   vivado -mode batch -source G2/Nilesh/fpga/build.tcl -tclargs fpga_top attack
#
# Arguments: <top> (fpga_top or exerciser_top) and <prog> (a program already
# compiled by scripts/build_sw.py; its imem.hex/dmem.hex become the initial
# contents of the block RAMs). Then any of these options:
#   ila       insert the Integrated Logic Analyzer on the (* mark_debug *) signals
#   ooo       build the SoC with the out-of-order core (define SHIELDV_OOO)
#   noshield  replace ShieldV by shieldv_stub.v, to measure what ShieldV costs
#
# Output in build/fpga/<top>[_ooo][_noshield][_<prog, unless attack>]/:
#   <top>.bit              the bitstream to load onto the board
#   utilization.rpt        LUTs, flip-flops, BRAM, DSP for the whole design
#   utilization_hier.rpt   the same, per module (ShieldV's own LUT count)
#   timing.rpt             worst negative slack must be >= 0
#   build_info.txt         which core and program this bitstream holds
#   debug_probes.ltx       only with "ila"

set top  [lindex $argv 0]
set prog [lindex $argv 1]
set opts [lrange $argv 2 end]
set ila      [expr {"ila" in $opts}]
set ooo      [expr {"ooo" in $opts}]
set noshield [expr {"noshield" in $opts}]
if {$top eq ""}  { set top fpga_top }
if {$prog eq ""} { set prog fib }

set root [file normalize [file join [file dirname [info script]] .. .. ..]]
set tag  $top
if {$ooo}      { append tag _ooo }
if {$noshield} { append tag _noshield }
# attack keeps the plain name; any other program gets its own folder
if {$top eq "fpga_top" && $prog ne "attack"} { append tag _$prog }
set out  [file join $root build fpga $tag]
file mkdir $out
set_part xc7a100tcsg324-1

# ---- sources ----
set skip {core_single.v munit_stub.v shieldv_stub.v}
if {$noshield} { set skip {core_single.v munit_stub.v} }
foreach f [glob [file join $root G* * rtl *.v]] {
    # simulation-only models are not needed on the FPGA
    if {[file tail $f] ni $skip} { read_verilog $f }
}
read_xdc [file join $root G2 Nilesh fpga nexys_a7.xdc]

# ---- program images: $readmemh("imem.hex") is resolved from the run directory ----
if {$top eq "fpga_top"} {
    set sw [file join $root build sw $prog]
    foreach h {imem.hex dmem.hex} {
        if {![file exists [file join $sw $h]]} { error "missing $sw/$h: run  python scripts/build_sw.py $prog  first" }
        file copy -force [file join $sw $h] [file join $out $h]
    }
}
cd $out

# ---- synthesis and implementation ----
set synth_args [list -top $top -flatten_hierarchy rebuilt]
if {$ooo}      { lappend synth_args -verilog_define SHIELDV_OOO }
if {$noshield} { lappend synth_args -generic USE_SHIELD_STUB=1 }
synth_design {*}$synth_args
if {$ila} { source [file join $root G2 Nilesh fpga ila.tcl] }
opt_design
place_design
phys_opt_design
route_design

# ---- reports ----
report_utilization -file utilization.rpt
report_utilization -hierarchical -hierarchical_depth 4 -file utilization_hier.rpt
report_timing_summary -max_paths 10 -file timing.rpt
report_drc -file drc.rpt
write_bitstream -force ${top}.bit
if {$ila} { write_debug_probes -force debug_probes.ltx }

set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]

# what is in this bitstream, read back by:  python scripts/fpga.py list
set info [open build_info.txt w]
puts $info "core [expr {$ooo ? {out-of-order} : {in-order}}]"
puts $info "shieldv [expr {$noshield ? {no} : {yes}}]"
puts $info "program $prog"
puts $info "wns_ns $wns"
close $info

puts "=========================================================="
puts " bitstream : $out/${top}.bit   (program: $prog, options: $opts)"
puts " worst negative slack (WNS): $wns ns  [expr {$wns >= 0 ? {timing MET} : {timing FAILED}}]"
puts " reports   : $out/utilization*.rpt, timing.rpt"
puts "=========================================================="
