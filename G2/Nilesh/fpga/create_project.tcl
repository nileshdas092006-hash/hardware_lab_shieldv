# create_project.tcl - make a normal Vivado project you can open and click through
# Owner: Nilesh (G2)
#
#   python scripts/fpga.py project attack        in-order core
#   python scripts/fpga.py project attack --ooo  out-of-order core
#   (builds the program, runs this, opens Vivado)
#
# Creates build/vivado_project/shieldv.xpr (build/vivado_project_ooo/shieldv.xpr
# for the out-of-order core; the two never share a folder) with
#   * Design Sources : every RTL file, top = fpga_top, loaded with <prog>'s hex files
#   * Constraints    : nexys_a7.xdc
#   * Simulation     : every testbench; top = soc_tb, set up to run <prog> with
#                      switch SW0 = 1 (protection on) until the program ends
# Then in Vivado: Flow Navigator > Run Simulation, or Generate Bitstream.

set prog [lindex $argv 0]
if {$prog eq ""} { set prog attack }
set ooo [expr {"ooo" in [lrange $argv 1 end]}]

set root [file normalize [file join [file dirname [info script]] .. .. ..]]
set dir  [file join $root build [expr {$ooo ? "vivado_project_ooo" : "vivado_project"}]]
set sw   [file join $root build sw $prog]
foreach h {imem.hex dmem.hex} {
    if {![file exists [file join $sw $h]]} { error "missing $sw/$h: run  python scripts/build_sw.py $prog  first" }
}

create_project shieldv $dir -part xc7a100tcsg324-1 -force

# ---- design sources ----
set rtl {}
foreach f [lsort [glob [file join $root G* * rtl *.v]]] { lappend rtl $f }
add_files -fileset sources_1 $rtl
# the simulation-only models stay out of synthesis
foreach f {core_single.v munit_stub.v shieldv_stub.v} {
    set_property used_in_synthesis false [get_files -of_objects [get_filesets sources_1] *$f]
}
set_property top fpga_top [get_filesets sources_1]
set imem [file join $sw imem.hex]
set dmem [file join $sw dmem.hex]
set_property generic "IMEM_INIT=\"$imem\" DMEM_INIT=\"$dmem\"" [get_filesets sources_1]

# ---- constraints ----
add_files -fileset constrs_1 [file join $root G2 Nilesh fpga nexys_a7.xdc]

# ---- simulation ----
set tbs [lsort [glob [file join $root G* * tb *_tb.v]]]
add_files -fileset sim_1 $tbs
set_property top soc_tb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]
# hacked= lets soc_tb report RESULT: HIJACKED when the attacker's code really runs
set hacked ""
set symfile [open [file join $sw symbols.txt]]
foreach line [split [read $symfile] "\n"] {
    if {[lindex $line 1] eq "hacked"} { set hacked " -testplusarg hacked=[lindex $line 0]" }
}
close $symfile
set_property -name {xsim.simulate.xsim.more_options} \
    -value "-testplusarg imem=$imem -testplusarg dmem=$dmem${hacked} -testplusarg sw=1" \
    -objects [get_filesets sim_1]

# ---- which core: soc_top picks core_ooo when SHIELDV_OOO is defined ----
if {$ooo} {
    set_property verilog_define SHIELDV_OOO [get_filesets sources_1]
    set_property verilog_define SHIELDV_OOO [get_filesets sim_1]
}

puts "=========================================================="
puts " project : $dir/shieldv.xpr"
puts " core    : [expr {$ooo ? "out-of-order" : "in-order"}]"
puts " program : $prog (simulation and bitstream)"
puts "=========================================================="
