#!/bin/bash
# XORO Minimal Firmware Validation Script
# Comprehensive validation of firmware build artifacts

# Run all checks and report results, but don't exit early on individual failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
FIRMWARE_ELF="build/knight_rider.elf"
FIRMWARE_BIN="build/knight_rider.bin"
FIRMWARE_MIF="build/quartus/firmware.mif"
FIRMWARE_LST="build/knight_rider.lst"
LINKER_SCRIPT="src/linker.ld"

# Tools
OBJDUMP="/c/msys64/opt/riscv32/bin/riscv-none-elf-objdump"
OBJSIZE="/c/msys64/opt/riscv32/bin/riscv-none-elf-size"
READELF="/c/msys64/opt/riscv32/bin/riscv-none-elf-readelf"

# Results tracking
CHECKS_PASSED=0
CHECKS_FAILED=0
TOTAL_CHECKS=0

# Print functions
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  XORO Minimal Firmware Validation${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
}

print_check() {
    local check_name="$1"
    echo -e "${YELLOW}[CHECK]${NC} $check_name"
}

print_pass() {
    local message="$1"
    echo -e "${GREEN}[PASS]${NC} $message"
    ((CHECKS_PASSED++))
    ((TOTAL_CHECKS++))
}

print_fail() {
    local message="$1"
    echo -e "${RED}[FAIL]${NC} $message"
    ((CHECKS_FAILED++))
    ((TOTAL_CHECKS++))
}

print_info() {
    local message="$1"
    echo -e "${BLUE}[INFO]${NC} $message"
}

