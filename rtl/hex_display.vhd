-- Hex Display Driver
-- Displays 32-bit value on 8 seven-segment displays

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity hex_display is
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
end entity;

architecture rtl of hex_display is

    function hex_to_7seg(hex_value : std_logic_vector(3 downto 0)) return std_logic_vector is
    begin
        case hex_value is
            when "0000" => return "1000000"; -- 0
            when "0001" => return "1111001"; -- 1
            when "0010" => return "0100100"; -- 2
            when "0011" => return "0110000"; -- 3
            when "0100" => return "0011001"; -- 4
            when "0101" => return "0010010"; -- 5
            when "0110" => return "0000010"; -- 6
            when "0111" => return "1111000"; -- 7
            when "1000" => return "0000000"; -- 8
            when "1001" => return "0010000"; -- 9
            when "1010" => return "0001000"; -- A
            when "1011" => return "0000011"; -- b
            when "1100" => return "1000110"; -- C
            when "1101" => return "0100001"; -- d
            when "1110" => return "0000110"; -- E
            when "1111" => return "0001110"; -- F
            when others => return "1111111"; -- blank
        end case;
    end function;

    signal value_reg : std_logic_vector(31 downto 0);

begin

    process(clk, resetn)
    begin
        if resetn = '0' then
            value_reg <= (others => '0');
        elsif rising_edge(clk) then
            value_reg <= value;
        end if;
    end process;

    -- Display each nibble on a 7-segment display
    hex0 <= hex_to_7seg(value_reg(3 downto 0));
    hex1 <= hex_to_7seg(value_reg(7 downto 4));
    hex2 <= hex_to_7seg(value_reg(11 downto 8));
    hex3 <= hex_to_7seg(value_reg(15 downto 12));
    hex4 <= hex_to_7seg(value_reg(19 downto 16));
    hex5 <= hex_to_7seg(value_reg(23 downto 20));
    hex6 <= hex_to_7seg(value_reg(27 downto 24));
    hex7 <= hex_to_7seg(value_reg(31 downto 28));

end architecture;