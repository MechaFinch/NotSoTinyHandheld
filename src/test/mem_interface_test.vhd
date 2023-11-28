--
-- NST Handheld Project
--
-- mem_interface_test
-- Testbed for the memory manager 
--

library ieee;
use ieee.std_logic_1164.all;
use work.nst_types.all;

entity mem_interface_test is
end mem_interface_test;

architecture tb of mem_interfae_test is
	-- interface signals
	signal memory_bus_IN:		std_logic_vector(15 downto 0) := x"0000";
	signal memory_bus_OUT:		std_logic_vector(15 downto 0);
	signal memory_bus_OE:		std_logic;
	signal mem_addr_low_clk:	std_logic;
	signal mem_addr_high_clk:	std_logic;
	signal memory_read:			std_logic;
	signal memory_write:		std_logic;
	
	signal spi_sel:		std_logic_vector(2 downto 0);
	signal spi_cd:		std_logic;
	signal spi_cido:	std_logic := '0';
	signal spi_codi:	std_logic;
	signal spi_clk:		std_logic;
	
	signal keypad_sel:	std_logic_vector(4 downto 0);
	signal keypad_data:	std_logic := '0';
	
	signal leds:	std_logic_vector(3 downto 0);
	signal btn_1:	std_logic := '0';
	signal btn_2:	std_logic := '0';
	
	signal device_exec_clk:	std_logic := '0';
	signal device_mem_clk:	std_logic := '0';
	signal device_spi_clk:	std_logic := '0';
	
	signal irb_address:	nst_dword_t := x"00000000";
	signal irb_data:	icache_block_data_t;
	signal irb_ready:	std_logic;
	
	signal memop_address:	nst_dword_t := x"00000000";
	signal memop_data_in:	bulk_data_t := (
		x"00", x"00", x"00", x"00", x"00",
		x"00", x"00", x"00", x"00", x"00",
		x"00", x"00", x"00", x"00", x"00",
		x"00", x"00", x"00", x"00", x"00"
	);
	signal memop_data_out:	bulk_data_t;
	signal memop_size:		integer range 1 to 20 := 1;
	signal memop_read:		std_logic := '0';
	signal memop_write:		std_logic := '0';
	signal memop_ready:		std_logic;
	
	signal spi_interrupt:		std_logic;
	signal keypad_interrupt:	std_logic;
	signal boundary_fault:		std_logic;
begin
	-- clocks (arbitrary values)
	device_exec_clk	<= not device_exec_clk after 10 ns;
	device_mem_clk	<= not device_mem_clk after 20 ns;
	device_spi_clk	<= not device_spi_clk after 40 ns;
	
	-- memory manager
	manager: entity work.nst_memory_manager
		port map (
			memory_bus_IN		=> memory_bus_IN,
			memory_bus_OUT		=> memory_bus_OUT,
			memory_bus_OE		=> memory_bus_OE,
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
			
			device_exec_clk	=> device_exec_clk,
			device_mem_clk	=> device_mem_clk,
			device_spi_clk	=> device_spi_clk,
			
			irb_address	=> ird_address,
			irb_data	=> irb_data,
			irb_ready	=> irb_ready,
			
			memop_address	=> memop_address,
			memop_data_in	=> memop_data_in,
			memop_data_out	=> memop_data_out,
			memop_size		=> memop_size,
			memop_read		=> memop_read,
			memop_write		=> memop_write,
			memop_ready		=> memop_ready,
			
			spi_interrupt		=> spi_interrupt,
			keypad_interrupt	=> keypad_interrupt,
			boundary_fault		=> boundary_fault
		);
end tb;