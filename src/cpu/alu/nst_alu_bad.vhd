--
-- Mechafinch
-- NST Handheld Project
--
-- nst_alu
-- ALU for the cpu
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.nst_types.all;

entity nst_alu is
	port (
		in_a:		in nst_word_t;
		in_a_high:	in nst_word_t;
		in_b:		in nst_word_t;
		in_f:		in nst_word_t;
		
		subtract:			in std_logic;
		include_carry:		in std_logic;
		set_carry:			in std_logic;
		packed_4:			in std_logic;
		packed_8:			in std_logic;
		md_signed:			in std_logic;
		short:				in std_logic;
		logic_sel:			in std_logic_vector(3 downto 0);
		-- 0000 AND
		-- 0001 OR
		-- 0010 XOR
		-- 0011 NOT
		-- 0100 SHL
		-- 0110 SHR
		-- 0111 SAR
		-- 1000 ROL
		-- 1010 ROR
		-- 1100 RCL
		-- 1110 RCR
		
		sum:		out nst_word_t;
		product:	out nst_dword_t;
		quotient:	out nst_word_t;
		remainder:	out nst_word_t;
		logic:		out nst_word_t;
		
		arithmetic_flags:	out nst_word_t;
		logic_flags:		out nst_word_t
	);
end nst_alu;

architecture a1 of nst_alu is
	-- adder_cins deals with carry from flags/set as well, adder_couts is just from the adders
	signal adder_cins: std_logic_vector(3 downto 0);
	signal adder_couts, adder_signs, adder_overflows, adder_zeros: std_logic_vector(3 downto 0);
	
	-- sub-multipliers for packed multiply
	-- the T8 has 8 embedded multipliers, so we can just use one for each case
	signal prod_8:		nst_word_t;
	signal prod_16:		nst_dword_t;
	signal prod_2x8:	packed16_t(1 downto 0);
	signal prod_4x4:	packed8_t(3 downto 0);
	
	signal in_a_full:	nst_dword_t;
	
	signal logic_internal:		nst_word_t;
	signal shift_carry:			std_logic;
