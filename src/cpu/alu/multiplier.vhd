--
-- Mechafinch
-- NST Handheld Project
--
-- multiplier
-- Hardware multipliers
--
-- a:	input a
-- b:	input b
-- s:	'0' = unsigned, '1' = signed
--
-- p:	product
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library efxphysicallib;
use efxphysicallib.efxcomponents.all;

entity mult_signed is
	generic (
		WIDTH:	integer := 16
	)
	port (
		a:	in std_logic_vector(WIDTH - 1 downto 0);
		b:	in std_logic_vector(WIDTH - 1 downto 0);
		s:	in std_logic;
		
		p:	out std_logic_vector((WIDTH * 2) - 1 downto 0);
		c:	out std_logic;
	);
end mult_signed;

architecture hw of mult_signed is
	signal sign_a, sign_b:			std_logic;
	signal fullsize_a, fullsize_b:	std_logic_vector(17 downto 0);
	signal fullsize_p:				std_logic_vector(35 downto 0);
begin
	-- flag
	carry_proc: process (all) begin
		if to_integer(unsigned(p((WIDTH * 2) - 1 downto WIDTH))) /= 0 then
			c <= '1';
		else
			c <= '0';
		end if;
	end process;

	-- inputs
	p <= fullsize_p((WIDTH * 2) - 1 downto 0);
	
	sign_a	<=	a(WIDTH - 1) if s = '1' else
				'0';
	
	sign_b	<=	b(WIDTH - 1) if s = '1' else
				'0';

	multi_vec_proc: process (a, b) begin
		fullsize_a(17 downto WIDTH)		<= (others => sign_a);
		fullsize_a(WIDTH - 1 downto 0)	<= a;
		
		fullsize_b(17 downto WIDTH)		<= (others => sign_b);
		fullsize_b(WIDTH - 1 downto 0)	<= b;
	end process;

	inst: EFX_MULT
		port map (
			CLK		=> '0',
			CEA		=> '0',
			RSTA	=> '0',
			CEB		=> '0',
			RSTB	=> '0',
			CEO		=> '0',
			RSTO	=> '0',
			
			A		=> fullsize_a,
			B		=> fullsize_b,
			O		=> fullsize_p
		);
end hw;