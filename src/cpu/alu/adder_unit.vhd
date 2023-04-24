--
-- Mechafinch
-- NST Handheld Project
--
-- adder_unit
-- adder/subtractor with packed, flags, and so on
--  

library ieee;
use ieee.std_logic_1164.all;
use work.nst_types.all;

entity adder_unit is
	port (
		-- input
		in_a:	in nst_word_t;
		in_b:	in nst_word_t;
		in_f:	in nst_word_t;
		
		-- control
		packed_4:		in std_logic;
		packed_8:		in std_logic;
		subtract:		in std_logic;
		include_carry:	in std_logic;
		set_carry:		in std_logic;
		
		-- output
		sum:	out nst_word_t;
		flags:	out nst_word_t;
	);
end adder_unit;

architecture a1 of adder_unit is
	signal cins:		std_logic_vector(3 downto 0);
	signal int_flags:	packed4_flags_t;
begin
	-- unpack flags
	unpack: process (all) begin
		-- these two don't depend on packed status
		flags(15)	<= int_flags(3).zero;
		flags(14)	<= int_flags(3).overflow;
		flags(13)	<= int_flags(3).sign;
		flags(12)	<= int_flags(3).carry;
		
		flags(7)	<= int_flags(1).zero;
		flags(6)	<= int_flags(1).overflow;
		flags(5)	<= int_flags(1).sign;
		flags(4)	<= int_flags(1).carry;
		
		-- depends on packed 8
		if packed_8 then
			flags(11)	<= int_flags(3).zero and int_flags(2).zero;
			flags(10)	<= int_flags(3).overflow;
			flags(9)	<= int_flags(3).sign;
			flags(8)	<= int_flags(3).carry;
			
			flags(3)	<= int_flags(1).zero and int_flags(0).zero;
			flags(2)	<= int_flags(1).overflow;
			flags(1)	<= int_flags(1).sign;
			flags(0)	<= int_flags(1).carry;
		else
			flags(11)	<= int_flags(2).zero;
			flags(10)	<= int_flags(2).overflow;
			flags(9)	<= int_flags(2).sign;
			flags(8)	<= int_flags(2).carry;
			
			-- depends on packed 4
			if packed_4 then
				flags(3)	<= int_flags(0).zero;
				flags(2)	<= int_flags(0).overflow;
				flags(1)	<= int_flags(0).sign;
				flags(0)	<= int_flags(0).carry;
			else
				flags(3)	<= int_flags(3).zero and int_flags(2).zero and int_flags(1).zero and int_flags(0).zero;
				flags(2)	<= int_flags(0).overflow;
				flags(1)	<= int_flags(0).sign;
				flags(0)	<= int_flags(0).carry;
			end if;
		end if;
	end process;
	
	-- map carry ins
	carries: process (all) begin
		cins(0)	<=	set_carry or (include_carry and in_f(0));
		cins(1)	<=	(set_carry or (include_carry and in_f(4))) when packed_4 else
					int_flags(0).carry;
		cins(2)	<=	(set_carry or (include_carry and in_f(8))) when packed_4 or packed_8 else
					int_flags(1).carry;
		cins(3)	<=	(set_carry or (include_carry and in_f(12))) when packed_4 else
					int_flags(2).carry;
	end process;
	
	-- instantiate adders
	gen_adders: for i in 0 to 3 generate
		adder: entity work.add_4
			port map (
				a			=> in_a((i * 4) + 3 downto i * 4),
				b			=> in_a((i * 4) + 3 downto i * 4),
				c			=> cins(i),
				subtract	=> subtract,
				sum			=> sum((i * 4) + 3 downto i * 4),
				carry		=> int_flags(i).carry,
				sign		=> int_flags(i).sign,
				overflow	=> int_flags(i).overflow,
				zero		=> int_flags(i).zero
			);
	end generate;
end a1;