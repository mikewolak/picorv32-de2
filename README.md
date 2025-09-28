# PicoRV32 DE-2 FPGA Implementation

A complete RISC-V soft processor implementation for the Altera DE-2 development board featuring hardware debugging, memory testing, and Knight Rider LED demonstrations.

## Overview

This project implements the PicoRV32 RISC-V core on the Altera Cyclone II FPGA (DE-2 board) with comprehensive debugging infrastructure and memory controller validation. The system demonstrates a fully functional 32-bit RISC-V processor with:

- **Hardware debugging system** with single-step capability
- **4-symbol MIF memory controller** for Block RAM initialization
- **Knight Rider LED pattern** firmware for visual verification
- **Comprehensive memory testing** with write strobe validation
- **LCD display integration** for real-time debugging information

## Features

### 🖥️ **RISC-V Processor Core**
- **PicoRV32** - 32-bit RISC-V RV32I implementation
- **32KB Block RAM** memory using Altera M4K blocks
- **Memory-mapped I/O** for LED control and debugging
- **Custom linker script** for optimal memory layout

### 🔧 **Hardware Debugging System**
- **Real-time PC and cycle display** on 7-segment displays
- **Button-controlled execution** (Run/Halt/Step/Reset)
- **LCD debugging interface** showing memory operations
- **LED status indicators** for system state visualization
- **Switch-controlled debug modes** for comprehensive testing

### 🧪 **Memory Validation Framework**
- **4-symbol MIF controller** supporting all RISC-V memory operations
- **Write strobe testing** for byte/halfword/word operations
- **Memory pattern verification** with comprehensive test suites
- **Real-time memory monitoring** via LCD display

### 💡 **Visual Demonstrations**
- **Knight Rider LED pattern** - 18-LED scanning demonstration
- **Configurable timing** - Adjustable pattern speed for testing
- **Hardware-accelerated** - Direct firmware control of LED arrays

## Hardware Requirements

- **Altera DE-2 Development Board** (EP2C35F672C6)
- **USB-Blaster** JTAG programming cable
- **Power supply** for DE-2 board
- **Optional:** VGA monitor for extended display capabilities

## Software Requirements

- **Quartus II 8.0** (Altera FPGA development tools)
- **RISC-V GCC Cross-Compiler** (rv32i target)
- **MinGW/MSYS2** (Windows build environment)
- **Git** for version control

## Quick Start

### 1. Clone and Build
```bash
git clone https://github.com/mikewolak/picorv32-de2.git
cd picorv32-de2

# Build everything (firmware + FPGA)
make all

# Program FPGA
make program
```

### 2. Hardware Operation
- **Power on** DE-2 board and program FPGA
- **System starts** in HALT mode showing PC=0x0000000C, CY=00000000
- **Press KEY1** to start/stop CPU execution
- **Press KEY2** for single-step debugging (currently has issues)
- **Press KEY3** for system reset
- **Observe** Knight Rider LED pattern on red LEDs

### 3. Debug Information
- **7-Segment Displays** show program counter and cycle count
- **Red LEDs (0-17)** display Knight Rider pattern
- **Green LEDs (0-8)** show debug status indicators
- **LCD Display** shows memory operations and system state

## Project Structure

```
picorv32-de2/
├── README.md                           # This file
├── build.txt                           # Comprehensive build instructions
├── Makefile                            # Automated build system
├── DEBUG_ISSUES_DOCUMENTED.md          # Known issues and solutions
│
├── src/                                # Firmware source code
│   ├── main.c                          # Knight Rider LED firmware
│   ├── start.S                         # RISC-V startup assembly
│   └── linker.ld                       # Memory layout script
│
├── rtl/                                # FPGA RTL source files
│   ├── test_4mif_riscv_debug.vhd       # Main debug system
│   ├── mem_controller_4mif.v           # 4-symbol memory controller
│   ├── memory_test_4mif.vhd            # Memory testing/debugging
│   ├── picorv32.v                      # RISC-V CPU core
│   ├── hex_display.vhd                 # 7-segment controller
│   └── lcd_controller.vhd              # LCD interface
│
├── scripts/                            # Build automation
│   ├── build_riscv_debug.tcl           # Quartus build script
│   └── validate_firmware.sh            # Firmware validation
│
├── tools/                              # Build utilities
│   ├── bin2mif_enhanced.c              # Binary to MIF converter
│   └── bin2mif.c                       # Basic MIF converter
│
└── build/                              # Generated files (git ignored)
    ├── knight_rider.elf                # RISC-V executable
    ├── knight_rider.bin                # Raw binary
    ├── knight_rider.lst                # Assembly listing
    └── quartus/                        # Quartus outputs
        ├── firmware_symbol_*.mif       # Memory initialization
        ├── riscv_4mif_debug.sof        # FPGA configuration
        └── riscv_4mif_debug.pof        # Programming file
```

## Memory Architecture

