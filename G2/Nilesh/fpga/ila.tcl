# ila.tcl - add a Vivado ILA (on-chip logic analyzer) to the synthesized design
# Owner: Nilesh (G2)
#
# Sourced by build.tcl after synthesis when called with the "ila" argument.
# It records every net marked (* mark_debug = "true" *) in fpga_top.v (the
# trace port: stage PCs, stall, flush, ex_valid, retire, and the alarm) for
# 1024 cycles. In the Vivado Hardware Manager, set the trigger to
# LED17_R (alarm) rising, run the attack, and you get the cycle-exact
# picture of the attack being caught on the real board (timing Scenario 2).

set nets [get_nets -hierarchical -filter {MARK_DEBUG == 1}]
if {[llength $nets] == 0} { error "no nets are marked for debug" }

create_debug_core u_ila_0 ila
set_property C_DATA_DEPTH          1024  [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN           false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES   0     [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets -of_objects [get_pins u_clk/u_bufg_clk/O]]

set_property port_width [llength $nets] [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 $nets
puts "ILA: [llength $nets] probe bits connected"
