--
-- Mechafinch
-- NST Handheld Project
--
-- nst_address_decoder
-- Determines whether a memory region can be cached and which device it is
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
		
		cachable:		out std_logic;
		device_id:		out device_id_t;
		device_address:	out nst_dword_t;
		boundary:		out std_logic;	-- 1 if more than one memory region is covered (raise exception)
	);
end nst_cachability;

architecture a1 of nst_cachability is
begin
	proc: process (all) is
		variable start_unsigned, end_unsigned, device_addr_unsigned:	unsigned(31 downto 0);
		variable start_cachable, end_cachable:							std_logic;
		variable start_device_id, end_device_id:						device_id_t;
	begin
		start_unsigned	:= unsigned(start_address);
		end_unsigned	:= to_unsigned(to_integer(start_unsigned) + size);
		
		-- check start & deivce
		case start_unsigned is
			when RAM_INTERFACE_MAPPING.start_address to RAM_INTERFACE_MAPPING.end_address =>
				start_cachable 			:= RAM_INTERFACE_MAPPING.cachable;
				start_device_id			:= DEVICE_RAM;
				device_addr_unsigned	:= start_unsigned - RAM_INTERFACE_MAPPING.start_address;
			
			when SPI_INTERFACE_MAPPING.start_address to SPI_INTERFACE_MAPPING.end_address =>
				start_cachable			:= SPI_INTERFACE_MAPPING.cachable;
				start_device_id			:= DEVICE_SPI;
				device_addr_unsigned	:= start_unsigned - SPI_INTERFACE_MAPPING.start_address;
			
			when KEYPAD_INTERFACE_MAPPING.start_address to KEYPAD_INTERFACE_MAPPING.end_address =>
				start_cachable 			:= KEYPAD_INTERFACE_MAPPING.cachable;
				start_device_id			:= DEVICE_KEY;
				device_addr_unsigned	:= start_unsigned - KEYPAD_INTERFACE_MAPPING.start_address;
			
			when BOOTROM_INTERFACE_MAPPING.start_address to BOOTROM_INTERFACE_MAPPING.end_address =>
				start_cachable			:= BOOTROM_INTERFACE_MAPPING.cachable;
				start_device_id			:= DEVICE_BROM;
				device_addr_unsigned	:= start_unsigned - BOOTROM_INTERFACE_MAPPING.start_address;
			
			when CACHE_CONTROL_MAPPING.start_address to CACHE_CONTROL_MAPPING.end_address =>
				start_cachable			:= CACHE_CONTROL_MAPPING.cachable;
				start_device_id			:= DEVICE_CACHE_CONTROL;
				device_addr_unsigned	:= start_unsigned - CACHE_CONTROL_MAPPING.end_address;
			
			when others => -- default uncachable to not waste space on zero/discarded
				start_cachable 			:= '0';
				start_device_id			:= DEVICE_NULL;
				device_addr_unsigned	:= 0;
		end case;
		
		-- check end
		case end_unsigned is
			when RAM_INTERFACE_MAPPING.start_address to RAM_INTERFACE_MAPPING.end_address =>
				end_cachable 	:= RAM_INTERFACE_MAPPING.cachable;
				end_device_id	:= DEVICE_RAM;
			
			when SPI_INTERFACE_MAPPING.start_address to SPI_INTERFACE_MAPPING.end_address =>
				end_cachable 	:= SPI_INTERFACE_MAPPING.cachable;
				end_device_id	:= DEVICE_SPI;
			
			when KEYPAD_INTERFACE_MAPPING.start_address to KEYPAD_INTERFACE_MAPPING.end_address =>
				end_cachable 	:= KEYPAD_INTERFACE_MAPPING.cachable;
				end_device_id	:= DEVICE_KEY;
			
			when BOOTROM_INTERFACE_MAPPING.start_address to BOOTROM_INTERFACE_MAPPING.end_address =>
				end_cachable 	:= BOOTROM_INTERFACE_MAPPING.cachable;
				end_device_id	:= DEVICE_BROM;
			
			when CACHE_CONTROL_MAPPING.start_address to CACHE_CONTROL_MAPPING.end_address =>
				end_cachable	:= CACHE_CONTROL_MAPPING.cachable;
				end_device_id	:= DEVICE_CACHE_CONTROL;
			
			when others => -- default uncachable to not waste space on zero/discarded
				end_cachable 	:= '0';
				end_device_id	:= DEVICE_NULL;
		end case;
		
		cachable 		<= start_cachable and end_cachable;
		device_id		<= start_device_id;
		device_address	<= nst_dword_t(device_addr_unsigned);
		boundary		<= '0' when start_device_id = end_device_id else '1';
	end process;
end a1;