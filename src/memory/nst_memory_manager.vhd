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
--	There are three sources of memory operations:
--		Instruction Cache	Always reading 8 byte aligned blocks
--		Data Cache			Performs random access of 4 byte aligned blocks in cacheable memory regions
--		Bulk Data Buffer	Performs random access of 1-20 byte non-aligned blocks
--		IP Readahead buffer	Always reading 8 byte aligned blocks
--
--	If the block being operated upon by the BDB is fully cacheable, it will be directed to the data
--	cache. If any part is not, it will be used directly. The same is true of the IRB with the
--	instruction cache.
--	
--	For each Buffer, when operating via its respective cache that cache's ready signal is used.
--	When operating directly, the ready signal is set when the operation completes. 
--
--	Operations
--		A memory manager operation consists of either a read or write operation of a number of
--		bytes between 1 and 20. These operations are atomic from the perspective of the CPU.
--
--		The manager operates by performing actions 1 or 2 bytes at a time on memory devices as
--		alignment and device operation allow. 
--
--		When the memory manager is ready to begin a new operation, the following priorities are
--		applied:
--			1.	BDB Direct Access
--			2.	Data Cache
--			3.	IRB/Instruction Cache
--		Although BDB and Data Cache operations appear exclusive, a write to a cacheable region
--		followed by a non-cacheable operation will result in such a contention, as a write is
--		considered ready as soon as it is latched by the cache.
--		

architecture a1 of nst_memory_manager is
	-- this implementation of the memory manager only works with one memory access at a time. It
	-- may be beneficial to reimplement allowing concurrent access by the instruction and data
	-- interfaces
	
	-- instruction cache signals
	signal irb_cachable:	std_logic;
	signal icache_address:	nst_dword_t;
	signal icache_data:		icache_block_data_t;
	signal icache_read:		std_logic;
	signal icache_ready:	std_logic;
	
	-- data cache signals
	signal bdb_cachable:		std_logic;
	signal dcache_bdb_data_in:	dcache_block_data_t;
	signal dcache_bdb_data_out:	dcache_block_data_t;
	signal dcache_mem_data_in:	dcache_block_data_t;
	signal dcache_mem_data_out:	dcache_block_data_t;
	
	signal dcache_address:	nst_dword_t;
	signal dcache_read:		std_logic;
	signal dcache_write:	std_logic;
	signal dcache_ready:	std_logic;
	
	-- ram interface signals
	signal ram_address:					nst_dword_t;
	signal ram_data_in, ram_data_out:	nst_word_t;
	signal ram_read, ram_write:			std_logic;
	signal ram_ready:					std_logic;

	-- spi interface signals
	signal spi_interface_address:		std_logic_vector(1 downto 0);
	signal spi_data_in, spi_data_out:	nst_byte_t;
	signal spi_mem_read, spi_mem_write:	std_logic;
	signal spi_interrupt:				std_logic;
	
	-- operation signals
	signal operation_buffer:	bulk_data_t;
	
begin

	-- TODO
	-- unify BDB interface - operate dcache invisibly cause block size/alignment usually wont match

	-- cachability detection
	icachability: entity work.nst_cachability
		port map (
			start_address	<= irb_address,
			size			<= 8,
			cachable		<= irb_cachable
		);
	
	dcachability: entity work.nst_cachability
		port map (
			start_address	<= bdb_address,
			size			<= bdb_op_size,
			cachable		<= bdb_cachable
		);
	
	-- cache instances
	icache: entity work.nst_instruction_cache
		port map (
			address		<= irb_address,
			data		<= irb_data,
			data_ready	<= irb_ready,
			
			mem_address	<= icache_address,
			mem_data	<= icache_data,
			mem_read	<= icache_read,
			mem_ready	<= icache_ready,
			
			exec_clk	<= device_exec_clk
		);
	
	dcache: entity work.nst_data_cache
		port map (
			address		<= bdb_address,
			data_in		<= dcache_bdb_data_in,
			data_out	<= dcache_bdb_data_out,
			
			cpu_read	<= bdb_read,
			cpu_write	<= bdb_write,
			data_ready	<= bdb_ready,
			
			mem_address		<= dcache_address,
			mem_data_in		<= dcache_mem_data_in,
			mem_data_out	<= dcache_mem_data_out,
			
			mem_read	<= dcache_read,
			mem_write	<= dcache_write,
			mem_ready	<= dcache_ready,
			
			exec_clk	<= device_exec_clk
		);

	-- interface instances
	ram: entity work.nst_ram_interface
		port map (
			data_in		=> ram_data_in,
			data_out	=> ram_data_out,
			address		=> ram_address,
			
			exec_clk	=> device_exec_clk,
			mem_clk		=> device_mem_clk,
			
			read_in		=> ram_read,
			write_in	=> ram_write,
			ready		=> ram_ready,
			
			bus_in	=> memory_bus_IN,
			bus_out	=> memory_bus_OUT,
			bus_oe	=> memory_bus_OE,
			
			address_low_clk		=> mem_addr_low_clk,
			address_high_clk	=> mem_addr_high_clk,
			read_out			=> memory_read,
			write_out			=> memory_write
		);
	
	spi: entity work.nst_spi_interface
		port map (
			address		<= spi_interface_address,
			data_in		<= spi_data_in,
			data_out	<= spi_data_out,
			
			exec_clk	<= device_exec_clk,
			spi_clk		<= device_spi_clk,
			mem_clk		<= device_mem_clk,
			mem_read	<= spi_mem_read,
			mem_write	<= spi_mem_write,
			
			interrupt	<= spi_interrupt,
			
			clk		<= spi_clk,
			sel		<= spi_sel,
			cd		<= spi_cd,
			cido	<= spi_cido,
			codi	<= spi_codi
		);
end a1;