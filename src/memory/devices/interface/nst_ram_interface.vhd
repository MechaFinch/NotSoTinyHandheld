--
-- Mechafinch
-- NST Handheld Project
--
-- nst_ram_interface
-- Interface for the off-board RAM chips. RAM is setup with a pair of AS6C4008 512k SRAM chips
-- addressed by 3 SN74HC273 8-bit DFFs. A 16 bit multiplexed address/data bus is used to write
-- addresses to the latches and read/write from the two SRAMs.
--
-- This interface takes an aligned 16 bit word, an aligned address (LSB ignored off-chip), and
-- control signals. It will read from or write to the given address, and output the read data when
-- applicable.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.nst_types.all;

entity nst_ram_interface is
	port (
		-- interface
		data_in:	in nst_word_t;
		data_out:	out nst_word_t := 16x"0000";
		
		address:	in nst_dword_t;
		
		exec_clk:	in std_logic;
		ram_clk:	in std_logic;
		read_in:	in std_logic;
		write_in:	in std_logic;
		
		ready:		out std_logic := '0';
		
		-- IO pins & control
		bus_in:		in std_logic_vector(15 downto 0);
		bus_out:	out std_logic_vector(15 downto 0) := 16x"0000";
		bus_oe:		out std_logic := '0';
		
		address_low_clk:	out std_logic := '0';
		address_high_clk:	out std_logic := '0';
		read_out:			out std_logic := '1';
		write_out:			out std_logic := '1'
	);
end nst_ram_interface;

-- DESCRIPTION OF OPERATION --
--	Next desired action, in priority order:
--		Update the upper address; if the upper address is not equal to the input address
--		Update the lower address; if the lower address is not equal to the input address
--		Read data; if read_in is set (and write_in is not)
--		Write data; if write_in is set (and read_in is not)
--
--	Operation
--		bus_out, AHC, and ALC track how many ram clock cycles until they are allowed to change.
--			bus_oe is tracked by bus_out
--		Control signals (AHC, ALC, OE, WE) track how many ram clock cycles until they will change.
--		A signal tracks how many cycles until data can be read.
--		All signal changes take place on the rising edge of the ram clock
--	
--	Address Updating
--	1.	Wait until data can be changed and the relevant address clock will go low
--	2.	Change the address, set the address clock to go high in 70 ns and low in 130 ns, set data
--		to be allowed to change in 80 ns
--
--	Reading
--	1.	Wait until data can be changed
--	2.	Set bus_oe low, set OE low and to go high in 50 ns, set data to be allowed to change in
--		70 ns
--	3.	Read data after 40 ns (set ready)
--
--	Writing
--	1.	Wait until data can be changed in 20 ns
--	2.	Set WE low and to go high in 50 ns
--	3.	Wait until data can be changed
--	4.	Change data, set data to be allowed to change in 40 ns (set ready)
--

