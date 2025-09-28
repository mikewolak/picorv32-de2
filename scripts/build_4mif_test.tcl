# Quartus II 8.0 Build Script - 4-MIF Memory Controller Test
# Tests new 4-symbol MIF memory controller with RISC-V Knight Rider

if { [info exists ::quartus(version)] } {
    puts "Quartus Version: $::quartus(version)"
}

load_package flow

# Create project if it doesn't exist
if {![project_exists test_4mif_riscv]} {
    project_new test_4mif_riscv
} else {
    project_open test_4mif_riscv
}

# Device settings for DE-2 board
set_global_assignment -name FAMILY "Cyclone II"
set_global_assignment -name DEVICE EP2C35F672C6
set_global_assignment -name TOP_LEVEL_ENTITY test_4mif_riscv

# Enable parallel compilation
set_global_assignment -name NUM_PARALLEL_PROCESSORS ALL

# VHDL source files
set_global_assignment -name VHDL_FILE rtl/test_4mif_riscv.vhd
set_global_assignment -name VHDL_FILE rtl/hex_display.vhd

# Verilog source files
set_global_assignment -name VERILOG_FILE rtl/mem_controller_4mif.v
set_global_assignment -name VERILOG_FILE rtl/picorv32.v

# 4-Symbol Memory initialization files
if {[file exists build/quartus/firmware_symbol_0.mif]} {
    set_global_assignment -name MIF_FILE build/quartus/firmware_symbol_0.mif
    puts "Added firmware_symbol_0.mif"
} else {
    puts "Warning: firmware_symbol_0.mif not found - build firmware first"
}

if {[file exists build/quartus/firmware_symbol_1.mif]} {
    set_global_assignment -name MIF_FILE build/quartus/firmware_symbol_1.mif
    puts "Added firmware_symbol_1.mif"
} else {
    puts "Warning: firmware_symbol_1.mif not found - build firmware first"
}

if {[file exists build/quartus/firmware_symbol_2.mif]} {
    set_global_assignment -name MIF_FILE build/quartus/firmware_symbol_2.mif
    puts "Added firmware_symbol_2.mif"
} else {
    puts "Warning: firmware_symbol_2.mif not found - build firmware first"
}

if {[file exists build/quartus/firmware_symbol_3.mif]} {
    set_global_assignment -name MIF_FILE build/quartus/firmware_symbol_3.mif
    puts "Added firmware_symbol_3.mif"
} else {
    puts "Warning: firmware_symbol_3.mif not found - build firmware first"
}

# Pin assignments for DE-2 board
# Clock and reset
set_location_assignment PIN_N2 -to CLOCK_50
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to CLOCK_50
set_location_assignment PIN_G26 -to KEY[0]
set_location_assignment PIN_N23 -to KEY[1]

# LEDs for Knight Rider pattern
set_location_assignment PIN_AE23 -to LEDR[0]
set_location_assignment PIN_AF23 -to LEDR[1]
set_location_assignment PIN_AB21 -to LEDR[2]
set_location_assignment PIN_AC22 -to LEDR[3]
set_location_assignment PIN_AD22 -to LEDR[4]
set_location_assignment PIN_AD23 -to LEDR[5]
set_location_assignment PIN_AD21 -to LEDR[6]
set_location_assignment PIN_AC21 -to LEDR[7]
set_location_assignment PIN_AA14 -to LEDR[8]
set_location_assignment PIN_Y13 -to LEDR[9]
set_location_assignment PIN_AA13 -to LEDR[10]
set_location_assignment PIN_AC14 -to LEDR[11]
set_location_assignment PIN_AD15 -to LEDR[12]
set_location_assignment PIN_AE15 -to LEDR[13]
set_location_assignment PIN_AF13 -to LEDR[14]
set_location_assignment PIN_AE13 -to LEDR[15]
set_location_assignment PIN_AE12 -to LEDR[16]
set_location_assignment PIN_AD12 -to LEDR[17]

# 7-segment displays for PC debugging
set_location_assignment PIN_AF10 -to HEX0[0]
set_location_assignment PIN_AB12 -to HEX0[1]
set_location_assignment PIN_AC12 -to HEX0[2]
set_location_assignment PIN_AD11 -to HEX0[3]
set_location_assignment PIN_AE11 -to HEX0[4]
set_location_assignment PIN_V14 -to HEX0[5]
set_location_assignment PIN_V13 -to HEX0[6]

set_location_assignment PIN_V20 -to HEX1[0]
set_location_assignment PIN_V21 -to HEX1[1]
set_location_assignment PIN_W21 -to HEX1[2]
set_location_assignment PIN_Y22 -to HEX1[3]
set_location_assignment PIN_AA24 -to HEX1[4]
set_location_assignment PIN_AA23 -to HEX1[5]
set_location_assignment PIN_AB24 -to HEX1[6]

set_location_assignment PIN_AB23 -to HEX2[0]
set_location_assignment PIN_V22 -to HEX2[1]
set_location_assignment PIN_AC25 -to HEX2[2]
set_location_assignment PIN_AC26 -to HEX2[3]
set_location_assignment PIN_AB26 -to HEX2[4]
set_location_assignment PIN_AB25 -to HEX2[5]
set_location_assignment PIN_Y24 -to HEX2[6]

set_location_assignment PIN_Y23 -to HEX3[0]
set_location_assignment PIN_AA25 -to HEX3[1]
set_location_assignment PIN_AA26 -to HEX3[2]
set_location_assignment PIN_Y26 -to HEX3[3]
set_location_assignment PIN_Y25 -to HEX3[4]
set_location_assignment PIN_U22 -to HEX3[5]
set_location_assignment PIN_W24 -to HEX3[6]

# Try to compile
puts "Starting 4-MIF RISC-V test compilation..."
if {[catch {execute_flow -compile} result]} {
    puts "Compilation failed: $result"
    project_close
    exit 1
} else {
    puts "4-MIF RISC-V compilation successful!"
    project_close
}