### Memory Map
```
0x00000000-0x00007FFF : Code and Data (32KB Block RAM)
    0x00000000-0x00001FFF : .text (Code section)
    0x00007000-0x00007BFF : .heap (3KB heap)
    0x00007C00-0x00007FFF : .stack (1KB stack)
    0x00008000-0x00008FFF : .data/.bss sections

0xFFFF0000-0xFFFFFFFF : Memory-mapped I/O
    0xFFFF0060 : LED Control Register (Knight Rider output)
```

### 4-Symbol MIF Controller
The memory controller splits 32-bit words into 4 byte-wide MIF files:
- **firmware_symbol_0.mif** - Byte 0 (LSB) of each word
- **firmware_symbol_1.mif** - Byte 1 of each word
- **firmware_symbol_2.mif** - Byte 2 of each word
- **firmware_symbol_3.mif** - Byte 3 (MSB) of each word

This architecture supports all RISC-V memory operations:
- **LW/SW** - 32-bit word access
- **LH/LHU/SH** - 16-bit halfword access
- **LB/LBU/SB** - 8-bit byte access

## Build System

### Automated Build (Recommended)
```bash
make firmware    # Compile RISC-V firmware
make fpga        # Synthesize FPGA design
make program     # Program FPGA via JTAG
make clean       # Clean build artifacts
```

### Manual Build Process
See [build.txt](build.txt) for complete step-by-step manual build instructions including:
- RISC-V cross-compilation setup
- Binary to MIF conversion
- Quartus synthesis configuration
- FPGA programming procedures

## Debugging Capabilities

### Hardware Debug Interface
- **Execution Control:** Run/Halt/Step via push buttons
- **Program Counter Display:** Real-time PC on 7-segment displays
- **Cycle Counter:** Execution progress monitoring
- **Memory Operations:** Live memory access visualization
- **System State:** LED indicators for debug modes

### Memory Testing Framework
The `memory_test_4mif.vhd` component provides comprehensive memory validation:
- **Write strobe patterns** controlled via switches SW[17:14]
- **All PicoRV32 memory operations** (byte/halfword/word)
- **Real-time result display** on LCD
- **Pattern verification** with known test vectors

### Known Debug Issues
- **Step button (KEY2)** starts continuous execution instead of single-step
- **CPU reset timing** - processor executes 3 instructions before halt
- **Run/halt toggle** requires reset workarounds in some cases

See [DEBUG_ISSUES_DOCUMENTED.md](DEBUG_ISSUES_DOCUMENTED.md) for detailed analysis and workarounds.

## Firmware Examples

### Knight Rider LED Pattern
The default firmware creates a scanning LED pattern across 18 red LEDs:

```c
// LED patterns for Knight Rider effect
static const uint32_t knight_rider_patterns[] = {
    0x00001, 0x00002, 0x00004, 0x00008, 0x00010, 0x00020, 0x00040, 0x00080,
    0x00100, 0x00200, 0x00400, 0x00800, 0x01000, 0x02000, 0x04000, 0x08000,
    0x10000, 0x20000, 0x10000, 0x08000, 0x04000, 0x02000, 0x01000, 0x00800,
    0x00400, 0x00200, 0x00100, 0x00080, 0x00040, 0x00020, 0x00010, 0x00008,
    0x00004, 0x00002
};

// Memory-mapped LED control
volatile uint32_t *led_reg = (volatile uint32_t *)0xFFFF0060;
*led_reg = knight_rider_patterns[pattern_index];
```

### Custom Firmware Development
1. **Edit** `src/main.c` for application logic
2. **Modify** `src/linker.ld` for memory layout changes
3. **Build** with `make firmware`
4. **Test** with hardware debugging system

## Development History

This project evolved from FPGA MIDI sequencer development, focusing on:
1. **Memory controller validation** for reliable Block RAM operations
2. **RISC-V processor integration** with custom peripherals
3. **Hardware debugging infrastructure** for system verification
4. **Comprehensive testing framework** for memory operations

The implementation demonstrates a complete embedded systems development workflow from RTL design through firmware development and hardware validation.

## Performance Characteristics

- **Clock Speed:** 50MHz (DE-2 board crystal)
- **Memory Bandwidth:** 32-bit single-cycle access
- **Code Size:** ~2KB for Knight Rider demo
- **Resource Utilization:** ~15% of EP2C35F672C6 logic elements
- **Boot Time:** <1ms from reset to LED pattern start

## Contributing

This project welcomes contributions in:
- **Debug system improvements** (fixing step functionality)
- **Additional firmware examples**
- **Memory controller optimizations**
- **Extended peripheral support**
- **Documentation enhancements**

## License

This project incorporates the PicoRV32 RISC-V core which is licensed under the ISC license.
Project-specific code and documentation are provided under MIT license.

## References

- **PicoRV32 Core:** https://github.com/cliffordwolf/picorv32
- **RISC-V Specification:** https://riscv.org/specifications/
- **Altera DE-2 User Manual:** DE-2 board documentation
- **Quartus II Documentation:** Altera FPGA development tools

## Contact

**Mike Wolak** - mikewolak@gmail.com

**Project Repository:** https://github.com/mikewolak/picorv32-de2