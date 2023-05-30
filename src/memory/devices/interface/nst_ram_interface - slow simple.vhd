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
--	If the address is not equal to the known address
--		clear the ready flag
--
--	If the upper halves of the addresses are not equal
--		set address_high_clk equal to the memory clock
--		On the falling edge of the memory clock
--			place the upper half of the input address onto the bus
--			update the known upper half
--			set read_out and write_out high
--			set bus_oe high
--	If the lower halves of the addresses are not equal
--		set address_low_clk equal to the memory clock for one pulse
--		On the falling edge of the memory clock
--			place the lower half of the input address onto the bus
--			update the known lower half
--			set read_out and write_out high
--			set bus_oe high
--	If both read_in and write_in are high
--		set read_out and write_out high on the falling edge of the memory clock
--		bus_oe doesn't matter
--	Otherwise
--		On the falling edge of the memory clock
--			set bus_oe to write_in
--			set write_out to (write_in NOR ram_clk)
--			set read_out to NOT read_in
--		If read_in is high
--			set data_out to bus_in on the rising edge of the memory clock
--			set the ready flag on the rising edge of the memory clock after the aforementioned falling edge
--		If write_in is high
--			set the ready flag on the rising edge of the memory clock after the aforementioned falling edge

architecture a1 of nst_ram_interface is
	signal next_known_address:	nst_dword_t;
	signal known_address:		nst_dword_t := 32x"FFFFFFFF";
	
	signal next_data_out, next_bus_out:		nst_word_t;
	signal next_read_out, next_bus_oe,
		   next_write_out, next_op_active,
		   next_address_high_clk,
		   next_address_low_clk:			std_logic;
	
	signal write_out_int:		std_logic := '1';
	signal op_active,
		   address_high_clk_int,
		   address_low_clk_int:	std_logic := '0';
begin
	-- ready flag deals in multiple domains
	ready_proc: process (all) begin
		if (address /= known_address) or (op_active = '0') or ((read_in = '0') and (write_in = '0'))then
			ready <= '0';
		else
			if rising_edge(ram_clk) and (op_active = '1') then
				ready <= '1';
			end if;
		end if;
	end process;
	
	-- most things are clocked on the falling edge of mem clk
	mem_falling_proc: process (ram_clk) begin
		if rising_edge(ram_clk) then
			-- read on the rising edge
			data_out <= next_data_out;
		end if;
	
		if falling_edge(ram_clk) then
			-- clocks
			address_high_clk_int	<= next_address_high_clk;
			address_low_clk_int		<= next_address_low_clk;
			write_out_int			<= next_write_out;
			
			-- delays to ensure address
			
			-- not clocks
			read_out		<= next_read_out;
			bus_out			<= next_bus_out;
			bus_oe			<= next_bus_oe;
			op_active		<= next_op_active;
			known_address	<= next_known_address;
		end if;
	end process;
	
	-- clocks need to follow the memory clock
	write_out			<= write_out_int or (not ram_clk);
	address_high_clk	<= address_high_clk_int and ram_clk;
	address_low_clk		<= address_low_clk_int and ram_clk;
	
	-- async stuff
	async_proc: process (all) begin
		next_data_out <=	bus_in when read_out = '0' else
							data_out;
	
		if address(31 downto 16) /= known_address(31 downto 16) then
			-- need to write upper address
			next_address_high_clk	<= '1';
			next_address_low_clk	<= '0';
			
			next_read_out	<= '1';
			next_write_out	<= '1';
			next_bus_out	<= address(31 downto 16);
			next_bus_oe		<= '1';
			next_op_active	<= '0';
			
			next_known_address(31 downto 16)	<= address(31 downto 16);
			next_known_address(15 downto 0)		<= known_address(15 downto 0);
		elsif address(15 downto 0) /= known_address(15 downto 0) then
			-- need to write lower address
			next_address_high_clk	<= '0';
			next_address_low_clk	<= '1';
			
			next_read_out	<= '1';
			next_write_out	<= '1';
			next_bus_out	<= address(15 downto 0);
			next_bus_oe		<= '1';
			next_op_active	<= '0';
			
			next_known_address(31 downto 16)	<= known_address(31 downto 16);
			next_known_address(15 downto 0)		<= address(15 downto 0);
		else
			-- allow read/write
			next_address_high_clk	<= '0';
			next_address_low_clk	<= '0';
			
			if read_in and write_in then
				-- conflict = no op
				next_read_out	<= '1'; 
				next_write_out	<= '1';
				next_bus_out	<= (others => '0');
				next_bus_oe		<= '0';
				next_op_active	<= '0';
			elsif read_in then
				-- read
				next_read_out	<= '0';
				next_write_out	<= '1';
				next_bus_out	<= (others => '0');
				next_bus_oe		<= '0';
				next_op_active	<= '1';
			elsif write_in then
				-- write
				next_read_out	<= '1';
				next_write_out	<= '0';
				next_bus_out	<= data_in;
				next_bus_oe		<= '1';
				next_op_active	<= '1';
			else
				-- no op
				next_read_out	<= '1'; 
				next_write_out	<= '1';
				next_bus_out	<= (others => '0');
				next_bus_oe		<= '0';
				next_op_active	<= '0';
			end if;
			
			next_known_address	<= known_address;
		end if;
	end process;
end a1;