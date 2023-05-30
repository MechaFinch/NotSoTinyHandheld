--
-- Mechafinch
-- NST Handheld Project
--
-- memory_test
-- Tests the system with a memory model attached
--

library ieee;
use ieee.std_logic_1164.all;

entity memory_test is
end memory_test;

architecture tb of memory_test is
	-- chip signals
	signal memory_bus_IN:	std_logic_vector(15 downto 0);
	signal memory_bus_OUT:	std_logic_vector(15 downto 0);
	signal memory_bus_OE:	std_logic_vector(15 downto 0);
	
	signal mem_addr_low_clk:	std_logic;
	signal mem_addr_high_clk:	std_logic;
	signal memory_read:			std_logic;
	signal memory_write:		std_logic;
	
	signal spi_sel:		std_logic_vector(2 downto 0);
	signal spi_cd:		std_logic;
	signal spi_cido:	std_logic;
	signal spi_codi:	std_logic;
	signal spi_clk:		std_logic;
	
	signal keypad_sel:	std_logic_vector(4 downto 0);
	signal keypad_data:	std_logic;
	
	signal leds:	std_logic_vector(3 downto 0);
	signal btn_1:	std_logic;
	signal btn_2:	std_logic;
	
	signal device_exec_clk:		std_logic := '0';
	signal device_ram_clk:		std_logic := '0';
	signal device_spi_clk:		std_logic := '0';
	signal device_10khz_clk:	std_logic := '0';
	
	constant exec_period:	time := 15625 ps;	-- 64 MHz
	constant ram_period:	time := 13 ns; --250 ns;		-- 4 MHz
	constant spi_period:	time := 125 ns;		-- 8 MHz
	constant tenkhz_period:	time := 100 us;		-- 10 kHz
	constant stim_period:	time := 1 us;
