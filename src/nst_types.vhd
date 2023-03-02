--
-- Mechafinch
-- NST Handheld Project
--
-- nst_types
-- Types for the NST cpu
--

library ieee;
use ieee.std_logic_1164.all;

package nst_types is
	-- aliases for data widths
	subtype nst_byte_t is std_logic_vector(7 downto 0);
	subtype nst_word_t is std_logic_vector(15 downto 0);
	subtype nst_dword_t is std_logic_vector(31 downto 0);

	-- word outputs of the bulk memory buffer
	type bulk_data_t is array (0 to 9) of nst_word_t;
end nst_types;