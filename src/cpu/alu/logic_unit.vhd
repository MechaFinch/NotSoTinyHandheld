--
-- Mechafinch
-- NST Handheld Project
--
-- logic_unit
-- handles bitwise logic and shifts for the ALU
--

library ieee;
use ieee.std_logic_1164.all;
use work.nst_types.all;

entity logic_unit is
	port (
		-- input
		in_a:	in nst_word_t;
		in_b:	in nst_word_t;
		in_f:	in nst_word_t;
		
		-- control
		operation:	in std_logic_vector(3 downto 0);
		short:		in std_logic;
		
		-- output
		v:		out nst_word_t;
		flags:	out flags_t;
	);
end logic_unit;

architecture a1 of logic_unit is
	-- shifts & rotates
	signal	internal, shift_shl, shift_shr, shift_sar,
			rotate_rol, rotate_ror, rotate_rcl, rotate_rcr:	nst_word_t;
	
	signal	carry_shl, carry_shr, carry_sar,
			carry_rol, carry_ror, carry_rcl, carry_rcr: std_logic;
begin
	v <= internal;

	-- select value and do basic logic
	with operation select internal <=
		in_a or in_b	when "0101",
		in_a xor in_b	when "0110",
		not in_a		when "0111",
		shift_shl		when "1000",
		shift_shr		when "1010",
		shift_sar		when "1011",
		rotate_rol		when "1100",
		rotate_ror		when "1101",
		rotate_rcl		when "1110",
		rotate_rcr		when "1111",
		in_a and in_b	when others;
	
	-- flags
	flag_proc: process (all) is
		variable carry: std_logic;
	begin
		with operation select carry :=
			carry_shl	when "1000",
			carry_shr	when "1010",
			carry_sar	when "1011",
			carry_rol	when "1100",
			carry_ror	when "1101",
			carry_rcl	when "1110",
			carry_rcr	when "1111",
			'0'			when others;
	
		flags.zero		<= (internal(7 downto 0) = 8x"00") when short else (internal = 16x"0000");
		flags.overflow	<= carry;
		flags.sign		<= internal(7) when short else internal(15);
		flags.carry		<= carry;
	end process;
	
	-- shift process
	shift_proc: process (all) is
		-- shift amount
		variable b_integer:	integer;
		variable b_natural:	integer;
		
		-- a w/ carry in
		variable a_wide_c_low, a_wide_c_high:	std_logic_vector(16 downto 0);
		variable a_short_c_low, a_short_c_high:	std_logic_vector(8 downto 0);
		variable a_short_no_c:					std_logic_vector(7 downto 0);
		
		-- shift results w/ carry out
		variable val_shl, val_shr_wide, val_sra_wide,
				 val_rcl_wide, val_rcr_wide:		std_logic_vector(16 downto 0);
		variable val_rol_wide, val_ror_wide:		std_logic_vector(15 downto 0);
		variable val_shr_short, val_sra_short:		std_logic_vector(8 downto 0);
		variable val_rol_short, val_ror_short:		std_logic_vector(7 downto 0);
	begin
		-- get shift amount usable by the functions
		if short then
			b_integer := to_integer(unsigned(in_b(2 downto 0)));
		else
			b_integer := to_integer(unsigned(in_b(3 downto 0)));
		end if;
		
		b_natural := b_integer;
		
		-- get values with carry in
		a_wide_c_low	:= (in_a & in_f(0));
		a_wide_c_high	:= (in_f(0) & in_a);
		a_short_c_low	:= (in_a(7 downto 0) & in_f(0));
		a_short_c_high	:= (in_f(0) & in_a(7 downto 0));
		a_short_no_c	:= in_a(7 downto 0);
		
		-- perform shifts
		-- shift left
		val_shl := std_logic_vector(shift_left(unsigned(a_wide_c_high), b_natural));
		
		-- shift right (logical)
		val_shr_wide	:= std_logic_vector(shift_right(unsigned(a_wide_c_low), b_natural));
		val_shr_short	:= std_logic_vector(shift_right(unsigned(a_short_c_low), b_natural));
		
		-- shift right (arithmetic)
		val_sra_wide	:= std_logic_vector(shift_right(signed(a_wide_c_low), b_natural));
		val_sra_short	:= std_logic_vector(shift_right(signed(a_short_c_low), b_natural));
		
		-- rotate left
		val_rol_wide	:= std_logic_vector(rotate_left(unsigned(in_a), b_natural));
		val_rol_short	:= std_logic_vector(rotate_left(unsigned(a_short_no_c), b_natural));
		
		-- rotate right
		val_ror_wide	:= std_logic_vector(rotate_right(unsigned(in_a), b_natural));
		val_ror_short	:= std_logic_vector(rotate_right(unsigned(a_short_no_c), b_natural));
		
		-- rotate left through carry
		val_rcl_wide	:= std_logic_vector(rotate_left(unsigned(a_wide_c_low), b_natural));
		var_rcl_short	:= std_logic_vector(rotate_left(unsigned(a_short_c_low), b_natural));
		
		-- rotate right through carry
		val_rcr_wide	:= std_logic_vector(rotate_right(unsigned(a_wide_c_low), b_natural));
		val_rcr_short	:= std_logic_vector(rotate_right(unsigned(a_short_c_low), b_natural));
		
		-- assign final values to signals
		if short then
			-- shift left
			shift_shl	<= val_shl(15 downto 0);
			carry_shl	<= val_shl(8);
			
			-- shift right (logical)
			shift_shr(15 downto 8)	<= (others => '0');
			shift_shr(7 downto 0)	<= val_shr_short(8 downto 1);
			carry_shr				<= val_shr_short(0);
			
			-- shift right (arithmetic)
			shift_sra(15 downto 8)	<= (others => '0');
			shift_sra(7 downto 0)	<= val_sra_short(8 downto 1);
			carry_sra				<= val_sra_short(0);
			
			-- rotate left
			rotate_rol(15 downto 8)	<= (others => '0');
			rotate_rol(7 downto 0)	<= val_rol_short;
			carry_rol				<= val_rol_short(0);
			
			-- rotate right
			rotate_ror(15 downto 8)	<= (others => '0');
			rotate_ror(7 downto 0)	<= val_ror_short;
			carry_ror				<= val_ror_short(7);
			
			-- rotate left through carry
			rotate_rcl(15 downto 8)	<= (others => '0');
			rotate_rcl(7 downto 0)	<= val_rcl_short(8 downto 1);
			shift_rcl				<= val_rcl_short(0);
			
			-- rotate right through carry
			rotate_rcr(15 downto 8)	<= (others => '0');
			rotate_rcr(7 downto 0)	<= val_rcr_short(8 downto 1);
			shift_rcr				<= val_rcr_short(0);
		else
			-- shift left
			shift_shl	<= val_shl(15 downto 0);
			carry_shl	<= val_shl(16);
			
			-- shift right (logical)
			shift_shr	<= val_shr_wide(16 downto 1);
			carry_shr	<= val_shr_wide(0);
			
			-- shift right (arithmetic)
			shift_sra	<= val_sra_wide(16 downto 1);
			shift_sra	<= val_sra_wide(0);
			
			-- rotate left
			rotate_rol	<= val_rol_wide;
			carry_rol	<= val_rol_wide(0);
			
			-- rotate right
			rotate_ror	<= val_ror_wide;
			carry_ror	<= val_ror_wide(15);
			
			-- rotate left through carry
			rotate_rcl	<= val_rcl_wide(16 downto 1);
			carry_rcl	<= val_rcl_wide(0);
			
			-- rotate right through carry
			rotate_rcr	<= val_rcr_wide(16 downto 1);
			carry_rcr	<= val_rcr_wide(0);
		end if;
	end process;
end a1;