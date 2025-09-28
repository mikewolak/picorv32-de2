-- 4-MIF Memory Test Controller
-- Tests the new 4-symbol MIF memory controller with comprehensive write/read validation
-- Uses same LCD approach as proven memory_test_simple.vhd

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity memory_test_4mif is
    port (
        -- Clock and Reset
        CLOCK_50 : in std_logic;
        KEY : in std_logic_vector(3 downto 0);

        -- Switches for write control
        SW : in std_logic_vector(17 downto 0);

        -- LEDs for status
        LEDR : out std_logic_vector(17 downto 0);

        -- 7-Segment Displays (32-bit address)
        HEX0 : out std_logic_vector(6 downto 0);
        HEX1 : out std_logic_vector(6 downto 0);
        HEX2 : out std_logic_vector(6 downto 0);
        HEX3 : out std_logic_vector(6 downto 0);
        HEX4 : out std_logic_vector(6 downto 0);
        HEX5 : out std_logic_vector(6 downto 0);
        HEX6 : out std_logic_vector(6 downto 0);
        HEX7 : out std_logic_vector(6 downto 0);

        -- LCD Interface
        LCD_DATA : out std_logic_vector(7 downto 0);
        LCD_RW   : out std_logic;
        LCD_EN   : out std_logic;
        LCD_RS   : out std_logic;
        LCD_ON   : out std_logic;
        LCD_BLON : out std_logic;

        -- GPIO (unused)
        GPIO_0 : inout std_logic_vector(35 downto 0);
        GPIO_1 : inout std_logic_vector(35 downto 0)
    );
end entity;