architecture a1 of nst_ram_interface is
	-- utility for constants
	pure function div_ceil(a: integer; b: integer) return integer is
	begin
		return (a + b - 1) / b;
	end function;

	-- constants weeeeee
	constant RAM_ADDRESS_MINIMUM:	integer := 1;
	constant RAM_ADDRESS_MAXIMUM:	integer := 19;
	constant ram_clock_period:		integer := 15;
	
	constant aclk_setup_ns:		integer := 70; -- time from data change to aclk high
	constant aclk_hold_ns:		integer := (aclk_setup_ns + 60); -- time from data change to aclk low
	constant aclk_data_hold_ns:	integer := (aclk_setup_ns + 1); -- time until data can change from an address update
	
	constant read_setup_ns:		integer := 40; -- time from OE low to read performed
	constant read_hold_ns:		integer := (read_setup_ns + 1); -- time from OE low to OE high
	constant read_data_hold_ns:	integer := (read_hold_ns + 20); -- time until data can change from OE low
	
	constant write_hold_ns:			integer := 50; -- time from WE low to WE high
	constant write_data_hold_ns:	integer := (write_hold_ns + 1); -- time until data can change from WE low
	
	constant aclk_setup_cycles:		integer := div_ceil(aclk_setup_ns, ram_clock_period) - 1;
	constant aclk_hold_cycles:		integer := div_ceil(aclk_hold_ns, ram_clock_period) - 1;
	constant aclk_data_hold_cycles:	integer := div_ceil(aclk_data_hold_ns, ram_clock_period) - 1;
	
	constant read_setup_cycles:		integer := div_ceil(read_setup_ns, ram_clock_period) - 1;
	constant read_hold_cycles:		integer := div_ceil(read_hold_ns, ram_clock_period) - 1;
	constant read_data_hold_cycles:	integer := div_ceil(read_data_hold_ns, ram_clock_period) - 1;
	
	constant write_hold_cycles:			integer := div_ceil(write_hold_ns, ram_clock_period) - 1;
	constant write_data_hold_cycles:	integer := div_ceil(write_data_hold_ns, ram_clock_period) - 1;

	signal known_address:	nst_dword_t := 32x"FFFFFFFF";
	
	signal data_change_counter:	integer range 0 to aclk_data_hold_cycles := 0;
	signal ahc_set_counter:		integer range 0 to aclk_setup_cycles := 0;
	signal ahc_hold_counter:	integer range 0 to aclk_hold_cycles := 0;
	signal alc_set_counter:		integer range 0 to aclk_setup_cycles := 0;
	signal alc_hold_counter:	integer range 0 to aclk_hold_cycles := 0;
	signal oe_hold_counter:		integer range 0 to read_hold_cycles := 0;
	signal we_hold_counter:		integer range 0 to write_hold_cycles := 0;
	signal read_delay_counter:	integer range 0 to read_setup_cycles := 0;
	
	signal read_ongoing:	std_logic := '0';
	
	signal ready_ram_domain:	std_logic := '0'; -- RAM domain ready
