--
-- Mechafinch
-- NST Handheld Project
-- 
-- nst_data_cache
-- Data cache.
-- 2-way set associative, LRU, read and write
-- 512 sets with 4 byte blocks
-- uses 11 BRAM blocks
--

library ieee;
use ieee.std_logic_1164.all;
use work.nst_types.all;

library efxphysicallib;
use efxphysicallib.efxcomponents.all;

entity nst_data_cache is
	port (
		-- cpu side
		address:	in nst_dword_t;
		data_in:	in dcache_block_data_t;
		data_out:	out dcache_block_data_t;
		
		cpu_read:	in std_logic;
		cpu_write:	in std_logic;
		data_ready:	out std_logic;
		
		-- memory side
		mem_address:	out nst_dword_t;
		mem_data_in:	in dcache_block_data_t;
		mem_data_out:	out dcache_block_data_t;
		
		mem_read:	out std_logic;
		mem_write:	out std_logic;
		mem_ready:	in std_logic;
		
		-- clocking
		exec_clk:	in std_logic;
	);
end nst_data_cache;

architecture a1 of nst_data_cache is
	type dcache_block_t is record
		data:	dcache_block_data_t; -- array of 4 bytes
		tag:	std_logic_vector(20 downto 0);
		clean:	std_logic;
	end record;
	
	type dcache_set_t is record
		b0:		dcache_block_t;
		b1:		dcache_block_t;
		lru:	std_logic;	-- 0 = b0 LRU, 1 = b1 LRU
		valid:	std_logic;	-- 0 = invalid, 1 = valid
	end record;
	
	-- only 10 bits per BRAM are used due to the addressing mode but we need to name them anyways
	-- the upper 10 bits per will be open
	type bram_data_t is array (10 downto 0) of std_logic_vector(19 downto 0);
	
	signal current_input:	dcache_set_t;
	signal current_output:	dcache_set_t;
	
	signal bram_write_enable:	std_logic;
	signal bram_address:		std_logic_vector(11 downto 0);
	
	signal bram_inputs:		bram_data_t;
	signal bram_outputs:	bram_data_t;
begin
	-- TODO
end a1;