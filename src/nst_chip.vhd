--
-- Mechafinch
-- NST Handheld Project
--
-- nst_chip
-- Entity representing the fpga board. This will instantiate components (cpu, spi driver, etc) and
-- map IO pins
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.nst_types.all;

entity nst_chip is
	port (
		-- GPIO
		memory_bus_IN:		in std_logic_vector(15 downto 0);
		memory_bus_OUT:		out std_logic_vector(15 downto 0);
		memory_bus_OE:		out std_logic;
		mem_addr_low_en:	out std_logic;
		mem_addr_high_en:	out std_logic;
		memory_read:		out std_logic;
		memory_write:		out std_logic;
		
		spi_sel:	out std_logic_vector(2 downto 0);
		spi_cd:		out std_logic;
		spi_cido:	in std_logic;
		spi_codi:	out std_logic;
		spi_clk:	out std_logic;
		
		keypad_sel:		out std_logic_vector(4 downto 0);
		keypad_data:	in std_logic;
		
		leds:	out std_logic_vector(3 downto 0);
		btn_1:	in std_logic;
		btn_2:	in std_logic;
		
		-- Device Signals
		-- PLL clocks
		device_exec_clk:	in std_logic;	-- 64 MHz	TBD based on cpu performance
		device_memory_clk:	in std_logic;	-- 4 MHz	TBD based on breadboard memory performance, potentially up to 16 MHz
		device_spi_clk:		in std_logic	-- 8 MHz	ILI9341 max spi clock is 10 MHz
	);
end nst_chip;

architecture a1 of nst_chip is
	signal blink_counter: std_logic_vector(19 downto 0) := (others => '0');
begin
	-- blink led1
	leds(3 downto 1)	<= "000";
	leds(0)				<= '1' when blink_counter(19) = '1' else '0';
	
	blink: process (device_memory_clk) begin
		if rising_edge(device_memory_clk) then
			blink_counter <= std_logic_vector(unsigned(blink_counter) + 1);
		end if;
	end process blink;

	-- just keep things off until we use them
	-- to be handled by memory interface
	memory_bus_out		<= (others => '0');
	memory_bus_oe		<= '0';
	mem_addr_low_en		<= '0';
	mem_addr_high_en	<= '0';
	memory_read			<= '0';
	memory_write		<= '0';
	
	-- to be handled by SPI interface
	spi_sel				<= "000";
	spi_cd				<= '0';
	spi_codi			<= '0';
	spi_clk				<= '0';
	
	-- to be handled by keypad interface
	keypad_sel			<= "00000";
end a1;