architecture rtl of memory_test_4mif is
    -- 4-MIF Memory controller component
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

    -- LCD controller - same as working example
    component lcd_controller is
        port (
            clk : in std_logic;
            reset_n : in std_logic;
            lcd_enable : in std_logic;
            lcd_bus : in std_logic_vector(9 downto 0);
            busy : out std_logic;
            rw, rs, e : out std_logic;
            lcd_data : out std_logic_vector(7 downto 0)
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

    -- Clock signals
    signal clk : std_logic;
    signal resetn : std_logic;

    -- LCD clock divider (50MHz / 3 = ~16.67MHz)
    signal lcd_clk : std_logic := '0';
    signal clk_div_counter : integer range 0 to 2 := 0;

    -- Memory interface signals
    signal mem_valid : std_logic := '1';  -- Always active
    signal mem_ready : std_logic;
    signal mem_instr : std_logic := '0';  -- Always data access
    signal mem_wstrb : std_logic_vector(3 downto 0);
    signal mem_wdata : std_logic_vector(31 downto 0);
    signal mem_addr : std_logic_vector(31 downto 0) := (others => '0');
    signal mem_rdata : std_logic_vector(31 downto 0);

    -- Control signals
    signal current_address : unsigned(31 downto 0) := (others => '0');
    signal write_mode : std_logic;
    signal write_strobe_pattern : std_logic_vector(2 downto 0);
    signal write_data_input : std_logic_vector(7 downto 0);

    -- Button debouncing
    signal key_prev : std_logic_vector(3 downto 0) := (others => '1');
    signal key_pressed : std_logic_vector(3 downto 0);

    -- LCD signals - same as working example
    signal lcd_enable : std_logic;
    signal lcd_bus : std_logic_vector(9 downto 0);
    signal lcd_busy : std_logic;

    -- Test status signals
    signal test_data_written : std_logic_vector(31 downto 0) := (others => '0');
    signal test_passed : std_logic := '0';
    signal write_performed : std_logic := '0';

    -- Convert hex nibble to ASCII - same format as working example
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
            when others => lcd_val := "1000111111"; -- '?'
        end case;
        return lcd_val;
    end function;

begin
    -- Clock and reset
    clk <= CLOCK_50;
    resetn <= KEY(0);  -- KEY0 = reset

    -- LCD Clock Divider Process (50MHz / 2 = 25MHz) - Testing faster refresh
    lcd_clk_divider : process(clk)
    begin
        if rising_edge(clk) then
            if clk_div_counter = 1 then
                clk_div_counter <= 0;
                lcd_clk <= not lcd_clk;
            else
                clk_div_counter <= clk_div_counter + 1;
            end if;
        end if;
    end process;

    -- Switch assignments and write control
    write_strobe_pattern <= SW(17 downto 15);  -- SW[17:15] for write strobes (bytes 3:1)
    write_data_input <= SW(7 downto 0);        -- SW[7:0] for data input
    write_mode <= '1' when (write_strobe_pattern /= "000" or SW(14) = '1') else '0';  -- Include SW[14] for byte 0

    -- Memory control signals
    mem_addr <= std_logic_vector(current_address);

    -- Write data (test pattern: replicate 8-bit input across all bytes for testing)
    mem_wdata <= write_data_input & write_data_input & write_data_input & write_data_input;

    -- Write strobe generation: SW[17:15] -> mem_wstrb[3:1], SW[14] -> mem_wstrb[0]
    -- This allows testing ALL PicoRV32 write strobe combinations with 4-MIF controller
    mem_wstrb <= write_strobe_pattern & SW(14) when (write_mode = '1' and key_pressed(1) = '1') else "0000";

    -- Button edge detection
    button_debounce : process(clk)
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                key_prev <= (others => '1');
                key_pressed <= (others => '0');
            else
                key_prev <= KEY;
                key_pressed <= key_prev and not KEY;
            end if;
        end if;
    end process;

    -- Address and write control
    address_control : process(clk)
        variable write_pending : std_logic := '0';
        variable write_counter : integer range 0 to 3 := 0;
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                current_address <= (others => '0');
                write_pending := '0';
                write_counter := 0;
                test_data_written <= (others => '0');
                test_passed <= '0';
                write_performed <= '0';
            else
                -- Handle write operation timing
                if write_pending = '1' then
                    if write_counter > 0 then
                        write_counter := write_counter - 1;
                    else
                        write_pending := '0';
                    end if;
                end if;

                -- Test validation: check if written bytes match what we intended to write (only after a write)
                if write_pending = '0' and mem_ready = '1' and write_performed = '1' then
                    -- Check if all written bytes match
                    if ((mem_wstrb(0) = '0') or (mem_rdata(7 downto 0) = test_data_written(7 downto 0))) and
                       ((mem_wstrb(1) = '0') or (mem_rdata(15 downto 8) = test_data_written(15 downto 8))) and
                       ((mem_wstrb(2) = '0') or (mem_rdata(23 downto 16) = test_data_written(23 downto 16))) and
                       ((mem_wstrb(3) = '0') or (mem_rdata(31 downto 24) = test_data_written(31 downto 24))) then
                        test_passed <= '1';
                    else
                        test_passed <= '0';
                    end if;
                end if;

                -- Handle button presses
                if key_pressed(3) = '1' then  -- KEY3 = decrement
                    if current_address >= 4 then
                        current_address <= current_address - 4;
                    end if;
                elsif key_pressed(2) = '1' then  -- KEY2 = increment
                    current_address <= current_address + 4;
                elsif key_pressed(1) = '1' and write_mode = '1' and write_pending = '0' then  -- KEY1 = write
                    write_pending := '1';
                    write_counter := 3;  -- Hold write for a few cycles
                    test_data_written <= mem_wdata;  -- Remember what we wrote for validation
                    write_performed <= '1';  -- Mark that we've performed a write operation
                end if;
            end if;
        end if;
    end process;

    -- 4-MIF Memory controller instance
    memory_ctrl : mem_controller_4mif
        port map (
            clk => clk,
            resetn => resetn,
            mem_valid => mem_valid,
            mem_ready => mem_ready,
            mem_instr => mem_instr,
            mem_wstrb => mem_wstrb,
            mem_wdata => mem_wdata,
            mem_addr => mem_addr,
            mem_rdata => mem_rdata
        );

    -- LCD controller - same instantiation as working example
    lcd_ctrl : lcd_controller
        port map (
            clk => lcd_clk,
            reset_n => '1',  -- Same as working example
            lcd_enable => lcd_enable,
            lcd_bus => lcd_bus,
            busy => lcd_busy,
            rw => LCD_RW,
            rs => LCD_RS,
            e => LCD_EN,
            lcd_data => LCD_DATA
        );

    -- LCD display process - shows 4-MIF test results
    lcd_display : process(lcd_clk)
        variable char : integer range 0 to 35 := 0;
        variable refresh_counter : integer range 0 to 100000 := 0;
    begin
        if rising_edge(lcd_clk) then
            if lcd_busy = '0' and lcd_enable = '0' then
                -- Slow down refresh rate for LCD stability
                if refresh_counter < 100000 then
                    refresh_counter := refresh_counter + 1;
                else
                    refresh_counter := 0;
                    lcd_enable <= '1';

                    case char is
                        -- Move cursor to home (start of line 1)
                        when 0 => lcd_bus <= "0010000000";  -- Command: Return home

                        -- Line 1: Display memory data (8 hex chars) + test status
                        when 1 => lcd_bus <= hex_to_lcd(mem_rdata(31 downto 28)); -- High nibble
                        when 2 => lcd_bus <= hex_to_lcd(mem_rdata(27 downto 24));
                        when 3 => lcd_bus <= hex_to_lcd(mem_rdata(23 downto 20));
                        when 4 => lcd_bus <= hex_to_lcd(mem_rdata(19 downto 16));
                        when 5 => lcd_bus <= hex_to_lcd(mem_rdata(15 downto 12));
                        when 6 => lcd_bus <= hex_to_lcd(mem_rdata(11 downto 8));
                        when 7 => lcd_bus <= hex_to_lcd(mem_rdata(7 downto 4));
                        when 8 => lcd_bus <= hex_to_lcd(mem_rdata(3 downto 0));  -- Low nibble
                        when 9 => lcd_bus <= "1000100000"; -- Space
                        when 10 =>
                            if test_passed = '1' then
                                lcd_bus <= "1001001111"; -- 'O' for test passed
                            else
                                lcd_bus <= "1001011000"; -- 'X' for test failed
                            end if;
                        when 11 => lcd_bus <= "1000100000"; -- Space
                        when 12 => lcd_bus <= "1001011011"; -- '['
                        when 13 =>
                            if mem_ready = '1' then
                                lcd_bus <= "1001010010"; -- 'R' for memory ready
                            else
                                lcd_bus <= "1001010111"; -- 'W' for waiting
                            end if;
                        when 14 => lcd_bus <= "1001011101"; -- ']'

                        -- Move cursor to line 2 (address 0xC0)
                        when 15 => lcd_bus <= "0011000000";  -- Command: Set DDRAM address to 0x40 (line 2)

                        -- Line 2: Show 4-MIF status: "4M:x W:0000 D:AA"
                        when 16 => lcd_bus <= "1000110100"; -- '4'
                        when 17 => lcd_bus <= "1001001101"; -- 'M'
                        when 18 => lcd_bus <= "1000111010"; -- ':'
                        when 19 => lcd_bus <= hex_to_lcd(mem_wstrb); -- Write strobe pattern
                        when 20 => lcd_bus <= "1000100000"; -- Space
                        when 21 => lcd_bus <= "1001010111"; -- 'W'
                        when 22 => lcd_bus <= "1000111010"; -- ':'
                        when 23 =>
                            if SW(17) = '1' then
                                lcd_bus <= "1000110001"; -- '1'
                            else
                                lcd_bus <= "1000110000"; -- '0'
                            end if;
                        when 24 =>
                            if SW(16) = '1' then
                                lcd_bus <= "1000110001"; -- '1'
                            else
                                lcd_bus <= "1000110000"; -- '0'
                            end if;
                        when 25 =>
                            if SW(15) = '1' then
                                lcd_bus <= "1000110001"; -- '1'
                            else
                                lcd_bus <= "1000110000"; -- '0'
                            end if;
                        when 26 =>
                            if SW(14) = '1' then
                                lcd_bus <= "1000110001"; -- '1' (SW[14] = byte 0)
                            else
                                lcd_bus <= "1000110000"; -- '0'
                            end if;
                        when 27 => lcd_bus <= "1000100000"; -- Space
                        when 28 => lcd_bus <= "1001000100"; -- 'D'
                        when 29 => lcd_bus <= "1000111010"; -- ':'
                        when 30 => lcd_bus <= hex_to_lcd(write_data_input(7 downto 4)); -- Data input high nibble
                        when 31 => lcd_bus <= hex_to_lcd(write_data_input(3 downto 0)); -- Data input low nibble

                        when others =>
                            char := 0;  -- Reset to beginning
                            lcd_enable <= '0';
                    end case;

                    if char < 31 then
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

    -- Hex display (show current address)
    hex_disp : hex_display
        port map (
            clk => clk,
            resetn => resetn,
            value => std_logic_vector(current_address),
            hex0 => HEX0,
            hex1 => HEX1,
            hex2 => HEX2,
            hex3 => HEX3,
            hex4 => HEX4,
            hex5 => HEX5,
            hex6 => HEX6,
            hex7 => HEX7
        );

    -- LCD power control
    LCD_ON <= '1';    -- Always power on LCD
    LCD_BLON <= '1';  -- Always enable backlight

    -- LED status indicators for 4-MIF testing
    LEDR(17) <= mem_ready;   -- LED17 = memory ready
    LEDR(16) <= test_passed; -- LED16 = test validation status
    LEDR(15 downto 12) <= mem_wstrb; -- LED15-12 = Write strobe pattern
    LEDR(11 downto 8) <= mem_rdata(7 downto 4);  -- LED11-8 = Memory data high nibble
    LEDR(7 downto 4) <= mem_rdata(3 downto 0);   -- LED7-4 = Memory data low nibble
    LEDR(3 downto 0) <= SW(3 downto 0);          -- LED3-0 = Switch input

    -- Unused GPIO
    GPIO_0 <= (others => 'Z');
    GPIO_1 <= (others => 'Z');

end architecture;