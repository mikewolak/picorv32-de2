-- RISC-V 4-MIF Debug System
-- Complete RISC-V debugging with proven LCD infrastructure
-- Based on validated memory_test_4mif.vhd architecture

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity test_4mif_riscv_debug is
    port (
        -- Clock and Reset
        CLOCK_50 : in std_logic;
        KEY : in std_logic_vector(3 downto 0);

        -- Switches for debug control
        SW : in std_logic_vector(17 downto 0);

        -- LEDs for status and Knight Rider pattern
        LEDR : out std_logic_vector(17 downto 0);
        LEDG : out std_logic_vector(8 downto 0);

        -- 7-Segment Display (Program Counter)
        HEX0 : out std_logic_vector(6 downto 0);
        HEX1 : out std_logic_vector(6 downto 0);
        HEX2 : out std_logic_vector(6 downto 0);
        HEX3 : out std_logic_vector(6 downto 0);
        HEX4 : out std_logic_vector(6 downto 0);
        HEX5 : out std_logic_vector(6 downto 0);
        HEX6 : out std_logic_vector(6 downto 0);
        HEX7 : out std_logic_vector(6 downto 0);

        -- LCD Display Interface
        LCD_DATA : inout std_logic_vector(7 downto 0);
        LCD_RW : out std_logic;
        LCD_EN : out std_logic;
        LCD_RS : out std_logic;
        LCD_ON : out std_logic;
        LCD_BLON : out std_logic;

        -- GPIO (unused but required for pin assignments)
        GPIO_0 : inout std_logic_vector(35 downto 0);
        GPIO_1 : inout std_logic_vector(35 downto 0)
    );
end entity;

