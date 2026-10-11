# program.tcl - load the bitstream onto the board over USB (make program)
# Owner: Nilesh (G2)
#
# Connect the Nexys A7 with its USB cable and switch it on first.
# The design is lost when the power goes off; just run this again.

set top [lindex $argv 0]
if {$top eq ""} { set top fpga_top }
set root [file normalize [file join [file dirname [info script]] .. .. ..]]
set bit  [file join $root build fpga $top ${top}.bit]

open_hw_manager
connect_hw_server
open_hw_target
set dev [lindex [get_hw_devices xc7a100t*] 0]
current_hw_device $dev
set_property PROGRAM.FILE $bit $dev
set ltx [file join $root build fpga $top debug_probes.ltx]
if {[file exists $ltx]} { set_property PROBES.FILE $ltx $dev }
program_hw_devices $dev
puts "programmed $bit"
close_hw_manager
