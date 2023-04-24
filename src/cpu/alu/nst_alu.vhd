--
-- Mechafinch
-- NST Handheld Project
--
-- nst_alu
-- ALU
-- This module instantiates components which handle each operation and selects between them.
--
-- operation values
--	0000	ADD/SUBTRACT
--	0001	MULTIPLY
--	0010	DIVIDE
--	0100	AND
--	0101	OR
--	0110	XOR
--	0111	NOT
--	1000	SHL
--	1010	SHR
--	1011	SAR
--	1100	ROL
--	1101	ROR
--	1110	RCL
--	1111	RCR
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.nst_types.all;

entity nst_alu is
	port (
		-- input
		in_a_low:	in nst_word_t;
		in_a_high:	in nst_word_t;
		in_b:		in nst_word_t;
		in_f:		in nst_word_t;
		
		-- control
		operation:	in std_logic_vector(3 downto 0);	-- selects between adder, mul, div, logic
		packed_4:		in std_logic;
		packed_8:		in std_logic;
		short:			in std_logic;	-- use 8 bit values
		
		-- adder control
		subtract:		in std_logic;	-- subtract
		include_carry:	in std_logic;	-- Cin comes from flags
		set_carry:		in std_logic;	-- Cin = 1
		
		-- mul/div control
		md_signed:	in std_logic;	-- signed operation
		
		-- output
		v:		out nst_dword_t;
		flags:	out nst_word_t;
	);
end nst_alu;

architecture a1 of nst_alu is
	-- adder signals
	signal sum:			nst_word_t;
	signal adder_flags:	nst_word_t;
	
	-- multiply/divide signals
	signal product:		nst_dword_t;
	signal mul_flags:	nst_word_t;
	
	signal quot_rem:	nst_dword_t;
	signal div_flags:	nst_word_t;
	
	-- logic
	signal logic_result:	nst_word_t;
	signal logic_flags:		flags_t;
begin
	-- select output
	proc_select: process (all) begin
		case operation is
			when "0000" => -- add/subtract
				v(31 downto 16)	<= (others => '0');
				v(15 downto 0)	<= sum;
				flags			<= adder_flags;
			
			when "0001" => -- multiply
				v		<= product;
				flags	<= mul_flags;
			
			when "0010" => -- divide
				v 		<= quot_rem;
				flags	<= div_flags;
			
			when others => -- logic
				v(31 downto 16)		<= (others => '0');
				v(15 downto 0)		<= logic_result;
				flags(15 downto 4)	<= (others => '0');
				flags(3)			<= logic_flags.zero;
				flags(2)			<= logic_flags.overflow;
				flags(1)			<= logic_flags.sign;
				flags(0)			<= logic_flags.carry;
		end case;
	end process;
	
	-- instantiate subcircuits
	-- add/subtract
	add: entity work.adder_unit
		port map (
			in_a			=> in_a_low,
			in_b			=> in_b,
			in_f			=> in_f,
			packed_4		=> packed_4,
			packed_8		=> packed_8,
			subtract		=> subtract,
			include_carry	=> include_carry,
			set_carry		=> set_carry,
			sum				=> sum,
			flags			=> adder_flags
		);
	
	-- multiply
	mul: entity work.multiply_unit
		port map (
			in_a		=> in_a_low,
			in_b		=> in_b,
			packed_4	=> packed_4,
			packed_8	=> packed_8,
			short		=> short,
			md_signed	=> md_signed,
			product		=> product,
			flags		=> mul_flags
		);
	
	-- divide
	div: entity work.divide_unit
		port map (
			in_a		=> (in_a_high, in_a_low),
			in_b		=> in_b,
			packed_4	=> packed_4,
			packed_8	=> packed_8,
			short		=> short,
			md_signed	=> md_signed,
			quot_rem	=> quot_rem,
			flags		=> div_flags
		);
	
	-- logic
	logic: entity work.logic_unit
		port map (
			in_a		=> in_a,
			in_b		=> in_b,
			in_f		=> in_f,
			operation	=> operation,
			short		=> short,
			v			=> logic_result,
			flags		=> logic_flags
		);
end a1;