architecture rtl of test_4mif_riscv_debug is
    -- Clock and reset signals
    signal clk : std_logic;
    signal resetn : std_logic;

    -- LCD clock divider (faster: 50MHz / 1 = 50MHz, no division)
    signal lcd_clk : std_logic := '0';
    signal clk_div_counter : integer range 0 to 0 := 0;

    -- Button debouncing (same as memory test)
    signal key_pressed : std_logic_vector(3 downto 0);
    signal key_prev : std_logic_vector(3 downto 0) := (others => '1');

    -- 4-MIF Memory Controller signals
    signal mem_valid : std_logic := '0';
    signal mem_ready : std_logic;
    signal mem_instr : std_logic := '0';
    signal mem_wstrb : std_logic_vector(3 downto 0) := (others => '0');
    signal mem_wdata : std_logic_vector(31 downto 0);
    signal mem_addr : std_logic_vector(31 downto 0);
    signal mem_rdata : std_logic_vector(31 downto 0);

    -- RISC-V CPU signals
    signal cpu_trap : std_logic;
    signal cpu_resetn : std_logic;
    signal cpu_clk : std_logic;

    -- Debug control signals
    type execution_state_type is (HALTED, RUNNING, STEPPING);
    signal execution_state : execution_state_type := HALTED;
    signal step_request : std_logic := '0';
    signal step_instruction_count : unsigned(63 downto 0) := (others => '0');
    signal startup_counter : unsigned(3 downto 0) := (others => '0');  -- Delay before allowing CPU to run
    signal startup_complete : std_logic := '0';  -- Flag indicating startup period is over

    -- Debug display mode (KEY3 cycles through modes)
    signal display_mode : integer range 0 to 5 := 0;

    -- Performance counters (64-bit)
    signal instruction_count : unsigned(63 downto 0) := (others => '0');
    signal cycle_count : unsigned(63 downto 0) := (others => '0');

    -- Real-time clock (HH:MM:SS) at 50MHz
    signal clock_counter : unsigned(31 downto 0) := (others => '0');  -- 32-bit counter for 50MHz clock
    signal seconds : unsigned(7 downto 0) := (others => '0');         -- BCD format: 4 bits tens + 4 bits ones
    signal minutes : unsigned(7 downto 0) := (others => '0');         -- BCD format: 4 bits tens + 4 bits ones
    signal hours : unsigned(7 downto 0) := (others => '0');           -- BCD format: 4 bits tens + 4 bits ones

    -- Copy timer signals for LCD display (to avoid scope issues)
    signal lcd_seconds : unsigned(7 downto 0) := (others => '0');
    signal lcd_minutes : unsigned(7 downto 0) := (others => '0');
    signal lcd_hours : unsigned(7 downto 0) := (others => '0');

    -- IPS calculation
    signal ips_sample_timer : unsigned(25 downto 0) := (others => '0');
    signal ips_current : unsigned(31 downto 0) := (others => '0');

    -- LED driver for Knight Rider pattern (memory-mapped I/O at 0xFFFF0060)
    signal led_register : std_logic_vector(17 downto 0) := (others => '0');
    signal last_instruction_count : unsigned(63 downto 0) := (others => '0');

    -- PC tracking (capture PC during instruction fetch)
    signal program_counter : std_logic_vector(31 downto 0) := (others => '0');
    signal current_instruction : std_logic_vector(31 downto 0) := (others => '0');

    -- LCD controller signals (same as memory test)
    signal lcd_enable : std_logic;
    signal lcd_bus : std_logic_vector(9 downto 0);
    signal lcd_busy : std_logic;

    -- 4-MIF Memory Controller Component
    component mem_controller_4mif
        port (
            clk : in std_logic;
            resetn : in std_logic;
            mem_valid : in std_logic;
            mem_ready : out std_logic;
            mem_instr : in std_logic;
            mem_wstrb : in std_logic_vector(3 downto 0);
            mem_wdata : in std_logic_vector(31 downto 0);
            mem_addr : in std_logic_vector(31 downto 0);
            mem_rdata : out std_logic_vector(31 downto 0)
        );
    end component;

    -- PicoRV32 RISC-V CPU Component
    component picorv32
        generic (
            ENABLE_COUNTERS : integer := 1;
            ENABLE_COUNTERS64 : integer := 1;
            ENABLE_REGS_16_31 : integer := 1;
            ENABLE_REGS_DUALPORT : integer := 1;
            LATCHED_MEM_RDATA : integer := 0;
            TWO_STAGE_SHIFT : integer := 1;
            BARREL_SHIFTER : integer := 0;
            TWO_CYCLE_COMPARE : integer := 0;
            TWO_CYCLE_ALU : integer := 0;
            COMPRESSED_ISA : integer := 0;
            CATCH_MISALIGN : integer := 1;
            CATCH_ILLINSN : integer := 1;
            ENABLE_PCPI : integer := 0;
            ENABLE_MUL : integer := 0;
            ENABLE_FAST_MUL : integer := 0;
            ENABLE_DIV : integer := 0;
            ENABLE_IRQ : integer := 0;
            ENABLE_IRQ_QREGS : integer := 1;
            ENABLE_IRQ_TIMER : integer := 1;
            ENABLE_TRACE : integer := 0;
            REGS_INIT_ZERO : integer := 0;
            MASKED_IRQ : std_logic_vector(31 downto 0) := x"00000000";
            LATCHED_IRQ : std_logic_vector(31 downto 0) := x"ffffffff";
            PROGADDR_RESET : std_logic_vector(31 downto 0) := x"00000000";
            PROGADDR_IRQ : std_logic_vector(31 downto 0) := x"00000010";
            STACKADDR : std_logic_vector(31 downto 0) := x"00007c00"
        );
        port (
            clk : in std_logic;
            resetn : in std_logic;
            trap : out std_logic;

            mem_valid : out std_logic;
            mem_instr : out std_logic;
            mem_ready : in std_logic;
            mem_addr : out std_logic_vector(31 downto 0);
            mem_wdata : out std_logic_vector(31 downto 0);
            mem_wstrb : out std_logic_vector(3 downto 0);
            mem_rdata : in std_logic_vector(31 downto 0);

            pcpi_valid : out std_logic;
            pcpi_insn : out std_logic_vector(31 downto 0);
            pcpi_rs1 : out std_logic_vector(31 downto 0);
            pcpi_rs2 : out std_logic_vector(31 downto 0);
            pcpi_wr : in std_logic;
            pcpi_rd : in std_logic_vector(31 downto 0);
            pcpi_wait : in std_logic;
            pcpi_ready : in std_logic;

            irq : in std_logic_vector(31 downto 0);
            eoi : out std_logic_vector(31 downto 0);

            trace_valid : out std_logic;
            trace_data : out std_logic_vector(35 downto 0)
        );
    end component;

    -- LCD controller component (same as memory test)
    component lcd_controller
        port (
            clk : in std_logic;
            reset_n : in std_logic;
            lcd_enable : in std_logic;
            lcd_bus : in std_logic_vector(9 downto 0);
            busy : out std_logic;
            rw : out std_logic;
            rs : out std_logic;
            e : out std_logic;
            lcd_data : inout std_logic_vector(7 downto 0)
        );
    end component;

    -- Hex display component
    component hex_display
        port (
            clk : in std_logic;
            resetn : in std_logic;
            value : in std_logic_vector(31 downto 0);
            hex0 : out std_logic_vector(6 downto 0);
            hex1 : out std_logic_vector(6 downto 0);
            hex2 : out std_logic_vector(6 downto 0);
            hex3 : out std_logic_vector(6 downto 0);
            hex4 : out std_logic_vector(6 downto 0);
            hex5 : out std_logic_vector(6 downto 0);
            hex6 : out std_logic_vector(6 downto 0);
            hex7 : out std_logic_vector(6 downto 0)
        );
    end component;

    -- Convert hex nibble to ASCII (same function as memory test)
    function hex_to_lcd(hex_val : std_logic_vector(3 downto 0)) return std_logic_vector is
        variable lcd_val : std_logic_vector(9 downto 0);
    begin
        case hex_val is
            when "0000" => lcd_val := "1000110000"; -- '0'
            when "0001" => lcd_val := "1000110001"; -- '1'
            when "0010" => lcd_val := "1000110010"; -- '2'
            when "0011" => lcd_val := "1000110011"; -- '3'
            when "0100" => lcd_val := "1000110100"; -- '4'
            when "0101" => lcd_val := "1000110101"; -- '5'
            when "0110" => lcd_val := "1000110110"; -- '6'
            when "0111" => lcd_val := "1000110111"; -- '7'
            when "1000" => lcd_val := "1000111000"; -- '8'
            when "1001" => lcd_val := "1000111001"; -- '9'
            when "1010" => lcd_val := "1001000001"; -- 'A'
            when "1011" => lcd_val := "1001000010"; -- 'B'
            when "1100" => lcd_val := "1001000011"; -- 'C'
            when "1101" => lcd_val := "1001000100"; -- 'D'
            when "1110" => lcd_val := "1001000101"; -- 'E'
            when "1111" => lcd_val := "1001000110"; -- 'F'
            when others => lcd_val := "1000100000"; -- Space
        end case;
        return lcd_val;
    end function;

