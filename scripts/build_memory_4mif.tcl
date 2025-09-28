# Quartus II 8.0 Build Script - 4-MIF Memory Controller Test
# Comprehensive validation of 4-symbol MIF memory controller

if { [info exists ::quartus(version)] } {
    puts "Quartus Version: $::quartus(version)"
}

load_package flow

# Create project if it doesn't exist
if {![project_exists memory_4mif]} {
    project_new memory_4mif
} else {
    project_open memory_4mif
}

# Device settings for DE-2 board
set_global_assignment -name FAMILY "Cyclone II"
set_global_assignment -name DEVICE EP2C35F672C6
set_global_assignment -name TOP_LEVEL_ENTITY memory_test_4mif

# Enable parallel compilation
set_global_assignment -name NUM_PARALLEL_PROCESSORS ALL

# VHDL source files
set_global_assignment -name VHDL_FILE rtl/memory_test_4mif.vhd
set_global_assignment -name VHDL_FILE rtl/hex_display.vhd
set_global_assignment -name VHDL_FILE rtl/lcd_controller.vhd

# Verilog source files
set_global_assignment -name VERILOG_FILE rtl/mem_controller_4mif.v

# 4-Symbol Memory initialization files
if {[file exists firmware_symbol_0.mif]} {
    set_global_assignment -name MIF_FILE firmware_symbol_0.mif
    puts "Added firmware_symbol_0.mif"
} else {
    puts "Warning: firmware_symbol_0.mif not found - will use zero initialization"
}

if {[file exists firmware_symbol_1.mif]} {
    set_global_assignment -name MIF_FILE firmware_symbol_1.mif
    puts "Added firmware_symbol_1.mif"
} else {
    puts "Warning: firmware_symbol_1.mif not found - will use zero initialization"
}

if {[file exists firmware_symbol_2.mif]} {
    set_global_assignment -name MIF_FILE firmware_symbol_2.mif
    puts "Added firmware_symbol_2.mif"
} else {
    puts "Warning: firmware_symbol_2.mif not found - will use zero initialization"
}

if {[file exists firmware_symbol_3.mif]} {
    set_global_assignment -name MIF_FILE firmware_symbol_3.mif
    puts "Added firmware_symbol_3.mif"
} else {
    puts "Warning: firmware_symbol_3.mif not found - will use zero initialization"
}

# Pin assignments for DE-2 board
# Clock and reset
set_location_assignment PIN_N2 -to CLOCK_50
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to CLOCK_50
set_location_assignment PIN_G26 -to KEY[0]
set_location_assignment PIN_N23 -to KEY[1]
set_location_assignment PIN_P23 -to KEY[2]
set_location_assignment PIN_W26 -to KEY[3]

# Switches
set_location_assignment PIN_N25 -to SW[0]
set_location_assignment PIN_N26 -to SW[1]
set_location_assignment PIN_P25 -to SW[2]
set_location_assignment PIN_AE14 -to SW[3]
set_location_assignment PIN_AF14 -to SW[4]
set_location_assignment PIN_AD13 -to SW[5]
set_location_assignment PIN_AC13 -to SW[6]
set_location_assignment PIN_C13 -to SW[7]
set_location_assignment PIN_B13 -to SW[8]
set_location_assignment PIN_A13 -to SW[9]
set_location_assignment PIN_N1 -to SW[10]
set_location_assignment PIN_P1 -to SW[11]
set_location_assignment PIN_P2 -to SW[12]
set_location_assignment PIN_T7 -to SW[13]
set_location_assignment PIN_U3 -to SW[14]
set_location_assignment PIN_U4 -to SW[15]
set_location_assignment PIN_V1 -to SW[16]
set_location_assignment PIN_V2 -to SW[17]

# Switch IO standards
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[2]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[3]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[4]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[5]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[6]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[7]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[8]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[9]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[10]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[11]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[12]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[13]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[14]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[15]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[16]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[17]

# LEDs
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

# 7-segment displays
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

set_location_assignment PIN_U9 -to HEX4[0]
set_location_assignment PIN_U1 -to HEX4[1]
set_location_assignment PIN_U2 -to HEX4[2]
set_location_assignment PIN_T4 -to HEX4[3]
set_location_assignment PIN_R7 -to HEX4[4]
set_location_assignment PIN_R6 -to HEX4[5]
set_location_assignment PIN_T3 -to HEX4[6]

set_location_assignment PIN_T2 -to HEX5[0]
set_location_assignment PIN_P6 -to HEX5[1]
set_location_assignment PIN_P7 -to HEX5[2]
set_location_assignment PIN_T9 -to HEX5[3]
set_location_assignment PIN_R5 -to HEX5[4]
set_location_assignment PIN_R4 -to HEX5[5]
set_location_assignment PIN_R3 -to HEX5[6]

set_location_assignment PIN_R2 -to HEX6[0]
set_location_assignment PIN_P4 -to HEX6[1]
set_location_assignment PIN_P3 -to HEX6[2]
set_location_assignment PIN_M2 -to HEX6[3]
set_location_assignment PIN_M3 -to HEX6[4]
set_location_assignment PIN_M5 -to HEX6[5]
set_location_assignment PIN_M4 -to HEX6[6]

set_location_assignment PIN_L3 -to HEX7[0]
set_location_assignment PIN_L2 -to HEX7[1]
set_location_assignment PIN_L9 -to HEX7[2]
set_location_assignment PIN_L6 -to HEX7[3]
set_location_assignment PIN_L7 -to HEX7[4]
set_location_assignment PIN_P9 -to HEX7[5]
set_location_assignment PIN_N9 -to HEX7[6]

# LCD Interface Pin Assignments - same as working example
set_location_assignment PIN_J1 -to LCD_DATA[0]
set_location_assignment PIN_J2 -to LCD_DATA[1]
set_location_assignment PIN_H1 -to LCD_DATA[2]
set_location_assignment PIN_H2 -to LCD_DATA[3]
set_location_assignment PIN_J4 -to LCD_DATA[4]
set_location_assignment PIN_J3 -to LCD_DATA[5]
set_location_assignment PIN_H4 -to LCD_DATA[6]
set_location_assignment PIN_H3 -to LCD_DATA[7]
set_location_assignment PIN_K4 -to LCD_RW
set_location_assignment PIN_K3 -to LCD_EN
set_location_assignment PIN_K1 -to LCD_RS
set_location_assignment PIN_L4 -to LCD_ON
set_location_assignment PIN_K2 -to LCD_BLON
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LCD_DATA[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LCD_DATA[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LCD_DATA[2]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LCD_DATA[3]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LCD_DATA[4]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LCD_DATA[5]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LCD_DATA[6]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LCD_DATA[7]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LCD_RW
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LCD_EN
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LCD_RS
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LCD_ON
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LCD_BLON

# Try to compile
puts "Starting 4-MIF Memory Controller Test compilation..."
if {[catch {execute_flow -compile} result]} {
    puts "Compilation failed: $result"
    project_close
    exit 1
} else {
    puts "4-MIF Memory Controller Test compilation successful!"
    project_close
}