--
-- Mechafinch
-- NST Handheld Project
--
-- nst_cachability
-- Determines whether a memory region can be cached
-- Fundamental assumption: this will never cover more than 2 memory regions
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.nst_types.all;
use work.nst_constants.all;

entity nst_cachability is
	port (
		start_address:	in nst_dword_t;
		size:			in integer range 1 to 20;
		
		cachable:	out std_logic;
	);
end nst_cachability;

architecture a1 of nst_cachability is
begin
	proc: process (all) is
		variable start_unsigned, end_unsigned:	unsigned(31 downto 0);
		variable start_cachable, end_cachable:	std_logic;
	begin
		start_unsigned	:= unsigned(start_address);
		end_unsigned	:= to_unsigned(to_integer(start_unsigned) + size);
		
		-- check start
		case start_unsigned is
			when RAM_INTERFACE_MAPPING.start_address to RAM_INTERFACE_MAPPING.end_address =>
				start_cachable := RAM_INTERFACE_MAPPING.cachable;
			
			when SPI_INTERFACE_MAPPING.start_address to SPI_INTERFACE_MAPPING.end_address =>
				start_cachable := SPI_INTERFACE_MAPPING.cachable;
			
			when KEYPAD_INTERFACE_MAPPING.start_address to KEYPAD_INTERFACE_MAPPING.end_address =>
				start_cachable := KEYPAD_INTERFACE_MAPPING.cachable;
			
			when BOOTROM_INTERFACE_MAPPING.start_address to BOOTROM_INTERFACE_MAPPING.end_address =>
				start_cachable := BOOTROM_INTERFACE_MAPPING.cachable;
			
			when others => -- default uncachable to not waste space on zero/discarded
				start_cachable := '0';
		end case;
		
		-- check end
		case start_unsigned is
			when RAM_INTERFACE_MAPPING.start_address to RAM_INTERFACE_MAPPING.end_address =>
				end_cachable := RAM_INTERFACE_MAPPING.cachable;
			
			when SPI_INTERFACE_MAPPING.start_address to SPI_INTERFACE_MAPPING.end_address =>
				end_cachable := SPI_INTERFACE_MAPPING.cachable;
			
			when KEYPAD_INTERFACE_MAPPING.start_address to KEYPAD_INTERFACE_MAPPING.end_address =>
				end_cachable := KEYPAD_INTERFACE_MAPPING.cachable;
			
			when BOOTROM_INTERFACE_MAPPING.start_address to BOOTROM_INTERFACE_MAPPING.end_address =>
				end_cachable := BOOTROM_INTERFACE_MAPPING.cachable;
			
			when others => -- default uncachable to not waste space on zero/discarded
				end_cachable := '0';
		end case;
		
		-- AND
		cachable <= start_cachable and end_cachable;
	end process;
end a1;