begin
    -- Clock and reset
    clk <= CLOCK_50;
    resetn <= KEY(0);  -- KEY0 = global reset

    -- LCD Clock - Direct connection to 50MHz (fastest possible)
    lcd_clk <= clk;  -- Direct assignment, no process needed

    -- CPU control: Provide clock during startup and when running/stepping
    -- During startup: CPU gets clock for proper initialization
    -- After startup: Clock gating controls execution, but CPU keeps state when halted
    cpu_resetn <= resetn;  -- CPU only resets on system reset, never on HALTED
    cpu_clk <= clk when (startup_complete = '0' or execution_state = RUNNING or execution_state = STEPPING) else '0';

    -- Button edge detection (proven working logic from memory test)
    button_debounce : process(clk)
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                key_prev <= (others => '1');
                key_pressed <= (others => '0');
            else
                key_prev <= KEY;
                key_pressed <= key_prev and not KEY;  -- Simple falling edge detection
            end if;
        end if;
    end process;

    -- Debug control state machine
    debug_control : process(clk)
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                execution_state <= HALTED;  -- Start halted for immediate debug capability
                display_mode <= 0;
                step_request <= '0';
                step_instruction_count <= (others => '0');
                startup_counter <= (others => '0');
                startup_complete <= '0';
            else
                step_request <= '0'; -- Default

                -- Startup delay: stay halted for a few cycles after reset
                if startup_counter < 15 then
                    startup_counter <= startup_counter + 1;
                    execution_state <= HALTED;  -- Force halted during startup
                    startup_complete <= '0';    -- Keep startup flag clear
                else
                    startup_complete <= '1';    -- Mark startup as complete
                    -- Normal key processing only after startup delay

                    -- KEY1: Start/Stop execution
                    if key_pressed(1) = '1' then
                    case execution_state is
                        when HALTED => execution_state <= RUNNING;
                        when RUNNING => execution_state <= HALTED;
                        when STEPPING => execution_state <= RUNNING;
                    end case;
                end if;

                -- KEY2: Single step (when halted) - step until next instruction completes
                if key_pressed(2) = '1' and execution_state = HALTED then
                    execution_state <= STEPPING;
                    step_request <= '1';
                    step_instruction_count <= instruction_count; -- Remember current count
                end if;

                -- Auto-return from STEPPING to HALTED when instruction completes
                if execution_state = STEPPING then
                    -- Check if instruction count increased (instruction completed)
                    if instruction_count > step_instruction_count then
                        execution_state <= HALTED;
                    end if;
                end if;

                -- KEY3: Cycle display modes
                if key_pressed(3) = '1' then
                    if display_mode = 5 then
                        display_mode <= 0;
                    else
                        display_mode <= display_mode + 1;
                    end if;
                end if;

                end if;  -- End startup delay check

                -- Auto-halt on trap
                if cpu_trap = '1' and execution_state = RUNNING then
                    execution_state <= HALTED;
                end if;
            end if;
        end if;
    end process;

    -- Performance counters (independent of LCD timing)
    performance_counters : process(clk)
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                instruction_count <= (others => '0');
                cycle_count <= (others => '0');
                ips_sample_timer <= (others => '0');
                ips_current <= (others => '0');
                last_instruction_count <= (others => '0');
            else
                -- Count completed instructions
                if mem_valid = '1' and mem_ready = '1' and mem_instr = '1' then
                    instruction_count <= instruction_count + 1;
                end if;

                -- Count clock cycles when CPU is actually clocked (running or stepping)
                if execution_state = RUNNING or execution_state = STEPPING then
                    cycle_count <= cycle_count + 1;
                end if;

                -- IPS calculation (sample every 1.0 second)
                if ips_sample_timer = 49999999 then  -- 1.0 second at 50MHz
                    ips_sample_timer <= (others => '0');
                    ips_current <= instruction_count(31 downto 0) - last_instruction_count(31 downto 0);
                    last_instruction_count <= instruction_count;
                else
                    ips_sample_timer <= ips_sample_timer + 1;
                end if;
            end if;
        end if;
    end process;

    -- PC and instruction tracking (asynchronous sampling for LCD)
    pc_tracking : process(clk)
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                program_counter <= (others => '0');
                current_instruction <= (others => '0');
            else
                -- Capture PC during instruction fetch
                if mem_valid = '1' and mem_instr = '1' then
                    program_counter <= mem_addr;
                end if;

                -- Capture instruction when fetch completes
                if mem_valid = '1' and mem_ready = '1' and mem_instr = '1' then
                    current_instruction <= mem_rdata;
                end if;
            end if;
        end if;
    end process;

    -- Real-time clock: 50MHz -> HH:MM:SS (always runs, independent of CPU state)
    real_time_clock : process(clk)
    begin
        if rising_edge(clk) then
            if resetn = '0' then  -- Use same reset as everything else
                clock_counter <= (others => '0');
                seconds <= (others => '0');
                minutes <= (others => '0');
                hours <= (others => '0');
            else
                if clock_counter = to_unsigned(49999999, 32) then  -- 50MHz -> 1 second
                    clock_counter <= (others => '0');

                    -- Increment seconds in BCD format
                    if seconds(3 downto 0) = "1001" then  -- 9 seconds
                        seconds(3 downto 0) <= "0000";
                        if seconds(7 downto 4) = "0101" then  -- 59 seconds
                            seconds(7 downto 4) <= "0000";

                            -- Increment minutes in BCD format
                            if minutes(3 downto 0) = "1001" then  -- 9 minutes
                                minutes(3 downto 0) <= "0000";
                                if minutes(7 downto 4) = "0101" then  -- 59 minutes
                                    minutes(7 downto 4) <= "0000";

                                    -- Increment hours in BCD format
                                    if hours(3 downto 0) = "1001" then  -- 9 hours
                                        hours(3 downto 0) <= "0000";
                                        if hours(7 downto 4) = "0010" then  -- 23 hours
                                            hours(7 downto 4) <= "0000";
                                        else
                                            hours(7 downto 4) <= hours(7 downto 4) + 1;
                                        end if;
                                    else
                                        hours(3 downto 0) <= hours(3 downto 0) + 1;
                                    end if;
                                else
                                    minutes(7 downto 4) <= minutes(7 downto 4) + 1;
                                end if;
                            else
                                minutes(3 downto 0) <= minutes(3 downto 0) + 1;
                            end if;
                        else
                            seconds(7 downto 4) <= seconds(7 downto 4) + 1;
                        end if;
                    else
                        seconds(3 downto 0) <= seconds(3 downto 0) + 1;
                    end if;
                else
                    clock_counter <= clock_counter + 1;
                end if;
            end if;
        end if;
    end process;

    -- Copy timer signals for LCD display
    timer_copy : process(clk)
    begin
        if rising_edge(clk) then
            lcd_seconds <= seconds;
            lcd_minutes <= minutes;
            lcd_hours <= hours;
        end if;
    end process;

    -- LED Memory-Mapped I/O Handler (address 0xFFFF0060)
    -- Independent of memory controller - detects writes directly
    led_io : process(clk)
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                led_register <= (others => '0');
            else
                -- LED I/O: Only respond to writes to exact address 0xFFFF0060
                if mem_wstrb /= "0000" and mem_addr = x"FFFF0060" then
                    -- Store the write data in all LEDs for Knight Rider pattern
                    led_register <= mem_wdata(17 downto 0);
                end if;
            end if;
        end if;
    end process;

    -- 4-MIF Memory Controller Instance (proven working)
    memory_ctrl : mem_controller_4mif
        port map (
            clk => clk,
            resetn => resetn,
            mem_valid => mem_valid,  -- Direct memory access (no gating)
            mem_ready => mem_ready,
            mem_instr => mem_instr,
            mem_wstrb => mem_wstrb,
            mem_wdata => mem_wdata,
            mem_addr => mem_addr,
            mem_rdata => mem_rdata
        );

    -- PicoRV32 CPU Instance
    cpu : picorv32
        generic map (
            ENABLE_COUNTERS => 1,
            ENABLE_COUNTERS64 => 1,
            ENABLE_REGS_16_31 => 1,
            ENABLE_REGS_DUALPORT => 1,
            LATCHED_MEM_RDATA => 0,
            TWO_STAGE_SHIFT => 1,
            BARREL_SHIFTER => 0,
            TWO_CYCLE_COMPARE => 0,
            TWO_CYCLE_ALU => 0,
            COMPRESSED_ISA => 0,
            CATCH_MISALIGN => 1,
            CATCH_ILLINSN => 1,
            ENABLE_PCPI => 0,
            ENABLE_MUL => 0,
            ENABLE_FAST_MUL => 0,
            ENABLE_DIV => 0,
            ENABLE_IRQ => 0,
            ENABLE_IRQ_QREGS => 1,
            ENABLE_IRQ_TIMER => 1,
            ENABLE_TRACE => 0,
            REGS_INIT_ZERO => 0,
            MASKED_IRQ => x"00000000",
            LATCHED_IRQ => x"ffffffff",
            PROGADDR_RESET => x"00000000",
            PROGADDR_IRQ => x"00000010",
            STACKADDR => x"00007c00"
        )
        port map (
            clk => cpu_clk,  -- Gated clock for stepping control
            resetn => cpu_resetn,  -- Only resets with global reset
            trap => cpu_trap,

            mem_valid => mem_valid,
            mem_instr => mem_instr,
            mem_ready => mem_ready,
            mem_addr => mem_addr,
            mem_wdata => mem_wdata,
            mem_wstrb => mem_wstrb,
            mem_rdata => mem_rdata,

            pcpi_valid => open,
            pcpi_insn => open,
            pcpi_rs1 => open,
            pcpi_rs2 => open,
            pcpi_wr => '0',
            pcpi_rd => (others => '0'),
            pcpi_wait => '0',
            pcpi_ready => '0',

            irq => (others => '0'),
            eoi => open,

            trace_valid => open,
            trace_data => open
        );

    -- LCD controller (same as memory test)
    lcd_ctrl : lcd_controller
        port map (
            clk => lcd_clk,
            reset_n => '1',
            lcd_enable => lcd_enable,
            lcd_bus => lcd_bus,
            busy => lcd_busy,
            rw => LCD_RW,
            rs => LCD_RS,
            e => LCD_EN,
            lcd_data => LCD_DATA
        );

    -- LCD Display Process (KEY3 cycles through debug modes)
    lcd_display : process(lcd_clk)
        variable char : integer range 0 to 35 := 0;
        variable refresh_counter : integer range 0 to 100000 := 0;
        variable hours, minutes, seconds : unsigned(7 downto 0);
    begin
        if rising_edge(lcd_clk) then
            if lcd_busy = '0' and lcd_enable = '0' then
                if refresh_counter < 100000 then
                    refresh_counter := refresh_counter + 1;
                else
                    refresh_counter := 0;
                    lcd_enable <= '1';

                    case char is
                        -- Move cursor to home
                        when 0 => lcd_bus <= "0010000000";

                        -- Display based on selected mode
                        when 1 to 16 =>
                            case display_mode is
                                -- Mode 0: PC + Instruction
                                when 0 =>
                                    case char is
                                        when 1 => lcd_bus <= "1001010000"; -- 'P'
                                        when 2 => lcd_bus <= "1001000011"; -- 'C'
                                        when 3 => lcd_bus <= "1000111010"; -- ':'
                                        when 4 => lcd_bus <= hex_to_lcd(program_counter(31 downto 28));
                                        when 5 => lcd_bus <= hex_to_lcd(program_counter(27 downto 24));
                                        when 6 => lcd_bus <= hex_to_lcd(program_counter(23 downto 20));
                                        when 7 => lcd_bus <= hex_to_lcd(program_counter(19 downto 16));
                                        when 8 => lcd_bus <= hex_to_lcd(program_counter(15 downto 12));
                                        when 9 => lcd_bus <= hex_to_lcd(program_counter(11 downto 8));
                                        when 10 => lcd_bus <= hex_to_lcd(program_counter(7 downto 4));
                                        when 11 => lcd_bus <= hex_to_lcd(program_counter(3 downto 0));
                                        when 12 to 16 => lcd_bus <= "1000100000"; -- Spaces
                                        when others => lcd_bus <= "1000100000"; -- Space for other cases
                                    end case;

                                -- Mode 1: Memory Address + Data (data operations only)
                                when 1 =>
                                    case char is
                                        when 1 => lcd_bus <= "1001001101"; -- 'M'
                                        when 2 => lcd_bus <= "1001000001"; -- 'A'
                                        when 3 => lcd_bus <= "1000111010"; -- ':'
                                        when 4 => lcd_bus <= hex_to_lcd(mem_addr(31 downto 28));
                                        when 5 => lcd_bus <= hex_to_lcd(mem_addr(27 downto 24));
                                        when 6 => lcd_bus <= hex_to_lcd(mem_addr(23 downto 20));
                                        when 7 => lcd_bus <= hex_to_lcd(mem_addr(19 downto 16));
                                        when 8 => lcd_bus <= hex_to_lcd(mem_addr(15 downto 12));
                                        when 9 => lcd_bus <= hex_to_lcd(mem_addr(11 downto 8));
                                        when 10 => lcd_bus <= hex_to_lcd(mem_addr(7 downto 4));
                                        when 11 => lcd_bus <= hex_to_lcd(mem_addr(3 downto 0));
                                        when 12 to 16 => lcd_bus <= "1000100000"; -- Spaces
                                        when others => lcd_bus <= "1000100000"; -- Space for other cases
                                    end case;

                                -- Mode 2: Write Data + Control
                                when 2 =>
                                    case char is
                                        when 1 => lcd_bus <= "1001010111"; -- 'W'
                                        when 2 => lcd_bus <= "1001000100"; -- 'D'
                                        when 3 => lcd_bus <= "1000111010"; -- ':'
                                        when 4 => lcd_bus <= hex_to_lcd(mem_wdata(31 downto 28));
                                        when 5 => lcd_bus <= hex_to_lcd(mem_wdata(27 downto 24));
                                        when 6 => lcd_bus <= hex_to_lcd(mem_wdata(23 downto 20));
                                        when 7 => lcd_bus <= hex_to_lcd(mem_wdata(19 downto 16));
                                        when 8 => lcd_bus <= hex_to_lcd(mem_wdata(15 downto 12));
                                        when 9 => lcd_bus <= hex_to_lcd(mem_wdata(11 downto 8));
                                        when 10 => lcd_bus <= hex_to_lcd(mem_wdata(7 downto 4));
                                        when 11 => lcd_bus <= hex_to_lcd(mem_wdata(3 downto 0));
                                        when 12 to 16 => lcd_bus <= "1000100000"; -- Spaces
                                        when others => lcd_bus <= "1000100000"; -- Space for other cases
                                    end case;

                                -- Mode 3: CPU Status
                                when 3 =>
                                    case char is
                                        when 1 => lcd_bus <= "1001010110"; -- 'V'
                                        when 2 => lcd_bus <= "1000111010"; -- ':'
                                        when 3 =>
                                            if mem_valid = '1' then
                                                lcd_bus <= "1000110001"; -- '1'
                                            else
                                                lcd_bus <= "1000110000"; -- '0'
                                            end if;
                                        when 4 => lcd_bus <= "1000100000"; -- Space
                                        when 5 => lcd_bus <= "1001010010"; -- 'R'
                                        when 6 => lcd_bus <= "1000111010"; -- ':'
                                        when 7 =>
                                            if mem_ready = '1' then
                                                lcd_bus <= "1000110001"; -- '1'
                                            else
                                                lcd_bus <= "1000110000"; -- '0'
                                            end if;
                                        when 8 => lcd_bus <= "1000100000"; -- Space
                                        when 9 => lcd_bus <= "1001001001"; -- 'I'
                                        when 10 => lcd_bus <= "1000111010"; -- ':'
                                        when 11 =>
                                            if mem_instr = '1' then
                                                lcd_bus <= "1000110001"; -- '1'
                                            else
                                                lcd_bus <= "1000110000"; -- '0'
                                            end if;
                                        when 12 to 16 => lcd_bus <= "1000100000"; -- Spaces
                                        when others => lcd_bus <= "1000100000"; -- Space for other cases
                                    end case;

                                -- Mode 4: Instruction + Cycle Count (lower 32 bits)
                                when 4 =>
                                    case char is
                                        when 1 => lcd_bus <= "1001001001"; -- 'I'
                                        when 2 => lcd_bus <= "1001001110"; -- 'N'
                                        when 3 => lcd_bus <= "1000111010"; -- ':'
                                        when 4 => lcd_bus <= hex_to_lcd(std_logic_vector(instruction_count(31 downto 28)));
                                        when 5 => lcd_bus <= hex_to_lcd(std_logic_vector(instruction_count(27 downto 24)));
                                        when 6 => lcd_bus <= hex_to_lcd(std_logic_vector(instruction_count(23 downto 20)));
                                        when 7 => lcd_bus <= hex_to_lcd(std_logic_vector(instruction_count(19 downto 16)));
                                        when 8 => lcd_bus <= hex_to_lcd(std_logic_vector(instruction_count(15 downto 12)));
                                        when 9 => lcd_bus <= hex_to_lcd(std_logic_vector(instruction_count(11 downto 8)));
                                        when 10 => lcd_bus <= hex_to_lcd(std_logic_vector(instruction_count(7 downto 4)));
                                        when 11 => lcd_bus <= hex_to_lcd(std_logic_vector(instruction_count(3 downto 0)));
                                        when 12 to 16 => lcd_bus <= "1000100000"; -- Spaces
                                        when others => lcd_bus <= "1000100000"; -- Space for other cases
                                    end case;

                                -- Mode 5: Real-time Clock (with copied signals)
                                when 5 =>
                                    case char is
                                        when 1 => lcd_bus <= "1001010100"; -- 'T'
                                        when 2 => lcd_bus <= hex_to_lcd(std_logic_vector(lcd_hours(7 downto 4))); -- Hours tens
                                        when 3 => lcd_bus <= hex_to_lcd(std_logic_vector(lcd_hours(3 downto 0))); -- Hours ones
                                        when 4 => lcd_bus <= "1000111010"; -- ':'
                                        when 5 => lcd_bus <= hex_to_lcd(std_logic_vector(lcd_minutes(7 downto 4))); -- Minutes tens
                                        when 6 => lcd_bus <= hex_to_lcd(std_logic_vector(lcd_minutes(3 downto 0))); -- Minutes ones
                                        when 7 => lcd_bus <= "1000111010"; -- ':'
                                        when 8 => lcd_bus <= hex_to_lcd(std_logic_vector(lcd_seconds(7 downto 4))); -- Seconds tens
                                        when 9 => lcd_bus <= hex_to_lcd(std_logic_vector(lcd_seconds(3 downto 0))); -- Seconds ones
                                        when 10 to 16 => lcd_bus <= "1000100000"; -- Spaces
                                        when others => lcd_bus <= "1000100000"; -- Space
                                    end case;

                                when others =>
                                    lcd_bus <= "1000100000"; -- Space
                            end case;

                        -- Move cursor to line 2
                        when 17 => lcd_bus <= "0011000000";

                        -- Line 2 display
                        when 18 to 33 =>
                            case display_mode is
                                -- Mode 0: Current Instruction
                                when 0 =>
                                    case char is
                                        when 18 => lcd_bus <= "1001001001"; -- 'I'
                                        when 19 => lcd_bus <= "1001001110"; -- 'N'
                                        when 20 => lcd_bus <= "1000111010"; -- ':'
                                        when 21 => lcd_bus <= hex_to_lcd(current_instruction(31 downto 28));
                                        when 22 => lcd_bus <= hex_to_lcd(current_instruction(27 downto 24));
                                        when 23 => lcd_bus <= hex_to_lcd(current_instruction(23 downto 20));
                                        when 24 => lcd_bus <= hex_to_lcd(current_instruction(19 downto 16));
                                        when 25 => lcd_bus <= hex_to_lcd(current_instruction(15 downto 12));
                                        when 26 => lcd_bus <= hex_to_lcd(current_instruction(11 downto 8));
                                        when 27 => lcd_bus <= hex_to_lcd(current_instruction(7 downto 4));
                                        when 28 => lcd_bus <= hex_to_lcd(current_instruction(3 downto 0));
                                        when 29 to 33 => lcd_bus <= "1000100000"; -- Spaces
                                        when others => lcd_bus <= "1000100000"; -- Space for other cases
                                    end case;

                                -- Mode 1: Memory Data
                                when 1 =>
                                    case char is
                                        when 18 => lcd_bus <= "1001001101"; -- 'M'
                                        when 19 => lcd_bus <= "1001000100"; -- 'D'
                                        when 20 => lcd_bus <= "1000111010"; -- ':'
                                        when 21 => lcd_bus <= hex_to_lcd(mem_rdata(31 downto 28));
                                        when 22 => lcd_bus <= hex_to_lcd(mem_rdata(27 downto 24));
                                        when 23 => lcd_bus <= hex_to_lcd(mem_rdata(23 downto 20));
                                        when 24 => lcd_bus <= hex_to_lcd(mem_rdata(19 downto 16));
                                        when 25 => lcd_bus <= hex_to_lcd(mem_rdata(15 downto 12));
                                        when 26 => lcd_bus <= hex_to_lcd(mem_rdata(11 downto 8));
                                        when 27 => lcd_bus <= hex_to_lcd(mem_rdata(7 downto 4));
                                        when 28 => lcd_bus <= hex_to_lcd(mem_rdata(3 downto 0));
                                        when 29 to 33 => lcd_bus <= "1000100000"; -- Spaces
                                        when others => lcd_bus <= "1000100000"; -- Space for other cases
                                    end case;

                                -- Mode 2: Write Strobe + Status
                                when 2 =>
                                    case char is
                                        when 18 => lcd_bus <= "1001010111"; -- 'W'
                                        when 19 => lcd_bus <= "1001010011"; -- 'S'
                                        when 20 => lcd_bus <= "1000111010"; -- ':'
                                        when 21 => lcd_bus <= hex_to_lcd(mem_wstrb);
                                        when 22 => lcd_bus <= "1000100000"; -- Space
                                        when 23 => lcd_bus <= "1001010100"; -- 'T'
                                        when 24 => lcd_bus <= "1000111010"; -- ':'
                                        when 25 =>
                                            if cpu_trap = '1' then
                                                lcd_bus <= "1000110001"; -- '1'
                                            else
                                                lcd_bus <= "1000110000"; -- '0'
                                            end if;
                                        when 26 to 33 => lcd_bus <= "1000100000"; -- Spaces
                                        when others => lcd_bus <= "1000100000"; -- Space for other cases
                                    end case;

                                -- Mode 3: Trap + Execution State
                                when 3 =>
                                    case char is
                                        when 18 => lcd_bus <= "1001010100"; -- 'T'
                                        when 19 => lcd_bus <= "1000111010"; -- ':'
                                        when 20 =>
                                            if cpu_trap = '1' then
                                                lcd_bus <= "1000110001"; -- '1'
                                            else
                                                lcd_bus <= "1000110000"; -- '0'
                                            end if;
                                        when 21 => lcd_bus <= "1000100000"; -- Space
                                        when 22 => lcd_bus <= "1001000101"; -- 'E'
                                        when 23 => lcd_bus <= "1000111010"; -- ':'
                                        when 24 =>
                                            case execution_state is
                                                when HALTED => lcd_bus <= "1001001000"; -- 'H'
                                                when RUNNING => lcd_bus <= "1001010010"; -- 'R'
                                                when STEPPING => lcd_bus <= "1001010011"; -- 'S'
                                                when others => lcd_bus <= "1000100000"; -- Space
                                            end case;
                                        when 25 to 33 => lcd_bus <= "1000100000"; -- Spaces
                                        when others => lcd_bus <= "1000100000"; -- Space for other cases
                                    end case;

                                -- Mode 4: Cycle Count (lower 32 bits)
                                when 4 =>
                                    case char is
                                        when 18 => lcd_bus <= "1001000011"; -- 'C'
                                        when 19 => lcd_bus <= "1001011001"; -- 'Y'
                                        when 20 => lcd_bus <= "1000111010"; -- ':'
                                        when 21 => lcd_bus <= hex_to_lcd(std_logic_vector(cycle_count(31 downto 28)));
                                        when 22 => lcd_bus <= hex_to_lcd(std_logic_vector(cycle_count(27 downto 24)));
                                        when 23 => lcd_bus <= hex_to_lcd(std_logic_vector(cycle_count(23 downto 20)));
                                        when 24 => lcd_bus <= hex_to_lcd(std_logic_vector(cycle_count(19 downto 16)));
                                        when 25 => lcd_bus <= hex_to_lcd(std_logic_vector(cycle_count(15 downto 12)));
                                        when 26 => lcd_bus <= hex_to_lcd(std_logic_vector(cycle_count(11 downto 8)));
                                        when 27 => lcd_bus <= hex_to_lcd(std_logic_vector(cycle_count(7 downto 4)));
                                        when 28 => lcd_bus <= hex_to_lcd(std_logic_vector(cycle_count(3 downto 0)));
                                        when 29 to 33 => lcd_bus <= "1000100000"; -- Spaces
                                        when others => lcd_bus <= "1000100000"; -- Space for other cases
                                    end case;

                                -- Mode 5: Instructions Per Second (show in millions, e.g., "200M IPS")
                                when 5 =>
                                    case char is
                                        when 18 => lcd_bus <= "1001001001"; -- 'I'
                                        when 19 => lcd_bus <= "1001010000"; -- 'P'
                                        when 20 => lcd_bus <= "1001010011"; -- 'S'
                                        when 21 => lcd_bus <= "1000111010"; -- ':'
                                        -- Display IPS in millions (divide by 1,000,000)
                                        when 22 => -- Hundreds of millions digit
                                            case (to_integer(ips_current) / 100000000) is
                                                when 0 => lcd_bus <= "1000100000"; -- Space if zero
                                                when 1 => lcd_bus <= "1000110001"; -- '1'
                                                when 2 => lcd_bus <= "1000110010"; -- '2'
                                                when 3 => lcd_bus <= "1000110011"; -- '3'
                                                when 4 => lcd_bus <= "1000110100"; -- '4'
                                                when others => lcd_bus <= "1000110000"; -- '0'
                                            end case;
                                        when 23 => -- Tens of millions digit
                                            case ((to_integer(ips_current) mod 100000000) / 10000000) is
                                                when 0 =>
                                                    if to_integer(ips_current) >= 100000000 then
                                                        lcd_bus <= "1000110000"; -- '0'
                                                    else
                                                        lcd_bus <= "1000100000"; -- Space if leading zero
                                                    end if;
                                                when 1 => lcd_bus <= "1000110001"; -- '1'
                                                when 2 => lcd_bus <= "1000110010"; -- '2'
                                                when 3 => lcd_bus <= "1000110011"; -- '3'
                                                when 4 => lcd_bus <= "1000110100"; -- '4'
                                                when 5 => lcd_bus <= "1000110101"; -- '5'
                                                when 6 => lcd_bus <= "1000110110"; -- '6'
                                                when 7 => lcd_bus <= "1000110111"; -- '7'
                                                when 8 => lcd_bus <= "1000111000"; -- '8'
                                                when 9 => lcd_bus <= "1000111001"; -- '9'
                                                when others => lcd_bus <= "1000110000"; -- '0'
                                            end case;
                                        when 24 => -- Millions digit
                                            case ((to_integer(ips_current) mod 10000000) / 1000000) is
                                                when 0 =>
                                                    if to_integer(ips_current) >= 10000000 then
                                                        lcd_bus <= "1000110000"; -- '0'
                                                    else
                                                        lcd_bus <= "1000100000"; -- Space if leading zero
                                                    end if;
                                                when 1 => lcd_bus <= "1000110001"; -- '1'
                                                when 2 => lcd_bus <= "1000110010"; -- '2'
                                                when 3 => lcd_bus <= "1000110011"; -- '3'
                                                when 4 => lcd_bus <= "1000110100"; -- '4'
                                                when 5 => lcd_bus <= "1000110101"; -- '5'
                                                when 6 => lcd_bus <= "1000110110"; -- '6'
                                                when 7 => lcd_bus <= "1000110111"; -- '7'
                                                when 8 => lcd_bus <= "1000111000"; -- '8'
                                                when 9 => lcd_bus <= "1000111001"; -- '9'
                                                when others => lcd_bus <= "1000110000"; -- '0'
                                            end case;
                                        when 25 => lcd_bus <= "1001001101"; -- 'M' for millions
                                        when 26 to 28 => lcd_bus <= "1000100000"; -- Spaces
                                        when 29 to 33 => lcd_bus <= "1000100000"; -- Spaces
                                        when others => lcd_bus <= "1000100000"; -- Space for other cases
                                    end case;

                                when others =>
                                    lcd_bus <= "1000100000"; -- Space
                            end case;

                        when others =>
                            char := 0;
                            lcd_enable <= '0';
                    end case;

                    if char < 33 then
                        char := char + 1;
                    else
                        char := 0;
                    end if;
                end if;
            else
                lcd_enable <= '0';
            end if;
        end if;
    end process;

    -- HEX Display (shows Program Counter)
    hex_disp : hex_display
        port map (
            clk => clk,
            resetn => resetn,
            value => program_counter,
            hex0 => HEX0,
            hex1 => HEX1,
            hex2 => HEX2,
            hex3 => HEX3,
            hex4 => HEX4,
            hex5 => HEX5,
            hex6 => HEX6,
            hex7 => HEX7
        );

    -- Green LED Debug Indicators (moved from red LEDs)
    LEDG(0) <= '1' when execution_state = RUNNING else '0';    -- Running indicator
    LEDG(1) <= '1' when execution_state = HALTED else '0';     -- Halted indicator
    LEDG(2) <= '1' when execution_state = STEPPING else '0';   -- Step mode indicator
    LEDG(3) <= cpu_trap;                                       -- Trap indicator
    LEDG(4) <= mem_valid;                                      -- Memory access active (was LEDR(4))
    LEDG(5) <= mem_ready;                                      -- Memory ready (was LEDR(5))
    LEDG(6) <= mem_instr;                                      -- Instruction fetch (was LEDR(6))
    LEDG(8 downto 7) <= (others => '0');                      -- Unused green LEDs

    -- Red LEDs: Knight Rider pattern driven by firmware memory-mapped I/O
    LEDR <= led_register;  -- Connected to LED register at address 0xFFFF0060

    -- LCD power control
    LCD_ON <= '1';
    LCD_BLON <= '1';

end architecture;