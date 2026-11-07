# program.tcl - load the bitstream onto the board over USB (make program)
# Owner: Nilesh (G2)
#
# Connect the Nexys A7 with its USB cable and switch it on first.
# The design is lost when the power goes off; just run this again.
#
# Arguments: <top> and <tag>, the build folder name build.tcl used. The tag is
# what picks the core: fpga_top = in-order, fpga_top_ooo = out-of-order.
# scripts/fpga.py works it out from --ooo / --no-shield.

set top [lindex $argv 0]
set tag [lindex $argv 1]
if {$top eq ""} { set top fpga_top }
if {$tag eq ""} { set tag $top }
set root [file normalize [file join [file dirname [info script]] .. .. ..]]
set bit  [file join $root build fpga $tag ${top}.bit]
if {![file exists $bit]} { error "missing $bit: build it first with scripts/fpga.py build" }

open_hw_manager
connect_hw_server
open_hw_target
set dev [lindex [get_hw_devices xc7a100t*] 0]
current_hw_device $dev
set_property PROGRAM.FILE $bit $dev
set ltx [file join $root build fpga $tag debug_probes.ltx]
if {[file exists $ltx]} { set_property PROBES.FILE $ltx $dev }
program_hw_devices $dev
puts "programmed $bit"
close_hw_manager
