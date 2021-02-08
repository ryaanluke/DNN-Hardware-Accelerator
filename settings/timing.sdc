create_clock -name "CLOCK_50" -period 20ns [get_ports {CLOCK_50}]

derive_pll_clocks -create_base_clocks
derive_clock_uncertainty

set_false_path -from [get_ports KEY*] -to *
set_false_path -from [get_ports SW*] -to *
set_false_path -from * -to [get_ports LED*]
set_false_path -from * -to [get_ports HEX*]
