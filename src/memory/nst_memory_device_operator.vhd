--
-- Mechafinch
-- NST Handheld Project
-- 
-- nst_memory_device_operator
-- Operates memory devices
--

library iee;
use ieee.std_logic_1164.all;
use work.nst_types.all;

entity nst_memory_device_operator is
	port (
		---- Device Pins & Signals ----
		-- RAM, passed to nst_ram_interface
		memory_bus_IN:		in std_logic_vector(15 downto 0);
		memory_bus_OUT:		out std_logic_vector(15 downto 0);
		memory_bus_OE:		out std_logic;
		mem_addr_low_clk:	out std_logic;
		mem_addr_high_clk:	out std_logic;
		memory_read:		out std_logic;
		memory_write:		out std_logic;
		
		-- SPI, passed to nst_spi_interface
		spi_sel:		out std_logic_vector(2 downto 0);
		spi_cd:			out std_logic;
		spi_cido:		in std_logic;
		spi_codi:		out std_logic;
		spi_clk:		out std_logic;
		spi_interrupt:	out std_logic;
		
		-- Keys, passed to nst_keypad_interface
		keypad_sel:			out std_logic_vector(4 downto 0);
		keypad_data:		in std_logic;
		keypad_interrupt:	out std_logic;
		
		-- Fireant, passed to ???
		leds:	out std_logic_vector(3 downto 0);
		btn_1:	in std_logic;
		btn_2:	in std_logic;
		
		---- Interface ----
		-- clocks
		device_exec_clk:	in std_logic;
		device_ram_clk:		in std_logic;
		device_spi_clk:		in std_logic;
		
		-- control
		device_id:		in device_id_t;
		device_addr:	in nst_dword_t;
		
		data_in:	in nst_word_t;
		data_out:	out nst_word_t;
		
		mem_read:	in std_logic;
		mem_write:	in std_logic;
		ready:	out std_logic
	);
end nst_memory_device_operator;

-- This module instantiates device interfaces and routes control signals and pins to them.

architecture a1 of nst_memory_device_operator is
	-- multiplexed signals
	ram_data_out:				nst_word_t;
	spi_data_out, key_data_out:	nst_byte_t;
	
	ram_read, spi_read, key_read,
	ram_write, spi_write, key_write: std_logic;
	
	ram_ready:	std_logic;
	
	-- spi can be controlled by either debug or cpu
	spi_address:	std_logic_vector(1 downto 0);
	spi_data_in:	nst_byte_t;
begin
	-- device selection
	sel_proc: process (all) begin
		-- output selection
		with device_id select data_out <=
			ram_data_out			when DEVICE_RAM,
			x"00" & spi_data_out	when DEVICE_SPI,
			x"00" & key_data_out	when DEVICE_KEY,
			(others => '0')			when others;
		
		with device_id select ready <=
			ram_ready	when DEVICE_RAM,
			'1'			when DEVICE_SPI,
			'1'			when DEVICE_KEY,
			'0'			when others;
		
		-- control routing
		ram_read	<= mem_read when device_id = DEVICE_RAM else '0';
		ram_write	<= mem_write when device_id = DEVICE_RAM else '0';
		
		-- TODO: control by debug
		spi_read	<= mem_read when device_id = DEVICE_SPI else '0';
		spi_write	<= mem_read when device_id = DEVICE_SPI else '0';
		spi_address	<= device_addr(1 downto 0);
		spi_data_in	<= data_in(7 downto 0);
		
		key_read	<= mem_read when device_id = DEVICE_KEY else '0';
		key_write	<= mem_read when device_id = DEVICE_KEY else '0';
	end process;

	-- device instances
	-- internal
	-- bootrom
	-- TODO
	
	-- cache control
	-- TODO
	
	-- debug
	-- TODO
	
	-- interfaces
	-- RAM
	ram_interface: entity work.nst_ram_interface
		port map (
			data_in		=> data_in,
			data_out	=> ram_data_out,
			
			address	=> device_addr,
			
			exec_clk	=> device_exec_clk,
			ram_clk		=> device_ram_clk,
			read_in		=> ram_read,
			write_in	=> ram_write,
			
			ready	=> ram_ready,
			
			bus_in	=> memory_bus_IN,
			bus_out	=> memory_bus_OUT,
			bus_oe	=> memory_bus_OE,
			
			address_low_clk		=> mem_addr_low_clk,
			address_high_clk	=> mem_addr_high_clk,
			read_out			=> memory_read,
			write_out			=> memory_write
		);
	
	-- SPI
	spi_interface: entity work.nst_spi_interface
		port (
			address		=> spi_address,
			data_in		=> spi_data_in,
			data_out	=> spi_data_out,
			
			exec_clk	=> device_exec_clk,
			spi_clk		=> device_spi_clk,
			mem_read	=> spi_read,
			mem_write	=> spi_write,
			
			interrupt	=> spi_interrupt,
			
			clk		=> spi_clk,
			sel		=> spi_sel,
			cd		=> spi_cd,
			cido	=> spi_cido,
			codi	=> spi_codi
		);
	
	-- keys
	key_interface: entity work.nst_keypad_interface
		port map (
			address		=> device_addr(2 downto 0),
			data_in		=> data_in(7 downto 0),
			data_out	=> key_data_out,
			
			exec_clk	=> device_exec_clk,
			mem_read	=> key_read,
			mem_write	=> key_write,
			
			interrupt	=> keypad_interrupt,
			
			sel		=> keypad_sel,
			data	=> keypad_data
		);
end a1;