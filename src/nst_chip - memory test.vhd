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
		device_ram_clk:		in std_logic;	-- 4 MHz	TBD based on breadboard performance, potentially up to 12 MHz
		device_spi_clk:		in std_logic;	-- 8 MHz	ILI9341 max spi clock is 10 MHz
		device_10khz_clk:	in std_logic	-- 10 kHz	from the oscillator
	);
end nst_chip;

architecture a1 of nst_chip is
	signal btn_1_pressed, btn_2_pressed:	std_logic;

	signal memory_bus_oe_single: std_logic;
	
	signal test_data:			std_logic_vector(3 downto 0) := (others => '0');
	signal test_data_bulk_in:	nst_word_t;
	signal test_data_bulk_out:	nst_word_t;
	
	signal test_address:		std_logic_vector(3 downto 0) := (others => '0');
	signal test_address_full:	nst_dword_t;
	
	signal test_read, test_write:	std_logic := '0';
	signal test_ready:				std_logic;
	
	type led_state_t is (DISPLAY_ADDRESS, DISPLAY_DATA);
	signal led_state: led_state_t := DISPLAY_ADDRESS;
	
--	signal ram_clk_divider, exec_clk_divider: std_logic_vector(17 downto 0) := (others => '0');
--	signal ram_clk_divided, exec_clk_divided: std_logic;
	
	signal press_processed:	std_logic := '0';
begin
	memory_bus_OE <= (others => memory_bus_oe_single);
	
	-- why are they like this
	btn_1_pressed	<= not btn_1;
	btn_2_pressed	<= not btn_2;
	
	-- unused stuff
	spi_sel		<= (others => '0');
	spi_cd		<= '0';
	spi_codi	<= '0';
	spi_clk		<= '0';
	keypad_sel	<= (others => '0');
	
	-- memory testing system
	-- parsitizing the chip inputs as button controls
	-- keypad_data	= increment leds
	-- spi_cido		= switch addr/data
	-- btn_1		= read
	-- btn_2		= write
	
	test_proc: process (all) begin
		test_address_full(31 downto 5)	<= (others => '0');
		test_address_full(4 downto 1)	<= test_address;
		test_address_full(0)			<= '0';
		
		test_data_bulk_in(15 downto 4)	<= (others => '0');
		test_data_bulk_in(3 downto 0)	<= test_data;
		
		-- what are we showing
		if led_state = DISPLAY_ADDRESS then
			leds	<= not test_address;
		else
			leds	<= not test_data;
		end if;
		
	--	exec_clk_divided <= exec_clk_divider(17);
	--	ram_clk_divided <= ram_clk_divider(17);
		
	--	if rising_edge(device_ram_clk) then
	--		ram_clk_divider <= std_logic_vector(unsigned(ram_clk_divider) + 1);
	--	end if;
		
	--	if rising_edge(device_exec_clk) then
	--		exec_clk_divider <= std_logic_vector(unsigned(exec_clk_divider) + 1);
	--	end if;
		
		-- read/write state
	--	if rising_edge(exec_clk_divided) then
		if rising_edge(device_exec_clk) then
			if test_ready then
				if test_read then
					test_data <= test_data_bulk_out(3 downto 0);
				end if;
			
				test_read	<= '0';
				test_write	<= '0';
			elsif not press_processed then
				if btn_1_pressed then -- read
					test_read		<= '1';
					press_processed	<= '1';
				elsif btn_2_pressed then -- write
					test_write 		<= '1';
					press_processed	<= '1';
				elsif keypad_data then -- increment displayed item
					if led_state = DISPLAY_ADDRESS then
						test_address <= std_logic_vector(unsigned(test_address) + 1);
					else
						test_data <= std_logic_vector(unsigned(test_data) + 1);
					end if;
					
					press_processed	<= '1';
				elsif spi_cido then -- switch between addr and data
					led_state 		<=	DISPLAY_DATA when led_state = DISPLAY_ADDRESS else
										DISPLAY_ADDRESS;
					press_processed	<= '1';
				end if;
			else
				if (not btn_1_pressed) and (not btn_2_pressed) and (not keypad_data) and (not spi_cido) then
					press_processed <= '0';
				end if;
			end if;
		end if;
	end process;
	
	-- RAM interface
	ram: entity work.nst_ram_interface
		port map (
			data_in		=> test_data_bulk_in,
			data_out	=> test_data_bulk_out,
			address		=> test_address_full,
			
			exec_clk	=> device_exec_clk,
			ram_clk		=> device_ram_clk, --ram_clk_divided,
			read_in		=> test_read,
			write_in	=> test_write,
			ready		=> test_ready,
			
			bus_in	=> memory_bus_IN,
			bus_out	=> memory_bus_OUT,
			bus_oe	=> memory_bus_oe_single,
			
			address_low_clk		=> mem_addr_low_clk,
			address_high_clk	=> mem_addr_high_clk,
			read_out			=> memory_read,
			write_out			=> memory_write
		);
end a1;