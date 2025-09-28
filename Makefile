# XORO Minimal RISC-V System
# Clean build with only essential components

# Build tools
RISCV_PREFIX = /c/msys64/opt/riscv32/bin/riscv-none-elf-
GCC = TMP=/tmp TMPDIR=/tmp TEMP=/tmp $(RISCV_PREFIX)gcc
SHELL := /bin/bash
export PATH := /c/msys64/mingw64/bin:$(PATH)
export TMP := /tmp
export TEMP := /tmp
HOST_CC := /c/msys64/mingw64/bin/gcc.exe
HOST_CFLAGS = -std=c99 -Wall -Wextra -O2
OBJCOPY = $(RISCV_PREFIX)objcopy
OBJDUMP = $(RISCV_PREFIX)objdump
QUARTUS = /c/altera/80/quartus/bin/quartus_sh.exe
QUARTUS_PGM = /c/altera/80/quartus/bin/quartus_pgm.exe

# Targets
FIRMWARE_ELF = build/knight_rider.elf
FIRMWARE_BIN = build/knight_rider.bin
FIRMWARE_MIF = build/quartus/firmware.mif
FPGA_SOF = build/quartus/riscv_4mif_debug.sof

# RISC-V compiler flags
CFLAGS = -march=rv32i -mabi=ilp32 -mcmodel=medlow -nostdlib -Os -ffreestanding -g
LDFLAGS = -T src/linker.ld -nostdlib -Wl,--gc-sections

# Source files
C_SOURCES = src/main.c
ASM_SOURCES = src/start.S
OBJECTS = $(C_SOURCES:src/%.c=build/%.o) $(ASM_SOURCES:src/%.S=build/%.o)

.PHONY: all clean firmware fpga program help validate-firmware

all: firmware fpga

help:
	@echo "XORO Minimal RISC-V Build System"
	@echo "Available targets:"
	@echo "  firmware  - Build RISC-V firmware"
	@echo "  fpga      - Synthesize FPGA design"
	@echo "  program   - Program FPGA via JTAG"
	@echo "  clean     - Clean all build artifacts"
	@echo "  all       - Build firmware + FPGA"
	@echo "  validate-firmware - Run comprehensive firmware validation"

# Create build directory
build:
	@mkdir -p build build/quartus

# Build bin2mif tool
tools/bin2mif.exe: tools/bin2mif.c
	@echo "Building enhanced bin2mif tool..."
	$(HOST_CC) $(HOST_CFLAGS) -o $@ $<
	@echo "✅ bin2mif tool built successfully"

# Build enhanced bin2mif tool
tools/bin2mif_enhanced.exe: tools/bin2mif_enhanced.c
	@echo "Building enhanced bin2mif tool..."
	$(HOST_CC) $(HOST_CFLAGS) -o $@ $<
	@echo "✅ Enhanced bin2mif tool built successfully"

# Compile C sources
build/%.o: src/%.c | build
	@echo "Compiling $<..."
	$(GCC) $(CFLAGS) -c $< -o $@

# Compile assembly sources
build/%.o: src/%.S | build
	@echo "Assembling $<..."
	$(GCC) $(CFLAGS) -c $< -o $@

# Link firmware
$(FIRMWARE_ELF): $(OBJECTS)
	@echo "Linking RISC-V firmware..."
	$(GCC) $(LDFLAGS) $(OBJECTS) -o $@
	@echo "✅ Firmware linking successful"

# Convert to binary
$(FIRMWARE_BIN): $(FIRMWARE_ELF)
	@echo "Converting to binary..."
	$(OBJCOPY) -O binary $< $@
	@echo "✅ Binary conversion successful"

# Generate disassembly for debugging
build/knight_rider.lst: $(FIRMWARE_ELF)
	$(OBJDUMP) -d $< > $@

# Convert binary to MIF
$(FIRMWARE_MIF): $(FIRMWARE_BIN) tools/bin2mif.exe | build
	@echo "Converting binary to MIF..."
	@mkdir -p build/quartus
	./tools/bin2mif.exe -i $< -o $@ --single-mif --total-size 32768
	@echo "✅ MIF conversion successful"

# Generate 4-symbol MIF files for debug system
FIRMWARE_SYMBOL_MIFS = build/quartus/firmware_symbol_0.mif build/quartus/firmware_symbol_1.mif build/quartus/firmware_symbol_2.mif build/quartus/firmware_symbol_3.mif

$(FIRMWARE_SYMBOL_MIFS): $(FIRMWARE_BIN) tools/bin2mif_enhanced.exe | build
	@echo "Converting binary to 4-symbol MIF files..."
	@mkdir -p build/quartus
	./tools/bin2mif_enhanced.exe -i $< -o build/quartus/firmware_symbol_%d.mif --4-symbol --total-size 32768
	@echo "✅ 4-symbol MIF conversion successful"

# Build firmware
firmware: $(FIRMWARE_SYMBOL_MIFS) build/knight_rider.lst
	@echo "✅ Firmware build complete"

# Synthesize FPGA
$(FPGA_SOF): $(FIRMWARE_SYMBOL_MIFS)
	@echo "Building FPGA design..."
	cd build/quartus && $(QUARTUS) -t ../../scripts/build_riscv_debug.tcl
	@echo "✅ FPGA synthesis complete"

fpga: $(FPGA_SOF)

# Check USB-Blaster connection
check-cable:
	@echo "Checking USB-Blaster connection..."
	$(QUARTUS_PGM) --auto

# Program FPGA
program: $(FPGA_SOF)
	@echo "Programming FPGA..."
	cd build/quartus && $(QUARTUS_PGM) -c USB-Blaster -m JTAG -o "p;xoro_minimal.sof"
	@echo "✅ FPGA programming complete"

# Clean build artifacts
clean:
	rm -rf build/*
	rm -f tools/bin2mif.exe
	@echo "✅ Build artifacts cleaned"

# Debug targets
debug-firmware:
	$(OBJDUMP) -d $(FIRMWARE_ELF) | head -50

debug-mif:
	head -20 $(FIRMWARE_MIF)

# Firmware validation - depends on firmware target, not individual files
validate-firmware: firmware
	@echo "Running firmware validation..."
	@scripts/validate_firmware.sh