begin
	-- TODO: divide
	-- divide we have to do ourselves
	in_a_full	<= in_a_high & in_a;
	quotient	<= (others => '0');
	remainder	<= (others => '0');
	
	-- logic output
	logic <= logic_internal;
	
	-- keep partial vector assignments in the same process so it doesn't cause multi-driven net bs
	multi_vector_proc: process (all) is begin
		-- logic flags
		with logic_sel select logic_flags(0) <=
			shift_carry	when "0100" | "0110" | "0111" | "1000" | "1010" | "1100" | "1110",
			'0'			when others;
	
		logic_flags(1)	<= logic_internal(15);
		logic_flags(2)	<= '0';
		logic_flags(3)	<= '1' when logic_internal = x"0000" else '0';
		
		logic_flags(15 downto 4) <= (others => '0');
		
		-- handle carries cause packed and such
		adder_cins(0)	<=	set_carry or (include_carry and in_f(0));
		
		adder_cins(1)	<=	(set_carry or (include_carry and in_f(4))) when packed_4 = '1' else
							adder_couts(0);
		
		adder_cins(2)	<=	(set_carry or (include_carry and in_f(8))) when (packed_4 = '1') or (packed_8 = '1') else
							adder_couts(1);
		
		adder_cins(3)	<=	(set_carry or (include_carry and in_f(12))) when packed_4 = '1' else
							adder_couts(2);
	
		-- get flags where they need to go
		-- carry, sign, and overflow just get routed
		arithmetic_flags(2 downto 0)	<=	(adder_overflows(0), adder_signs(0), adder_couts(0)) when packed_4 = '1' else
											(adder_overflows(1), adder_signs(1), adder_couts(1)) when packed_8 = '1' else
											(adder_overflows(3), adder_signs(3), adder_couts(3));
		
		arithmetic_flags(6 downto 4)	<=	(adder_overflows(1), adder_signs(1), adder_couts(1));
		
		arithmetic_flags(10 downto 8)	<=	(adder_overflows(3), adder_signs(3), adder_couts(3)) when packed_8 = '1' else
											(adder_overflows(2), adder_signs(2), adder_couts(2));
		
		arithmetic_flags(14 downto 12)	<=	(adder_overflows(3), adder_signs(3), adder_couts(3));
		
		-- zeroes need to pay attention to other zeroes
		arithmetic_flags(3)		<=	adder_zeros(0)						when packed_4 = '1' else
									adder_zeros(0) and adder_zeros(1)	when packed_8 = '1' else
									adder_zeros(0) and adder_zeros(1) and adder_zeros(2) and adder_zeros(3);
		
		arithmetic_flags(7)		<=	adder_zeros(1);
		
		arithmetic_flags(11)	<=	adder_zeros(2) and adder_zeros(3)	when packed_8 = '1' else
									adder_zeros(2);
		
		arithmetic_flags(15)	<=	adder_zeros(3);
	end process multi_vector_proc;
	
	-- logic stuff
	shift_proc: process (all) is
		variable shift_value:		std_logic_vector(16 downto 0);
		variable shift_value_short:	std_logic_vector(8 downto 0);
		variable b_integer:			integer;
		variable b_natural:			natural;
	begin
		if short = '0' then
			b_integer := to_integer(unsigned(in_b(3 downto 0)));
		else
			b_integer := to_integer(unsigned(in_b(2 downto 0)));
		end if;
		
		b_natural := b_integer;
		
		-- 0001 OR
		if logic_sel = "0001" then
			logic_internal <= in_a or in_b;
		
		-- 0010 XOR
		elsif logic_sel = "0010" then
			logic_internal <= in_a xor in_b;
		
		-- 0011 NOT
		elsif logic_sel = "0011" then
			logic_internal <= not in_a;
		
		-- 0100 SHL
		elsif logic_sel = "0100" then
			if b_integer = 0 then
				shift_value			:= ('0', in_a);
				shift_value_short	:= ('0', in_a(7 downto 0));
			else
				shift_value			:= std_logic_vector(shift_left(unsigned('0' & in_a), b_natural));
				shift_value_short	:= std_logic_vector(shift_left(unsigned('0' & in_a(7 downto 0)), b_natural));
			end if;
			
			if short = '0' then
				logic_internal	<= shift_value(15 downto 0);
				shift_carry		<= shift_value(16);
			else
				logic_internal(15 downto 8)	<= (others => '0');
				logic_internal(7 downto 0)	<= shift_value_short(7 downto 0);
				shift_carry					<= shift_value_short(8);
			end if;
		
		-- 0110 SHR
		elsif logic_sel = "0110" then
			if b_integer = 0 then
				shift_value			:= (in_a, '0');
				shift_value_short	:= (in_a(7 downto 0), '0');
			else
				shift_value			:= std_logic_vector(shift_right(unsigned((in_a & '0')), b_natural));
				shift_value_short	:= std_logic_vector(shift_right(unsigned((in_a(7 downto 0) & '0')), b_natural));
			end if;
			
			if short = '0' then
				logic_internal	<= shift_value(16 downto 1);
				shift_carry		<= shift_value(0);
			else
				logic_internal(15 downto 8)	<= (others => '0');
				logic_internal(7 downto 0)	<= shift_value_short(8 downto 1);
				shift_carry					<= shift_value_short(0);
			end if;
		
		-- 0111 SAR
		elsif logic_sel = "0111" then
			if b_integer = 0 then
				shift_value			:= (in_a, '0');
				shift_value_short	:= (in_a(7 downto 0), '0');
			else
				shift_value			:= std_logic_vector(shift_right(signed((in_a & '0')), b_natural));
				shift_value_short	:= std_logic_vector(shift_right(signed((in_a(7 downto 0) & '0')), b_natural));
			end if;
			
			if short = '0' then
				logic_internal	<= shift_value(16 downto 1);
				shift_carry		<= shift_value(0);
			else
				logic_internal(15 downto 8)	<= (others => '0');
				logic_internal(7 downto 0)	<= shift_value_short(8 downto 1);
				shift_carry					<= shift_value_short(0);
			end if;
		
		-- 1000 ROL
		elsif logic_sel = "1000" then
			if b_integer = 0 then
				logic_internal <= in_a;
			else
				if short = '0' then
					logic_internal <= std_logic_vector(rotate_left(unsigned(in_a), b_natural));
				else
					logic_internal(15 downto 8)	<= (others => '0');
					logic_internal(7 downto 0)	<= std_logic_vector(rotate_left(unsigned(in_a(7 downto 0)), b_natural));
				end if;
			end if;
			
			if short = '0' then
				shift_carry <= logic_internal(15);
			else
				shift_carry <= logic_internal(7);
			end if;
		
		-- 1010 ROR
		elsif logic_sel = "1010" then
			if b_integer = 0 then
				logic_internal <= in_a;
			else
				if short = '0' then
					logic_internal <= std_logic_vector(rotate_right(unsigned(in_a), b_natural));
				else
					logic_internal(15 downto 8)	<= (others => '0');
					logic_internal(7 downto 0)	<= std_logic_vector(rotate_right(unsigned(in_a(7 downto 0)), b_natural));
				end if;
			end if;
			
			shift_carry <= logic_internal(0);
		
		-- 1100 RCL
		elsif logic_sel = "1100" then
			if b_integer = 0 then
				shift_value := (in_f(0), in_a);
			else
				if short = '0' then
					shift_value := std_logic_vector(rotate_left(unsigned((in_f(0) & in_a)), b_natural));
				else
					shift_value_short := std_logic_vector(rotate_left(unsigned((in_f(0) & in_a(7 downto 0)), b_natural));
				end if;
			end if;
			
			if short = '0' then
				logic_internal	<= shift_value(15 downto 0);
				shift_carry		<= shift_value(16);
			else
				logic_internal(15 downto 8)	<= (others => '0');
				logic_internal(7 downto 0)	<= shift_value_short(7 downto 0);
				shift_carry					<= shift_value_short(8);
			end if;
			
		-- 1110 RCR
		elsif logic_sel = "1110" then
			if b_integer = 0 then
				shift_value := (in_f(0), in_a);
			else
				if short = '0' then
					shift_value := std_logic_vector(rotate_right(unsigned((in_f(0) & in_a)), b_natural));
				else
					shift_value_short := std_logic_vector(rotate_right(unsigned((in_f(0) & in_a(7 downto 0)), b_natural));
				end if;
			end if;
			
			if short = '0' then
				logic_internal	<= shift_value(15 downto 0);
				shift_carry		<= shift_value(16);
			else
				logic_internal(15 downto 8)	<= (others => '0');
				logic_internal(7 downto 0)	<= shift_value_short(7 downto 0);
				shift_carry					<= shift_value_short(8);
			end if;
		
		-- 0000 AND
		else
			logic_internal <= in_a and in_b;
		end if;
	end process shift_proc;
	
	-- multiply stuff
	mul_sel: process (all) begin
		-- choose the right product
		if packed_4 = '1' then
			-- packed outputs need some swizzling
			prodcut(31 downto 28)	<= prod_4x4(3)(7 downto 4);
			product(27 downto 24)	<= prod_4x4(2)(7 downto 4);
			product(23 downto 20)	<= prod_4x4(1)(7 downto 4);
			product(19 downto 16)	<= prod_4x4(0)(7 downto 4);
			
			product(15 downto 12)	<= prod_4x4(3)(3 downto 0);
			product(11 downto 8)	<= prod_4x4(2)(3 downto 0);
			product(7 downto 4)		<= prod_4x4(1)(3 downto 0);
			product(3 downto 0)		<= prod_4x4(0)(3 downto 0);
		elsif packed_8 = '1' then
			-- more packed swizzling
			product(31 downto 24)	<= prod_2x8(1)(15 downto 8);
			product(23 downto 16)	<= prod_2x8(0)(15 downto 8);
			
			product(15 downto 8)	<= prod_2x8(1)(7 downto 0);
			product(7 downto 0)		<= prod_2x8(0)(7 downto 0);
		elsif short then
			product(31 downto 16)	<= (others => '0');
			product(15 downto 0)	<= prod_8;
		else
			product <= prod_16;
		end if;
	end process;
	
	mul_8: entity work.multiplier
		generic map (
			WIDTH => 8
		)
		port map (
			a	=> in_a(7 downto 0),
			b	=> in_b(7 downto 0),
			s	=> md_signed,
			p	=> prod_8
		);
	
	mul_16: entity work.multiplier
		generic map (
			WIDTH => 16
		)
		port map (
			a	=> in_a,
			b	=> in_b,
			s	=> md_signed,
			p	=> prod_16
		);
	
	mul_2x8_1: entity work.multiplier
		generic map (
			WIDTH => 8
		)
		port map (
			a	=> in_a(7 downto 0),
			b	=> in_b(7 downto 0),
			s	=> md_signed,
			p	=> prod_2x8(0)
		);
	
	mul_2x8_2: entity work.multiplier
		generic map (
			WIDTH => 8
		)
		port map (
			a	=> in_a(15 downto 8),
			b	=> in_b(15 downto 8),
			s	=> md_signed,
			p	=> prod_2x8(1)
		);
	
	gen_mul_packed_4: for i in 0 to 3 generate
		mul_4x4: entity work.multiplier
			generic map (
				WIDTH => 4
			)
			port map (
				a	=> in_a((i * 4) + 3 downto i * 4),
				b	=> in_b((i * 4) + 3 downto i * 4),
				s	=> md_signed,
				p	=> prod_4x4(i)
			);
	end generate;
	
	-- adders
	gen_adders: for i in 0 to 3 generate
		adder: entity work.add_4
			port map (
				a			=> in_a((i * 4) + 3 downto i * 4),
				b			=> in_a((i * 4) + 3 downto i * 4),
				c			=> adder_cins(i),
				subtract	=> subtract,
				sum			=> sum((i * 4) + 3 downto i * 4),
				carry		=> adder_couts(i),
				sign		=> adder_signs(i),
				overflow	=> adder_overflows(i),
				zero		=> adder_zeros(i)
			);
	end generate;
end a1;