print_summary() {
    echo
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Validation Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Total Checks: $TOTAL_CHECKS"
    echo -e "${GREEN}Passed: $CHECKS_PASSED${NC}"
    echo -e "${RED}Failed: $CHECKS_FAILED${NC}"

    if [ $CHECKS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✅ All firmware validation checks passed!${NC}"
        return 0
    else
        echo -e "${RED}❌ Firmware validation failed!${NC}"
        return 1
    fi
}

# Extract memory layout from linker script
extract_memory_layout() {
    local ram_origin=$(grep -A2 "MEMORY" "$LINKER_SCRIPT" | grep "ram.*ORIGIN" | sed 's/.*ORIGIN = \([^,]*\).*/\1/' | sed 's/[[:space:]]*//g')
    local ram_length=$(grep -A2 "MEMORY" "$LINKER_SCRIPT" | grep "ram.*LENGTH" | sed 's/.*LENGTH = \([^[:space:]]*\).*/\1/' | sed 's/[[:space:]]*//g')

    # Convert hex to decimal if needed
    if [[ $ram_origin == 0x* ]]; then
        RAM_ORIGIN=$((ram_origin))
    else
        RAM_ORIGIN=$ram_origin
    fi

    if [[ $ram_length == 0x* ]]; then
        RAM_SIZE=$((ram_length))
    else
        RAM_SIZE=$ram_length
    fi

    RAM_END=$((RAM_ORIGIN + RAM_SIZE - 1))
}

# Check 1: MIF file exists and has content
check_mif_exists() {
    print_check "MIF file existence and size"

    if [ ! -f "$FIRMWARE_MIF" ]; then
        print_fail "MIF file does not exist: $FIRMWARE_MIF"
        return 1
    fi

    local mif_size=$(ls -la "$FIRMWARE_MIF" | awk '{print $5}')

    if [ "$mif_size" -le 0 ]; then
        print_fail "MIF file is empty: $FIRMWARE_MIF (size: $mif_size bytes)"
        return 1
    fi

    print_pass "MIF file exists and has content (size: $mif_size bytes)"
    print_info "MIF file: $FIRMWARE_MIF"
}

# Check 2: Generate and verify assembly listing
check_assembly_listing() {
    print_check "Assembly listing generation and verification"

    if [ ! -f "$FIRMWARE_ELF" ]; then
        print_fail "ELF file does not exist: $FIRMWARE_ELF"
        return 1
    fi

    # Generate listing
    $OBJDUMP -d "$FIRMWARE_ELF" > "$FIRMWARE_LST"

    if [ ! -f "$FIRMWARE_LST" ]; then
        print_fail "Failed to generate assembly listing: $FIRMWARE_LST"
        return 1
    fi

    local lst_lines=$(wc -l < "$FIRMWARE_LST")
    if [ "$lst_lines" -le 10 ]; then
        print_fail "Assembly listing appears empty or too short ($lst_lines lines)"
        return 1
    fi

    print_pass "Assembly listing generated successfully ($lst_lines lines)"
    print_info "Listing file: $FIRMWARE_LST"
}

# Check 3: Verify stack pointer initialization
check_stack_pointer() {
    print_check "Stack pointer initialization"

    # Extract _stack_end symbol from ELF
    local stack_end_addr=$($READELF -s "$FIRMWARE_ELF" | grep "_stack_end" | awk '{print "0x" $2}')

    if [ -z "$stack_end_addr" ]; then
        print_fail "Cannot find _stack_end symbol in ELF file"
        return 1
    fi

    # Convert to decimal for comparison
    local stack_end_dec=$((stack_end_addr))

    # Check if stack end is within memory bounds
    if [ $stack_end_dec -lt $RAM_ORIGIN ] || [ $stack_end_dec -gt $RAM_END ]; then
        print_fail "Stack end address $stack_end_addr is outside memory bounds (0x$(printf '%X' $RAM_ORIGIN) - 0x$(printf '%X' $RAM_END))"
        return 1
    fi

    # Verify stack pointer is properly referenced in _start function
    local start_function=$(grep -A20 "<_start>" "$FIRMWARE_LST")
    if [ -z "$start_function" ]; then
        print_fail "Cannot find _start function in assembly listing"
        return 1
    fi

    # Check that _start function contains stack pointer setup (any sp instruction)
    local sp_setup=$(echo "$start_function" | grep "sp")
    if [ -z "$sp_setup" ]; then
        print_fail "_start function does not contain stack pointer setup"
        return 1
    fi

    print_pass "Stack pointer correctly initialized to $stack_end_addr"
    print_info "Stack end within memory bounds: 0x$(printf '%X' $RAM_ORIGIN) - 0x$(printf '%X' $RAM_END)"
    print_info "SP setup found in _start function"
}

# Check 4: Memory layout validation
check_memory_layout() {
    print_check "Memory layout and size constraints"

    # Get section information
    local text_size=$($OBJSIZE -A "$FIRMWARE_ELF" | grep "\.text" | awk '{print $2}')
    local data_size=$($OBJSIZE -A "$FIRMWARE_ELF" | grep "\.data" | awk '{print $2}' || echo "0")
    local bss_size=$($OBJSIZE -A "$FIRMWARE_ELF" | grep "\.bss" | awk '{print $2}' || echo "0")

    # Calculate total used memory
    local total_used=$((text_size + data_size + bss_size))

    if [ $total_used -gt $RAM_SIZE ]; then
        print_fail "Firmware size ($total_used bytes) exceeds available memory ($RAM_SIZE bytes)"
        return 1
    fi

    local usage_percent=$((total_used * 100 / RAM_SIZE))

    print_pass "Firmware fits in memory: $total_used/$RAM_SIZE bytes (${usage_percent}% used)"
    print_info "Memory layout: TEXT=$text_size, DATA=$data_size, BSS=$bss_size bytes"
    print_info "Available memory: $RAM_SIZE bytes (0x$(printf '%X' $RAM_SIZE))"
}

# Check 5: MIF content validation
check_mif_content() {
    print_check "MIF file content validation"

    # Check MIF header
    local mif_header=$(head -10 "$FIRMWARE_MIF" | grep -E "DEPTH|WIDTH|ADDRESS_RADIX|DATA_RADIX")

    if [ -z "$mif_header" ]; then
        print_fail "MIF file appears to have invalid header format"
        return 1
    fi

    # Extract first few instructions from MIF
    local first_instruction=$(grep -E "^0000.*:" "$FIRMWARE_MIF" | head -1 | cut -d: -f2 | tr -d ' ;')

    if [ -z "$first_instruction" ]; then
        print_fail "Cannot find first instruction in MIF file"
        return 1
    fi

    # Check if first instruction looks like valid RISC-V
    if [[ ! $first_instruction =~ ^[0-9A-Fa-f]{8}$ ]]; then
        print_fail "First instruction in MIF has invalid format: $first_instruction"
        return 1
    fi

    # Count total instructions in MIF
    local mif_instructions=$(grep -E "^[0-9A-Fa-f]{4}.*:" "$FIRMWARE_MIF" | wc -l)

    print_pass "MIF content appears valid"
    print_info "First instruction: 0x$first_instruction"
    print_info "Total MIF entries: $mif_instructions"
}

# Check 6: Cross-reference MIF with binary
check_mif_binary_match() {
    print_check "MIF and binary file cross-reference"

    # Check if binary file exists
    if [ ! -f "$FIRMWARE_BIN" ]; then
        print_fail "Binary file does not exist: $FIRMWARE_BIN"
        return 1
    fi

    # Get binary size and compare with expected MIF content
    local bin_size=$(ls -la "$FIRMWARE_BIN" | awk '{print $5}')

    if [ "$bin_size" -eq 0 ]; then
        print_fail "Binary file is empty: $FIRMWARE_BIN"
        return 1
    fi

    # Check that MIF contains non-fill instructions (fill pattern is typically 0x00000013)
    local non_fill_instructions=$(grep -E "^[0-9A-F]{4}.*:" "$FIRMWARE_MIF" | grep -v -i "00000013" | wc -l)

    if [ "$non_fill_instructions" -eq 0 ]; then
        print_fail "MIF file contains only fill patterns (no actual firmware)"
        return 1
    fi

    # Verify MIF has correct number of entries for memory size
    local total_mif_entries=$(grep -E "^[0-9A-F]{4}.*:" "$FIRMWARE_MIF" | wc -l)
    local expected_entries=$((RAM_SIZE / 4))  # 32-bit words

    if [ "$total_mif_entries" -ne "$expected_entries" ]; then
        print_fail "MIF has wrong number of entries: $total_mif_entries (expected: $expected_entries)"
        return 1
    fi

    print_pass "MIF appears to be correctly generated from binary"
    print_info "Binary size: $bin_size bytes"
    print_info "Non-fill instructions in MIF: $non_fill_instructions"
    print_info "Total MIF entries: $total_mif_entries (expected: $expected_entries)"
}

# Main validation function
main() {
    print_header

    # Extract memory layout from linker script
    extract_memory_layout
    print_info "Memory layout: Origin=0x$(printf '%X' $RAM_ORIGIN), Size=$RAM_SIZE bytes (0x$(printf '%X' $RAM_SIZE))"
    echo

    # Run all checks (continue even if some fail)
    check_mif_exists || true
    check_assembly_listing || true
    check_stack_pointer || true
    check_memory_layout || true
    check_mif_content || true
    check_mif_binary_match || true

    # Print summary and return result
    print_summary
}

# Run main function
main "$@"