begin
	-- exec synchronized ready bit
	ready_syn: process (exec_clk) begin
		if falling_edge(exec_clk) then
			-- this serves two purposes:
			--	1. synchronize across domains.
			--	2. ensure the ready bit is not prematurely set
			-- The latter is accomplished by duplicating the clearing logic from the ram domain
			-- This ensures that even with the ram clock slower than the exec clock, starting a new
			-- operation will clear the ready bit
			ready <= '1' when (ready_ram_domain = '1') and ((read_in = '1') or (write_in = '1')) and (address = known_address) else '0';
		end if;
	end process;
	
	-- main process
	op_proc: process (all) is
		variable data_counter_start:	boolean := false;
		variable data_counter_value:	integer range 0 to aclk_data_hold_cycles := 0;
		variable data_value:			nst_word_t;
		variable data_oe:				std_logic;
		
		variable ahc_counter_start: 	boolean := false;
		variable alc_counter_start:		boolean := false;
		variable oe_counter_start:		boolean := false;
		variable we_counter_start:		boolean := false;
		variable read_counter_start:	boolean := false;
	begin
		-- priority order
		-- variables are set combinationally
		if address(RAM_ADDRESS_MAXIMUM downto 16) /= known_address(RAM_ADDRESS_MAXIMUM downto 16) then
			ahc_counter_start	:= true;
			alc_counter_start	:= false;
			oe_counter_start	:= false;
			we_counter_start	:= false;
			read_counter_start	:= false;
			
			data_counter_start	:= true;
			data_counter_value	:= aclk_data_hold_cycles;
			data_oe				:= '1';
			data_value			:= address(31 downto 16);
		elsif address(15 downto RAM_ADDRESS_MINIMUM) /= known_address(15 downto RAM_ADDRESS_MINIMUM) then
			ahc_counter_start	:= false;
			alc_counter_start	:= true;
			oe_counter_start	:= false;
			we_counter_start	:= false;
			read_counter_start	:= false;
			
			data_counter_start	:= true;
			data_counter_value	:= aclk_data_hold_cycles;
			data_oe				:= '1';
			data_value			:= address(15 downto 0);
		elsif read_in and write_in then
			ahc_counter_start	:= false;
			alc_counter_start	:= false;
			oe_counter_start	:= false;
			we_counter_start	:= false;
			read_counter_start	:= false;
			
			data_counter_start	:= false;
			data_counter_value	:= 0;
			data_oe				:= '1';
			data_value			:= data_in;
		elsif read_in then
			ahc_counter_start	:= false;
			alc_counter_start	:= false;
			oe_counter_start	:= true;
			read_counter_start	:= true;
			we_counter_start	:= false;
			
			data_counter_start	:= true;
			data_counter_value	:= read_data_hold_cycles;
			data_oe				:= '0';
			data_value			:= data_in;
		elsif write_in then
			ahc_counter_start	:= false;
			alc_counter_start	:= false;
			oe_counter_start	:= false;
			read_counter_start	:= false;
			we_counter_start	:= true;
			
			data_counter_start	:= true;
			data_counter_value	:= write_data_hold_cycles;
			data_oe				:= '1';
			data_value			:= data_in;
		else
			ahc_counter_start	:= false;
			alc_counter_start	:= false;
			oe_counter_start	:= false;
			we_counter_start	:= false;
			read_counter_start	:= false;
			
			data_counter_start	:= false;
			data_counter_value	:= 0;
			data_oe				:= '1';
			data_value			:= data_in;
		end if;
	
		if rising_edge(ram_clk) then
			-- the ready flag is cleared when addresses change or a new read/write starts
			-- and set when a read completes or a write latches its data
			if (address /= known_address) or
			   ((write_in = '0') and (read_in = '0')) then
				ready_ram_domain <= '0';
			elsif ((read_ongoing = '1') and (read_delay_counter = 0)) or we_counter_start then
				ready_ram_domain <= '1';
			end if;
			
			-- data_out is updated on read or write
			if ((read_delay_counter = 0) and (read_ongoing = '1')) then
				data_out <= bus_in;
			elsif we_counter_start then
				data_out <= data_in;
			end if;
			
			-- counter and signal handling
			if data_change_counter /= 0 then
				data_change_counter <= data_change_counter - 1;
			elsif data_counter_start then
				data_change_counter	<= data_counter_value;
				bus_out				<= data_value;
				bus_oe				<= data_oe;
			end if;
			
			-- address_high_clk
			if ahc_set_counter /= 0 then
				ahc_set_counter <= ahc_set_counter - 1;
			elsif ahc_counter_start and (data_change_counter = 0) and (ahc_hold_counter = 0) then
				ahc_set_counter				<= aclk_setup_cycles;
				known_address(31 downto 16)	<= address(31 downto 16);
				known_address(15 downto 0)	<= known_address(15 downto 0);
			elsif ahc_hold_counter /= 0 then
				address_high_clk <= '1';
			end if;
			
			if ahc_hold_counter /= 0 then
				ahc_hold_counter <= ahc_hold_counter - 1;
			elsif ahc_counter_start and (data_change_counter = 0) then
				ahc_hold_counter <= aclk_hold_cycles;
			else
				address_high_clk <= '0';
			end if;
			
			-- address_low_clk
			if alc_set_counter /= 0 then
				alc_set_counter <= alc_set_counter - 1;
			elsif alc_counter_start and (data_change_counter = 0) and (alc_hold_counter = 0) then
				alc_set_counter				<= aclk_setup_cycles;
				known_address(31 downto 16)	<= known_address(31 downto 16);
				known_address(15 downto 0)	<= address(15 downto 0);
			elsif alc_hold_counter /= 0 then
				address_low_clk <= '1';
			end if;
			
			if alc_hold_counter /= 0 then
				alc_hold_counter <= alc_hold_counter - 1;
			elsif alc_counter_start and (data_change_counter = 0) then
				alc_hold_counter <= aclk_hold_cycles;
			else
				address_low_clk <= '0';
			end if;
			
			-- read_out
			if oe_hold_counter /= 0 then
				oe_hold_counter <= oe_hold_counter - 1;
			elsif oe_counter_start and (data_change_counter = 0) then
				oe_hold_counter	<= read_hold_cycles;
				read_out		<= '0';
			else
				read_out <= '1';
			end if;
			
			-- write_out
			if we_hold_counter /= 0 then
				we_hold_counter <= we_hold_counter - 1;
			elsif we_counter_start and (data_change_counter = 0) then
				we_hold_counter	<= write_hold_cycles;
				write_out		<= '0';
			else
				write_out <= '1';
			end if;
			
			-- reading
			if read_delay_counter /= 0 then
				read_delay_counter	<= read_delay_counter - 1;
				read_ongoing		<= '1';
			elsif read_counter_start and (data_change_counter = 0) then
				read_delay_counter	<= read_setup_cycles;
			elsif read_ongoing then
				read_ongoing	<= '0';
			end if;
		end if;
	end process;
end a1;