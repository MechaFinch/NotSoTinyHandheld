--
-- Mechafinch
-- NST Handheld Project
--
-- nst_cpu
-- The CPU itself. 
--

library ieee;
use ieee.std_logic_1164.all;
use work.nst_constants.all;

entity nst_cpu is
	port (
		instruction_memory_value:	in std_logic_vector(MEMORY_DATA_WIDTH - 1 downto 0);
		instruction_memory_ready:	in std_logic;
		data_memory_value_in:		in std_logic_vector(MEMORY_DATA_WIDTH - 1 downto 0);
		data_memory_ready:			in std_logic;
		
		interrupt_number:			in std_logic_vector(7 downto 0);
		blocking_interrupt:			in std_logic;
		non_blocking_interrupt:		in std_logic;
		
		instruction_memory_address:	out std_logic_vector(31 downto 0);
		data_memory_address:		out std_logic_vector(31 downto 0);
		data_memory_value_out:		out std_logic_vector(MEMORY_DATA_WIDTH - 1 downto 0)
		data_memory_read:			out std_logic;
		data_memory_write:			out std_logic;
	);
end nst_cpu;