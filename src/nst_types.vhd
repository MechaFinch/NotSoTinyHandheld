--
-- Mechafinch
-- NST Handheld Project
--
-- nst_types
-- Types for the NST cpu
--

library ieee;
use ieee.std_logic_1164.all;

package nst_types is
	-- aliases for data widths
	subtype nst_byte_t is std_logic_vector(7 downto 0);
	subtype nst_word_t is std_logic_vector(15 downto 0);
	subtype nst_dword_t is std_logic_vector(31 downto 0);
	
	-- flags
	type flags_t is record
		carry:		std_logic;
		sign:		std_logic;
		overflow:	std_logic;
		zero:		std_logic;
	end record;
	
	-- packed arrays
	type packed4_single_t is array (3 downto 0) of std_logic_vector(3 downto 0);
	type packed4_double_t is array (7 downto 0) of std_logic_vector(3 downto 0);
	type packed8_single_t is array (1 downto 0) of std_logic_vector(7 downto 0);
	type packed8_double_t is array (3 downto 0) of std_logic_vector(7 downto 0);
	type packed16_single_t is array (0 downto 0) of std_logic_vector(15 downto 0);
	type packed16_double_t is array (1 downto 0) of std_logic_vector(15 downto 0);
	
	type packed4_flags_t is array (3 downto 0) of flags_t;
	type packed8_flags_t is array (1 downto 0) of flags_t;
	
	-- cache related
	type icache_block_data_t is array (7 downto 0) of nst_byte_t;
	type dcache_block_data_t is array (3 downto 0) of nst_byte_t;

	-- word outputs of the bulk memory buffer
	type bulk_data_t is array (19 downto 0) of nst_byte_t;
	
	-- shared enums
	type device_id_t is (
		-- internal
		DEVICE_BROM,
		DEVICE_CACHE_CONTROL,
		DEVICE_DEBUG,
		
		-- external
		DEVICE_RAM,
		DEVICE_SPI,
		DEVICE_KEY,
		
		DEVICE_NULL
	);
end nst_types;