begin
	-- signals to manage
	device_exec_clk		<= not device_exec_clk after exec_period / 2;
	device_ram_clk		<= not device_ram_clk after ram_period / 2;
	device_spi_clk		<= not device_spi_clk after spi_period / 2;
	device_10khz_clk	<= not device_10khz_clk after tenkhz_period / 2;
	
	stim: process begin
		spi_cido	<= '0';
		keypad_data	<= '0';
		btn_1		<= '0';
		btn_2		<= '0';
		
		wait for stim_period;
		
		assert leds = "1111" report
			"Initial address is wrong";
		
		-- select addr 0001
		keypad_data	<= '1';
		wait for stim_period / 2;
		keypad_data <= '0';
		wait for stim_period / 2;
		
		assert leds = "1110" report
			"1st address increment failed";
		
		-- switch to data
		spi_cido <= '1';
		wait for stim_period / 2;
		spi_cido <= '0';
		wait for stim_period / 2;
		
		assert leds = "1111" report
			"Initial data is wrong";
		
		-- select data 0010
		keypad_data	<= '1';
		wait for stim_period / 2;
		keypad_data <= '0';
		wait for stim_period / 2;
		keypad_data	<= '1';
		wait for stim_period / 2;
		keypad_data <= '0';
		wait for stim_period / 2;
		
		assert leds = "1101" report
			"1st data increment failed";
		
		-- write
		btn_2 <= '1';
		wait for stim_period / 2;
		btn_2 <= '0';
		wait for stim_period / 2;
		
		-- select data 0100
		keypad_data	<= '1';
		wait for stim_period / 2;
		keypad_data <= '0';
		wait for stim_period / 2;
		keypad_data	<= '1';
		wait for stim_period / 2;
		keypad_data <= '0';
		wait for stim_period / 2;
		
		assert leds = "1011" report
			"2nd data increment failed";
		
		-- switch to addr
		spi_cido <= '1';
		wait for stim_period / 2;
		spi_cido <= '0';
		wait for stim_period / 2;
		
		assert leds = "1110" report
			"1st address switch failed";
		
		-- select addr 0010
		keypad_data	<= '1';
		wait for stim_period / 2;
		keypad_data <= '0';
		wait for stim_period / 2;
		
		assert leds = "1101" report
			"2nd address increment failed";
		
		-- write
		btn_2 <= '1';
		wait for stim_period / 2;
		btn_2 <= '0';
		wait for stim_period / 2;
		
		-- select addr 0001
		keypad_data	<= '1';
		wait for stim_period / 2;
		keypad_data <= '0';
		wait for stim_period / 2;
		keypad_data	<= '1';
		wait for stim_period / 2;
		keypad_data <= '0';
		wait for stim_period / 2;
		keypad_data	<= '1';
		wait for stim_period / 2;
		keypad_data <= '0';
		wait for stim_period / 2;
		keypad_data	<= '1';
		wait for stim_period / 2;
		keypad_data <= '0';
		wait for stim_period / 2;
		keypad_data	<= '1';
		wait for stim_period / 2;
		keypad_data <= '0';
		wait for stim_period / 2;
		keypad_data	<= '1';
		wait for stim_period / 2;
		keypad_data <= '0';
		wait for stim_period / 2;
		keypad_data	<= '1';
		wait for stim_period / 2;
		keypad_data <= '0';
		wait for stim_period / 2;
		keypad_data	<= '1';
		wait for stim_period / 2;
		keypad_data <= '0';
		wait for stim_period / 2;
		keypad_data	<= '1';
		wait for stim_period / 2;
		keypad_data <= '0';
		wait for stim_period / 2;
		keypad_data	<= '1';
		wait for stim_period / 2;
		keypad_data <= '0';
		wait for stim_period / 2;
		keypad_data	<= '1';
		wait for stim_period / 2;
		keypad_data <= '0';
		wait for stim_period / 2;
		keypad_data	<= '1';
		wait for stim_period / 2;
		keypad_data <= '0';
		wait for stim_period / 2;
		keypad_data	<= '1';
		wait for stim_period / 2;
		keypad_data <= '0';
		wait for stim_period / 2;
		keypad_data	<= '1';
		wait for stim_period / 2;
		keypad_data <= '0';
		wait for stim_period / 2;
		keypad_data	<= '1';
		wait for stim_period / 2;
		keypad_data <= '0';
		wait for stim_period / 2;
		
		assert leds = "1110" report
			"3rd address increment failed";
		
		-- switch to data
		spi_cido <= '1';
		wait for stim_period / 2;
		spi_cido <= '0';
		wait for stim_period / 2;
		
		assert leds = "1011" report
			"1st data switch failed";
		
		-- read data 0010
		btn_1 <= '1';
		wait for stim_period / 2;
		btn_1 <= '0';
		wait for stim_period / 2;
		
		assert leds = "1101" report
			"1st read failed";
		
		-- switch to addr
		spi_cido <= '1';
		wait for stim_period / 2;
		spi_cido <= '0';
		wait for stim_period / 2;
		
		assert leds = "1110" report
			"2nd address switch failed";
		
		-- select addr 0010
		keypad_data	<= '1';
		wait for stim_period / 2;
		keypad_data <= '0';
		wait for stim_period / 2;
		
		assert leds = "1101" report
			"4th address increment failed";
		
		-- switch to data
		spi_cido <= '1';
		wait for stim_period / 2;
		spi_cido <= '0';
		wait for stim_period / 2;
		
		assert leds = "1101" report
			"2nd data switch failed";
		
		-- read data 0100
		btn_1 <= '1';
		wait for stim_period / 2;
		btn_1 <= '0';
		wait for stim_period / 2;
		
		assert leds = "1011" report
			"2nd read failed";
	
		wait;
	end process;

	-- chip instance
	chip: entity work.nst_chip
		port map (
			memory_bus_IN	=> memory_bus_IN,
			memory_bus_OUT	=> memory_bus_OUT,
			memory_bus_OE	=> memory_bus_OE,
			
			mem_addr_low_clk	=> mem_addr_low_clk,
			mem_addr_high_clk	=> mem_addr_high_clk,
			memory_read			=> memory_read,
			memory_write		=> memory_write,
			
			spi_sel		=> spi_sel,
			spi_cd		=> spi_cd,
			spi_cido	=> spi_cido,
			spi_codi	=> spi_codi,
			spi_clk		=> spi_clk,
			
			keypad_sel	=> keypad_sel,
			keypad_data	=> keypad_data,
			
			leds	=> leds,
			btn_1	=> btn_1,
			btn_2	=> btn_2,
			
			device_exec_clk		=> device_exec_clk,
			device_ram_clk		=> device_ram_clk,
			device_spi_clk		=> device_spi_clk,
			device_10khz_clk	=> device_10khz_clk
		);
	
	-- memory instance
	mem: entity work.external_mem
		port map (
			memory_bus_IN	=> memory_bus_IN,
			memory_bus_OUT	=> memory_bus_OUT,
			memory_bus_OE	=> memory_bus_OE,
			
			mem_addr_low_clk	=> mem_addr_low_clk,
			mem_addr_high_clk	=> mem_addr_high_clk,
			memory_read			=> memory_read,
			memory_write		=> memory_write
		);
end tb;