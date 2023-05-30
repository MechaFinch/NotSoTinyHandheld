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
		memory_bus_OE:		out std_logic_vector(15 downto 0);
		mem_addr_low_clk:	out std_logic;
		mem_addr_high_clk:	out std_logic;
		memory_read:		out std_logic;
		memory_write:		out std_logic;
		
		spi_sel:	out std_logic_vector(2 downto 0);
		spi_cd:		out std_logic;
		spi_cido:	in std_logic;
		spi_codi:	out std_logic;
		spi_clk:	out std_logic;
		
		keypad_sel:		out std_logic_vector(4 downto 0);
		keypad_data:	in std_logic;
		
		leds:	out std_logic_vector(3 downto 0); -- high = off, low = on
		btn_1:	in std_logic; -- pressed = low
		btn_2:	in std_logic; -- pressed = low
		
		-- Device Signals
		-- PLL clocks
		device_exec_clk:	in std_logic;	-- 64 MHz	TBD based on cpu performance
		device_ram_clk:		in std_logic;	-- 4 MHz	TBD based on breadboard memory performance, potentially up to 16 MHz
		device_spi_clk:		in std_logic;	-- 8 MHz	ILI9341 max spi clock is 10 MHz
		device_10khz_clk:	in std_logic	-- 10 kHz	from the oscillator
	);
end nst_chip;

architecture a1 of nst_chip is
	signal memory_bus_oe_single: std_logic;
begin
	memory_bus_OE <= (others => memory_bus_oe_single);
	
	-- things we aren't using
	spi_sel		<= "111";
	spi_cd		<= '1';
	spi_codi	<= '0';
	spi_clk		<= '0';
	
	keypad_sel	<= "00000";
	
	-- memory system
	mem: entity work.nst_memory_manager
		port map (
			memory_bus_IN
			memory_bus_OUT
			memory_bus_OE		=> memory_bus_oe_single,
			mem_addr_low_clk
			mem_addr_high_clk
		);
end a1;