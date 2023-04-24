--
-- Mechafinch
-- NST Handheld Project
--
-- multiply_unit
-- Handles all multiplication variants
--

library ieee;
use ieee.std_logic_1164.all;
use work.nst_types.all;

entity multiply_unit is
	port (
		-- input
		in_a:	nst_word_t;
		in_b:	nst_word_t;
		
		-- control
		packed_4:	in std_logic;
		packed_8:	in std_logic;
		short:		in std_logic;
		
		md_signed:	in std_logic;
		
		-- output
		product:	out nst_dword_t;
		flags:		out nst_word_t
	);
end multiply_unit;

architecture a1 of multiply_unit is
	signal product_8:	nst_word_t;
	signal product_16:	nst_dword_t;
	signal product_2x8:	packed16_double_t;
	signal product_4x4:	packed8_double_t;
	
	signal flags_8, flags_16:	flags_t;
	signal flags_2x8:			packed8_flags_t;
	signal flags_4x4:			packed4_flags_t;
begin
	-- select product and flags
	proc_select: process (all) begin
		if packed_4 = '1' then
			-- 4x4
			-- upper
			product(31 downto 28)	<= product_4x4(3)(7 downto 4);
			product(27 downto 24)	<= product_4x4(2)(7 downto 4);
			product(23 downto 20)	<= product_4x4(1)(7 downto 4);
			product(19 downto 16)	<= product_4x4(0)(7 downto 4);
			
			-- lower
			product(15 downto 12)	<= product_4x4(3)(3 downto 0);
			product(11 downto 8)	<= product_4x4(2)(3 downto 0);
			product(7 downto 4)		<= product_4x4(1)(3 downto 0);
			product(3 downto 0)		<= product_4x4(0)(3 downto 0);
			
			-- flags
			flags(15)	<= flags_4x4(3).zero;
			flags(14)	<= flags_4x4(3).overflow;
			flags(13)	<= flags_4x4(3).sign;
			flags(12)	<= flags_4x4(3).carry;
			
			flags(11)	<= flags_4x4(2).zero;
			flags(10)	<= flags_4x4(2).overflow;
			flags(9)	<= flags_4x4(2).sign;
			flags(8)	<= flags_4x4(2).carry;
			
			flags(7)	<= flags_4x4(1).zero;
			flags(6)	<= flags_4x4(1).overflow;
			flags(5)	<= flags_4x4(1).sign;
			flags(4)	<= flags_4x4(1).carry;
			
			flags(3)	<= flags_4x4(0).zero;
			flags(2)	<= flags_4x4(0).overflow;
			flags(1)	<= flags_4x4(0).sign;
			flags(0)	<= flags_4x4(0).carry;
		
		elsif packed_8 = '1' then
			-- 2x8
			-- upper
			product(31 downto 24)	<= product_2x8(1)(15 downto 8);
			product(23 downto 16)	<= product_2x8(0)(15 downto 8);
			
			-- lower
			product(15 downto 8)	<= product_2x8(1)(7 downto 0);
			product(7 downto 0)		<= product_2x8(0)(7 downto 0);
			
			-- flags
			flags(15 downto 12)	<= (others => '0');
			flags(7 downto 4)	<= (others => '0');
			
			flags(11)	<= flags_2x8(1).zero;
			flags(10)	<= flags_2x8(1).overflow;
			flags(9)	<= flags_2x8(1).sign;
			flags(8)	<= flags_2x8(1).carry;
			
			flags(3)	<= flags_2x8(0).zero;
			flags(2)	<= flags_2x8(0).overflow;
			flags(1)	<= flags_2x8(0).sign;
			flags(0)	<= flags_2x8(0).carry;
		
		elsif md_short then
			-- 1x8
			product(31 downto 16)	<= (others => '0');
			product(15 downto 0)	<= product_8;
			
			flags(15 downto 4)	<= (others => '0');
			
			flags(3)	<= flags_8.zero;
			flags(2)	<= flags_8.overflow;
			flags(1)	<= flags_8.sign;
			flags(0)	<= flags_8.carry;
		
		else
			-- 1x16
			product	<= product_16;
			
			flags(15 downto 4)	<= (others => '0');
			
			flags(3)	<= flags_16.zero;
			flags(2)	<= flags_16.overflow;
			flags(1)	<= flags_16.sign;
			flags(0)	<= flags_16.carry;
			
		end if;
	end process;
	
	-- generate flags
	proc_flags: process (all) begin
		-- copy carry to overflow
		flags_8.overflow		<= flags_8.carry;
		flags_16.overflow		<= flags_16.carry;
		
		flags_2x8(0).overflow	<= flags_2x8(0).carry;
		flags_2x8(1).overflow	<= flags_2x8(1).carry;
		
		flags_4x4(3).overflow	<= flags_4x4(3).carry;
		flags_4x4(2).overflow	<= flags_4x4(3).carry;
		flags_4x4(1).overflow	<= flags_4x4(3).carry;
		flags_4x4(0).overflow	<= flags_4x4(3).carry;
		
		-- sign and zero depend on if the operation is wide
		if md_short = '1' then
			-- short
			-- 8 bit
			flags_8.sign	<= product_8(7);
			flags_8.zero	<= '1' when product_8(7 downto 0) = 8x"00" else '0';
			
			-- 16 bit
			flags_16.sign	<= product_16(15);
			flags_16.zero	<= '1' when product_16(15 downto 0) = 16x"0000" else '0';
			
			-- packed 8s
			flags_2x8(1).sign	<= product_2x8(1)(7);
			flags_2x8(0).sign	<= product_2x8(0)(7);
			
			flags_2x8(1).zero	<= '1' when product_2x8(1)(7 downto 0) = 8x"00" else '0';
			flags_2x8(0).zero	<= '1' when product_2x8(0)(7 downto 0) = 8x"00" else '0';
			
			-- packed 4s
			flags_4x4(3).sign	<= product_4x4(3)(3);
			flags_4x4(2).sign	<= product_4x4(2)(3);
			flags_4x4(1).sign	<= product_4x4(1)(3);
			flags_4x4(0).sign	<= product_4x4(0)(3);
			
			flags_4x4(3).zero	<= '1' when product_4x4(3)(3 downto 0) = 4x"0" else '0';
			flags_4x4(2).zero	<= '1' when product_4x4(2)(3 downto 0) = 4x"0" else '0';
			flags_4x4(1).zero	<= '1' when product_4x4(1)(3 downto 0) = 4x"0" else '0';
			flags_4x4(0).zero	<= '1' when product_4x4(0)(3 downto 0) = 4x"0" else '0';
		else
			-- wide
			-- 8 bit
			flags_8.sign	<= product_8(15);
			flags_8.zero	<= '1' when product_8 = 16x"0000" else '0';
			
			-- 16 bit
			flags_16.sign	<= product_16(31);
			flags_16.zero	<= '1' when product_16 = 32x"00000000" else '0';
			
			-- packed 8s
			flags_2x8(1).sign	<= product_2x8(1)(15);
			flags_2x8(0).sign	<= product_2x8(0)(15);
			
			flags_2x8(1).zero	<= '1' when product_2x8(1) = 16x"0000" else '0';
			flags_2x8(0).zero	<= '1' when product_2x8(0) = 16x"0000" else '0';
			
			-- packed 4s
			flags_4x4(3).sign	<= product_4x4(3)(7);
			flags_4x4(2).sign	<= product_4x4(2)(7);
			flags_4x4(1).sign	<= product_4x4(1)(7);
			flags_4x4(0).sign	<= product_4x4(0)(7);
			
			flags_4x4(3).zero	<= '1' when product_4x4(3) = 8x"00" else '0';
			flags_4x4(2).zero	<= '1' when product_4x4(2) = 8x"00" else '0';
			flags_4x4(1).zero	<= '1' when product_4x4(1) = 8x"00" else '0';
			flags_4x4(0).zero	<= '1' when product_4x4(0) = 8x"00" else '0';
		end if;
	end process;
	
	-- instantiate hardware multipliers (with flags)
	mul_8: entity work.multiplier
		generic map (
			WIDTH => 8
		)
		port map (
			a	=> in_a(7 downto 0),
			b	=> in_b(7 downto 0),
			s	=> md_signed,
			p	=> product_8,
			c	=> flags_8.carry;
		);
	
	mul_16: entity work.multiplier
		generic map (
			WIDTH => 16
		)
		port map (
			a	=> in_a,
			b	=> in_b,
			s	=> md_signed,
			p	=> product_16,
			c	=> flags_16.carry;
		);
	
	mul_2x8_1: entity work.multiplier
		generic map (
			WIDTH => 8
		)
		port map (
			a	=> in_a(7 downto 0),
			b	=> in_b(7 downto 0),
			s	=> md_signed,
			p	=> product_2x8(0),
			c	=> flags_2x8(0).carry;
		);
	
	mul_2x8_2: entity work.multiplier
		generic map (
			WIDTH => 8
		)
		port map (
			a	=> in_a(15 downto 8),
			b	=> in_b(15 downto 8),
			s	=> md_signed,
			p	=> product_2x8(1),
			c	=> flags_2x8(1).carry;
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
				p	=> product_4x4(i),
				c	=> flags_2x8(i).carry;
			);
	end generate;
end a1;