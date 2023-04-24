--
-- Mechafinch
-- NST Handheld Project
--
-- blink_test
-- Test the LED blinking
--

library ieee;
use ieee.std_logic_1164.all;

entity blink_test is
end blink_test;

architecture tb of blink_test is
	signal memory_bus_OUT: std_logic_vector(15 downto 0);
	signal memory_bus_OE, mem_addr_low_en, mem_addr_high_en, memory_read, memory_write: std_logic;
	signal spi_sel: std_logic_vector(2 downto 0);
	signal spi_cd, spi_codi, spi_clk: std_logic;
	signal keypad_sel: std_logic_vector(4 downto 0);
	signal leds: std_logic_vector(3 downto 0);
	
	signal clk: std_logic := '0';
begin
	clk <= not clk after 50 ns;

	chip: entity work.nst_chip
		port map (
			memory_bus_IN		=> (others => '0'),
			memory_bus_OUT		=> memory_bus_OUT,
			memory_bus_OE		=> memory_bus_OE,
			mem_addr_low_en		=> mem_addr_low_en,
			mem_addr_high_en	=> mem_addr_high_en,
			memory_read			=> memory_read,
			memory_write		=> memory_write,
			
			spi_sel		=> spi_sel,
			spi_cd		=> spi_cd,
			spi_cido	=> '0',
			spi_codi	=> spi_codi,
			spi_clk		=> spi_clk,
			
			keypad_sel	=> keypad_sel,
			keypad_data	=> '0',
			
			leds	=> leds,
			btn_1	=> '0',
			btn_2	=> '0',
			
			device_exec_clk		=> '0',
			device_memory_clk	=> clk,
			device_spi_clk		=> '0'
		);
end tb;