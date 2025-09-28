# Debug System Issues - Reset-Based Control Problems

**Date:** 2025-09-28
**System:** RISC-V 4-MIF Debug System with Reset-Based Control
**Status:** PARTIALLY FUNCTIONAL - Major stepping and reset issues remain

## Current System State

### What Works ✅
- System starts in HALT mode as intended
- Shows 0 cycles executed at startup (fixed from previous 2 cycles)
- CPU receives clock and is responsive to some degree
- FPGA programming successful with reset-based control

### Critical Issues Remaining ❌

#### 1. Step Button (KEY2) Malfunction
**Problem:** KEY2 (step) doesn't perform single-step debugging as intended
- **Expected:** Press KEY2 → Execute exactly 1 instruction → Return to HALT
- **Actual:** Press KEY2 → Starts continuous clock → CPU runs continuously
- **Workaround:** Must press KEY1 (halt) to stop the runaway execution

#### 2. Run/Halt Button (KEY1) State Issues
**Problem:** KEY1 (run/halt) toggle behavior is broken
- **Expected:** Press KEY1 → Toggle between RUN and HALT states
- **Actual:** After stopping runaway step execution, KEY1 won't restart CPU
- **Workaround:** Must reset system, then press KEY1 halt, then reset again to get CPU running

#### 3. Reset State Inconsistency
**Problem:** System reset doesn't initialize to PC=0x00000000
- **Expected:** Reset → PC = 0x00000000 (start of firmware)
- **Actual:** Reset → PC = 0x0000000C (offset by 12 bytes)
- **Impact:** CPU starts execution at wrong instruction address

## Technical Analysis

### Root Cause: State Machine Logic Issues
The reset-based control implementation has fundamental flaws in state transitions:

1. **STEPPING State Transition:**
   - STEPPING state likely doesn't transition back to HALTED after one clock cycle
   - May be getting stuck in RUNNING state instead

2. **Button Edge Detection:**
   - Edge detection for KEY1 and KEY2 may not be working correctly
   - State changes may not be properly synchronized with button presses

3. **Reset Logic:**
   - PC initialization may be affected by reset control mechanism
   - Startup counter may interfere with proper CPU reset sequence

### File Affected
**Primary:** `/c/msys64/home/mwolak/fpgaseq/xoro-minimal/rtl/test_4mif_riscv_debug.vhd`
- Lines 180-220: State machine logic for debug control
- Lines 90-110: Button edge detection and debouncing
- Lines 140-160: CPU reset control mechanism

## Attempted Solutions

### Previous Fix: Clock Gating → Reset Control
- **Clock Gating (BROKEN):** `cpu_clk <= '0'` when HALTED → CPU completely unresponsive
- **Reset Control (CURRENT):** `cpu_resetn <= '0'` when HALTED → Partially functional but stepping broken

### Current Implementation Issues
```vhdl
-- Current problematic logic:
cpu_resetn <= '0' when execution_state = HALTED else resetn;

-- State transitions may be incorrect:
when STEPPING =>
    -- Missing: Return to HALTED after exactly 1 cycle
    -- Currently: May transition to RUNNING instead
```

## Impact on Development

### Development Workflow Disrupted
- Cannot perform reliable single-step debugging
- Cannot verify instruction-by-instruction execution
- Debugging requires constant system resets
- Knight Rider LED pattern cannot be properly analyzed

### Testing Limitations
- Unable to verify CPU instruction execution step-by-step
- Cannot debug memory access patterns at instruction level
- LED timing analysis requires functional stepping mechanism

## Next Steps Required

### Priority 1: Fix Step Button Logic
1. Implement proper single-cycle stepping mechanism
2. Ensure STEPPING state returns to HALTED after exactly 1 clock
3. Fix state machine transitions for reliable step debugging

### Priority 2: Fix Run/Halt Toggle
1. Debug button edge detection and debouncing
2. Ensure clean state transitions between RUN and HALT
3. Verify toggle behavior works consistently

### Priority 3: Fix Reset PC Initialization
1. Investigate why PC starts at 0x0000000C instead of 0x00000000
2. Verify linker script and startup code alignment
3. Ensure reset properly initializes CPU to entry point

## Workaround for Current Development

### For LED Pattern Testing
- Use continuous run mode (KEY1) to observe LED patterns
- Reduce LED timing delays to make patterns more visible
- Focus on overall functionality rather than step-by-step debugging

### For Basic Verification
- Verify system starts in HALT with 0 cycles (✅ Working)
- Use run mode to confirm CPU can execute instructions
- Rely on LED patterns and display outputs for functional verification

**Note:** The step debugging capability is currently non-functional and requires significant state machine rework to achieve proper single-instruction stepping behavior.
## CRITICAL INSIGHT: Reset Execution Race Condition

**Discovery:** PC starting at 0x0000000C reveals CPU executes 3 instructions during reset

### Analysis
- **PC offset:** 0x0000000C = 12 bytes = 3 RISC-V instructions × 4 bytes each
- **Timing issue:** CPU begins execution immediately when cpu_resetn releases
- **Debug lag:** Debug system cannot assert HALT state fast enough to prevent initial execution
- **Consequence:** First 3 instructions always execute before debug control takes effect

### First 3 Instructions (Always Execute)
Need to examine what these critical first instructions are:
1. Instruction at 0x00000000
2. Instruction at 0x00000004  
3. Instruction at 0x00000008
4. **Debug halts here** → PC = 0x0000000C

### LED Timing Update
- **Previous delay:** 500,000 cycles (slow pattern)
- **New delay:** 50,000 cycles (10x faster for better visibility)
- **Purpose:** Make Knight Rider pattern more visible during run mode testing

**Date Updated:** 2025-09-28 12:18

