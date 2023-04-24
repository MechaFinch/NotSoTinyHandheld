--
-- Mechafinch
-- NST Handheld Project
--
-- alu_test
-- Testbench for the ALU
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeris_std.all;
use work.nst_types.all;

entity alu_test is
end alu_test;

architecture tb of alu_test is
	type test_record is record
		in_a:	nst_word_t;
		in_b:	nst_word_t;
		in_f:	nst_word_t;
		
		operation:	std_logic_vector(3 downto 0);
		packed_4:	std_logic;
		packed_8:	std_logic;
		short:		std_logic;
		
		subtract:		std_logic;
		include_carry:	std_logic;
		set_carry:		std_logic;
		
		md_signed:	std_logic;
		
		v:		nst_word_t;
		flags:	nst_word_t;
	end record;
	
	type test_array is array (natural range <>) of test_vector;
	constant tva: test_array := (
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- ADD
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- ADC
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- PADD4
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- PADD8
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- PADC4
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- PADC8
		
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- SUB
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- SBB
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- PSUB4
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- PSUB8
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- PSBB4
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- PSBB8
		
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- MUL 8
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- MULH 8
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- MULSH 8
		
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- MUL 16
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- MULH 16
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- MULSH 16
		
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- PMUL4
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- PMUL8
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- PMULH4
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- PMULH8
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- PMULSH4
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- PMULSH8
		
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- AND
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- OR
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- XOR
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- NOT
		
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- SHL
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- SHR
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- SAR
		
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- ROL 8
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- ROR 8
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- RCL 8
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- RCR 8
		
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- ROL 16
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- ROR 16
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- RCL 16
		(16x"0000", 16x"0000", 16x"0000", 4x"0", '0', '0', '0', '0', '0', '0', '0', 16x"0000", 16x"0000"),	-- RCR 16
	);
	
	signal in_a:	nst_word_t;
	signal in_b:	nst_word_t;
	signal in_f:	nst_word_t;
		
	signal subtract:		std_logic;
	signal include_carry:	std_logic;
	signal set_carry:		std_logic;
	signal packed_4:		std_logic;
	signal packed_8:		std_logic;
	signal md_signed:		std_logic;
	signal short:			std_logic;
	signal logic_sel:		std_logic_vector(3 downto 0);
		
	signal sum:		nst_word_t;
	signal product:	nst_dword_t;
	signal quotient:	nst_word_t;
	signal remainder:	nst_word_t;
	signal logic:		nst_word_t;
		
	signal arithmetic_flags:	nst_word_t;
	signal logic_flags:		nst_word_t;
begin
	uut: entity work.nst_alu
		port map (
			in_a				=> in_a,
			in_b				=> in_b,
			in_f				=> in_f,
			subtract			=> subtract,
			include_carry		=> include_carry,
			set_carry			=> set_carry,
			packed_4			=> packed_4,
			packed_8			=> packed_8,
			md_signed			=> md_signed,
			short				=> short,
			logic_sel			=> logic_sel,
			sum					=> sum,
			product				=> product,
			quotient			=> quotient,
			remainder			=> remainder,
			logic				=> logic,
			arithmetic_flags	=> arithmetic_flags,
			logic_flags			=> logic_flags
		);
	
	stim: process begin
		for i in 0 to tva'range - 1 loop
			wait for 5 ns;
			
			in_a			<= tva(i).in_a;
			in_b			<= tva(i).in_b;
			in_f			<= tva(i).in_f;
			subtract		<= tva(i).subtract;
			include_carry	<= tva(i).include_carry;
			set_carry		<= tva(i).set_carry;
			packed_4		<= tva(i).packed_4;
			packed_8		<= tva(i).packed_8;
			md_signed		<= tva(i).md_signed;
			logic_sel		<= tva(i).logic_sel;
			
			wait for 5 ns;
			
			assert sum = tva(i).sum report
				"error: sum of test " & integer'image(i) &
				"expected " & to_hstring(tva(i).sum) &
				"but got " & to_hstring(sum);
			
			assert product = tva(i).product report
				"error: product of test " & integer'image(i) &
				"expected " & to_hstring(tva(i).product) &
				"but got " & to_hstring(product);
			
			assert quotient = tva(i).quotient report
				"error: quotient of test " & integer'image(i) &
				"expected " & to_hstring(tva(i).quotient) &
				"but got " & to_hstring(quotient);
			
			assert remainder = tva(i).remainder report
				"error: remainder of test " & integer'image(i) &
				"expected " & to_hstring(tva(i).remainder) &
				"but got " & to_hstring(remainder);
			
			assert logic = tva(i).logic report
				"error: logic of test " & integer'image(i) &
				"expected " & to_hstring(tva(i).logic) &
				"but got " & to_hstring(logic);
			
			assert arithmetic_flags = tva(i).arithmetic_flags report
				"error: arithmetic_flags of test " & integer'image(i) &
				"expected " & to_hstring(tva(i).arithmetic_flags) &
				"but got " & to_hstring(arithmetic_flags);
			
			assert logic_flags = tva(i).logic_flags report
				"error: logic_flags of test " & integer'image(i) &
				"expected " & to_hstring(tva(i).logic_flags) &
				"but got " & to_hstring(logic_flags);
		end for;
		
		-- quick simulation end
		assert false
			report "done."
			severity failure;
	end process stim;