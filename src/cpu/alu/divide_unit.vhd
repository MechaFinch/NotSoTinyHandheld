--
-- Mechafinch
-- NST Handheld Project
--
-- divide_unit
-- Handles division variants
-- Currently unimplemented
--

library ieee;
use ieee.std_logic_1164.all;
use work.nst_types.all;

entity divide_unit is
	port (
		-- input
		in_a:	nst_dword_t;
		in_b:	nst_word_t;
		
		-- control
		packed_4:	in std_logic;
		packed_8:	in std_logic;
		short:		in std_logic;
		
		md_signed:	in std_logic;
		
		-- output
		quot_rem:	out nst_dword_t;
		flags:		out nst_word_t
	);
end divide_unit;

architecture unimplemented of divide_unit is
begin
	quot_rem	<= (others => '0');
	flags		<= (others => '0');
end unimplemented;