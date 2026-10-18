# ---- clock: the REAL board clock (PYNQ-Z2 sysclk = 125 MHz). The 100 MHz fabric
# ---- clock is derived automatically from the MMCM; no create_clock needed for it.
create_clock -period 8.000 -name sys_clk [get_ports clk]
set_property PACKAGE_PIN H16 [get_ports clk]

# ---- buttons / LEDs are asynchronous to the design: no I/O delay constraints,
# ---- cut them from timing instead (rst/en are synchronised inside top_board).
set_false_path -from [get_ports {rst en}]
set_false_path -to   [get_ports {digit[*] done fc_done}]

set_property IOSTANDARD LVCMOS33 [get_ports {clk done en rst fc_done digit[*]}]

#set_property PACKAGE_PIN D19 [get_ports en]
#set_property PACKAGE_PIN D20 [get_ports rst]

set_property PACKAGE_PIN M20 [get_ports en]
set_property PACKAGE_PIN M19 [get_ports rst]
set_property PACKAGE_PIN M14 [get_ports {digit[3]}]
set_property PACKAGE_PIN N16 [get_ports {digit[2]}]
set_property PACKAGE_PIN P14 [get_ports {digit[1]}]
set_property PACKAGE_PIN R14 [get_ports {digit[0]}]

set_property PACKAGE_PIN L15 [get_ports fc_done]
set_property PACKAGE_PIN G14 [get_ports done]
