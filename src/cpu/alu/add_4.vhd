--
-- Mechafinch
-- NST Handheld Project
--
-- add_4
-- 4 bit adder with flags, for packed operations
--

library ieee;
use ieee.std_logic_1164.all;

entity add_4 is
	port (
		a:	in std_logic_vector(3 downto 0);
		b:	in std_logic_vector(3 downto 0);
		c:	in std_logic;
		
		subtract:	in std_logic;
		
		sum:		out std_logic_vector(3 downto 0);
		carry:		out std_logic;
		sign:		out std_logic;
		overflow:	out std_logic;
		zero:		out std_logic
	);
end add_4;

architecture a1 of add_4 is
	signal sum_internal:	std_logic_vector(3 downto 0);
	signal carry_internal:	std_logic_vector(3 downto 0);
	signal b_internal:		std_logic_vector(3 downto 0);
	signal c_internal:		std_logic;
begin
	-- output
	sum			<= sum_internal;
	carry		<= carry_internal(3);
	sign		<= sum_internal(3);
	zero		<= '1' when sum_internal(3 downto 0) = "0000" else '0';
	overflow	<= carry_internal(2) xor carry_internal(3);
	
	-- modifications from subtract
	b_internal	<=	(not b) when subtract else
					b;
	c_internal	<=	(not c) when subtract else
					c;
	
	-- actual adder
	-- bit by bit so we can get both carry and overflow
	add_gen: for i in 0 to 3 generate
		add_first: if i = 0 generate
			sum_internal(i)		<= a(i) xor b(i) xor c_internal;
			carry_internal(i)	<= ((a(i) xor b(i)) and c_internal) or (a(i) and b(i));
		end generate add_first;
		
		add_others: if i /= 0 generate
			sum_internal(i)		<= a(i) xor b(i) xor carry_internal(i - 1);
			carry_internal(i)	<= ((a(i) xor b(i)) and carry_internal(i - 1)) or (a(i) and b(i));
		end generate add_others;
	end generate add_gen;
end a1;