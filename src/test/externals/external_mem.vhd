--
-- Mechafinch
-- NST Handheld Project
--
-- external_mem
-- Models the external memory system for simulation
-- The address is held in 3 75HC273 8 bit DFFs - two are clocked by mem_addr_low_clk and store 15
-- bits (LSB ignored). The other is clocked by mem_addr_high_clk and stores the 4 LSBs. 
-- Data is stored in two AS6C4008 512kx8 SRAMs. One stores the upper byte, the other the lower. 
-- Their control signals are all tied together.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity external_mem is
	port (
		-- nst_chip signals
		memory_bus_IN:	out std_logic_vector(15 downto 0);
		memory_bus_OUT:	in std_logic_vector(15 downto 0);
		memory_bus_OE:	in std_logic_vector(15 downto 0);
		
		mem_addr_low_clk:	in std_logic;
		mem_addr_high_clk:	in std_logic;
		memory_read:		in std_logic;
		memory_write:		in std_logic
	);
end external_mem;

architecture a1 of external_mem is
	-- 19 bit address, word addressed memory
	type mem_arr is array ((2**19) - 1 downto 0) of std_logic_vector(15 downto 0);
	
	signal memory:	mem_arr := (others => (others => '0'));
	
	signal address_reg_low: 	std_logic_vector(14 downto 0);
	signal address_reg_high:	std_logic_vector(3 downto 0);
	signal combined_address:	std_logic_vector(18 downto 0);
	
	signal filtered_mem_bus:	std_logic_vector(15 downto 0);
begin
	-- make sure the chip and ram aren't driving the bus at the same time
	assert ((memory_bus_OE = 16x"0000") or (memory_read = '1')) or not memory_read'stable(1 ps) report
		"Error: memory bus is driven by both RAM and NST board.";
	
	-- deals with reading
	read_proc: process (all) begin
		-- output enable is overridden by write enable, both are active low
		memory_bus_IN <=	memory(to_integer(unsigned(combined_address))) when (not memory_read) and memory_write else
							(others => '0');
	end process;
	
	-- deals with writing
	write_proc: process (memory_write) begin
		-- final write occurs on the rising edge of WE
		if rising_edge(memory_write) then
			memory(to_integer(unsigned(combined_address))) <= filtered_mem_bus;
			
			-- check high z
			assert memory_bus_OE /= 16x"0000" report
				"Error: RAM written without chip data asserted.";
		end if;
	end process;
	
	-- deals with the address reg
	addr_proc: process (all) begin
		-- just renaming signals
		combined_address(18 downto 15)	<= address_reg_high;
		combined_address(14 downto 0)	<= address_reg_low;
		
		-- combinational
		filtered_mem_bus <=	memory_bus_OUT when memory_bus_OE /= 16x"0000" else
							(others => '0');
		
		-- clocked
		if rising_edge(mem_addr_low_clk) then
			address_reg_low <= filtered_mem_bus(15 downto 1);
			
			-- check for high z
			assert memory_bus_OE /= 16x"0000" report
				"Error: low address register clocked without chip data asserted.";
		end if;
		
		if rising_edge(mem_addr_high_clk) then
			address_reg_high <= filtered_mem_bus(3 downto 0);
			
			assert memory_bus_OE /= 16x"0000" report
				"Error: high address register clocked without chip data asserted.";
		end if;
	end process;
end a1;