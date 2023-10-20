--
-- Mechafinch
-- NST Handheld Project
--
-- nst_memory_manager
-- Memory manager for the system. This module will handle interfacing between the harvard style CPU
-- interface and memory-mapped IO & RAM.
--

library ieee;
use ieee.std_logic_1164.all;
use work.nst_types.all;

entity nst_memory_manager is
	port (
		---- Device Pins ----
		-- RAM, passed to nst_ram_interface
		memory_bus_IN:		in std_logic_vector(15 downto 0);
		memory_bus_OUT:		out std_logic_vector(15 downto 0);
		memory_bus_OE:		out std_logic;
		mem_addr_low_clk:	out std_logic;
		mem_addr_high_clk:	out std_logic;
		memory_read:		out std_logic;
		memory_write:		out std_logic;
		
		-- SPI, passed to nst_spi_interface
		spi_sel:	out std_logic_vector(2 downto 0);
		spi_cd:		out std_logic;
		spi_cido:	in std_logic;
		spi_codi:	out std_logic;
		spi_clk:	out std_logic;
		
		-- Keys, passed to nst_keypad_interface
		keypad_sel:		out std_logic_vector(4 downto 0);
		keypad_data:	in std_logic;
		
		-- Fireant, passed to ???
		leds:	out std_logic_vector(3 downto 0);
		btn_1:	in std_logic;
		btn_2:	in std_logic;
		
		---- Processor Interface ----
		-- Clocks
		device_exec_clk:	in std_logic;
		device_mem_clk:		in std_logic;
		device_spi_clk:		in std_logic;
		
		-- CPU signals
		irb_address:	in nst_dword_t;	-- IP readahead buffer
		irb_data:		out icache_block_data_t;
		irb_ready:		out std_logic;
		
		bdb_address:	in nst_dword_t; -- bulk data buffer
		bdb_data_in:	in bulk_data_t;
		bdb_op_size:	in std_logic_vector(4 downto 0);	-- number of bytes remaining in operation
		bdb_read:		in std_logic;
		bdb_write:		in std_logic;
		bdb_data_out:	out bulk_data_t;
		bdb_data_size:	out std_logic_vector(4 downto 0);	-- number of bytes read/written this ready cycle
		bdb_ready:		out std_logic
	);
end nst_memory_manager;

-- Operation
-- The memory manager operates off of two buffers. One is the dcache operation buffer, the other
-- the memory operation buffer. The dcache operation buffer handles requests from the data cache,
-- and thus does not perform caching. It has precedent over the memory operation buffer as it works
-- to fullfill its requests. The memory operation buffer handles requests from the CPU, directly
-- from the read/write unit and indirectly from the IRB via the instruction cache.
-- Each operation buffer is used to break memory operations down into sizes appropriate to the
-- target device, and to handle un-aligned accesses of multi-byte devices. 
-- If the target memory region is cachable, the memory operation buffer will operate via the data
-- cache. If the request comes from the read/write unit, this will be done strongly and the data
-- cache will correct misses. If the request comes from the instruction cache, a miss will defer to
-- direct device operation rather than affecting data cache contents.
--

architecture a1 of nst_memory_manager is
	
begin

end a1;