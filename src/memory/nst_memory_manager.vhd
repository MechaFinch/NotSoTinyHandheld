--
-- Mechafinch
-- NST Handheld Project
--
-- nst_memory_manager
-- Memory manager for the system. This module will handle interfacing between the harvard style CPU
-- interface and memory-mapped IO & RAM.
--
-- TODO: Add data cache usage to operation buffer
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
		
		memop_address:	in nst_dword_t;	-- memory operations
		memop_data_in:	in bulk_data_t;
		memop_data_out:	out bulk_data_t;
		memop_size:		in integer range 1 to 20;
		memop_read:		in std_logic;
		memop_write:	in std_logic;
		memop_ready:	out std_logic;
		
		-- Interrupts
		spi_interrupt:		out std_logic;
		keypad_interrupt:	out std_logic;
		boundary_fault:		out std_logic;
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
	signal decode_address:	nst_dword_t;			-- address send to the decoder
	signal decode_size:		integer range 1 to 20;	-- size sent to the decoder
	signal decode_word:		integer range 1 to 2;	-- word size from the decoder

	-- main operation buffer
	type operation_state_t is (
		IDLE,
		
		A_READ, A_WRITE,
		NA_READ,
		NA_WRITE_FIRST_READ, NA_WRITE_FIRST_WRITE,
		NA_WRITE_LAST_READ, NA_WRITE_LAST_WRITE
	);

	signal operation_buffer:	bulk_data_t;				-- data being read/written
	signal remaining_op_size:	integer range 0 to 20;		-- number of bytes left to read/write
	signal op_buffer_state:		operation_state_t := IDLE;	-- current state
	signal buffer_offset:		integer range 0 to 19;		-- where are we placing data
	
	signal operation_address:	nst_dword_t;			-- working base address
	signal operation_id:		device_id_t;			-- working device id
	signal operation_word:		integer range 1 to 2;	-- working word size
	
	-- instruction cache
	signal icache_address:	nst_dword_t;
	signal icache_data:		icache_block_data_t;
	signal icache_read:		std_logic;
	signal icache_ready:	std_logic;
	signal icache_clear:	std_logic;
	
	-- data cache
	
	-- devie operation
	signal device_id:	device_id_t;
	
	signal device_data_in:	nst_word_t;
	signal device_data_out:	nst_word_t;
	
	signal device_read:		std_logic;
	signal device_write:	std_logic;
	signal device_ready:	std_logic;
begin
	

	-- Operation Buffer
	-- While idle
	--	On read, latch operation size & address and start operation
	--	On write, latch data in, operation size, and address
	-- While reading
	--	Send read & aligned address to decoded device
	--	When device ready
	--		Latch (decoded word size) bytes
	--		Increment buffer offset by (decoded word size)
	--		If first word not aligned, latch only the upper byte(s)
	-- While writing
	--	If first word not aligned
	--		Read word
	--		Write read lower byte(s) and input upper byte
	--		Increment to first aligned word
	--	If last word not aligned 
	--		Read word
	--		Write read upper byte(s) and input lower byte
	--	If aligned
	--		Write word
	--		Increment offset by word size
	
	op_buffer_comb_proc: process (all) is
	begin
		-- combinational logic related to the op buffer
		decode_address <= 	memop_address when (memop_read = '1' or memop_write = '1') else
							icache_read_address;
		
		decode_size <=	memop_size when (memop_read = '1' or memop_write = '1') else
						8;
		
		icache_data	<= operation_buffer(7 downto 0);
		
		case op_buffer-state is
			when IDLE =>
				device_read		<= '0';
				device_write	<= '0';
			
			when A_READ =>
				device_read		<= '1';
				device_write	<= '0';
				
			when A_WRITE =>
				device_read		<= '0';
				device_write	<= '1';
				
			when NA_READ =>
				device_read		<= '1';
				device_write	<= '0';
				
			when NA_WRITE_FIRST_READ =>
				device_read		<= '1';
				device_write	<= '0';
				
			when NA_WRITE_FIRST_WRITE =>
				device_read		<= '0';
				device_write	<= '1';
				
			when NA_WRITE_LAST_READ =>
				device_read		<= '1';
				device_write	<= '0';
				
			when NA_WRITE_LAST_WRITE =>
				device_read		<= '0';
				device_write	<= '1';
		end case;
	end process;
	
	op_buffer_state_proc: process (device_exec_clk	) is
		variable aligned:	boolean := true;
	begin
		-- Aligned to device word size?
		device_aligned	:=	(memop_address(0) = '0')			when decode_word = 2 else
							(memop_address(1 downto 0) = "00")	when decode_word = 4 else
							(memop_address(2 downto 0) = "000")	when decode_word = 8 else
							true;
		
		-- Aligned to dcache block size?
		cache_aligned	:= memop_address(1 downto 0) = "00";
	
		if rising_edge(device_exec_clk) then
			case op_buffer_state is
				-- IDLE: Wait for an operation
				when IDLE =>
					if memop_read then
						remaining_op_size	<= memop_size;
						buffer_offset		<= 0;
						
						-- Read.
						if decode_cachable then
							operation_id		<= DCACHE;
							operation_address	<= memop_address; -- global address
							operation_word		<= 4;
							
							op_buffer_state	<=	A_READ when cache_aligned else
												NA_READ;
						else
							operation_id		<= decode_device_id;
							operation_address	<= decode_device_address; -- local address
							operation_word		<= decode_word;
							
							op_buffer_state	<=	A_READ when device_aligned else
												NA_READ;
						end if;
					elsif memop_write then
						-- Write.
						remaining_op_size	<= memop_size;
						buffer_offset		<= 0;
						
						-- Read.
						if decode_cachable then
							operation_id		<= DCACHE;
							operation_address	<= memop_address; -- global address
							operation_word		<= 4;
							
							op_buffer_state	<=	A_WRITE when cache_aligned else
												NA_WRITE_FIRST_READ;
						else
							operation_id		<= decode_device_id;
							operation_address	<= decode_device_address; -- local address
							operation_word		<= decode_word;
							
							op_buffer_state	<=	A_WRITE when device_aligned else
												NA_WRITE_FIRST_READ;
						end if;
					elsif icache_read then
						-- Read, always aligned
						remaining_op_size	<= 8;
						buffer_offset		<= 0;
						operation_id		<= decode_device_id;
						operation_address	<= icache_read_address;
						operation_word		<= decode_word;
						op_buffer_state 	<= A_READ;
					else
						-- No action.
						op_buffer_state <= IDLE;
					end if;
				
				-- A_READ: Aligned read, no special action
				when A_READ =>
					if device_ready = '1' then
						
					else
						-- not ready, wait
						op_buffer_state <= A_READ;
					end if;
					
				-- A_WRITE: Aligned write, no special action
				when A_WRITE =>
					if device_ready = '1' then
					
					else
						-- not ready, wait
						op_buffer_state <= A_WRITE;
					end if;
				
				-- NA_READ: Non-aligned read, upper byte(s) discarded
				when NA_READ =>
					if device_ready = '1' then
					
					else
						-- not ready, wait
						op_buffer_state <= NA_READ;
					end if;
				
				-- NA_WRITE_FIRST_READ: Non-aligned write, first word, read for lower byte(s)
				when NA_WRITE_FIRST_READ =>
					if device_ready = '1' then
					
					else
						-- not ready, wait
						op_buffer_state <= NA_WRITE_FIRST_READ;
					end if;
				
				-- NA_WRITE_FIRST_WRITE: Non-aligned write, first word, write using mixed bytes
				when NA_WRITE_FIRST_WRITE =>
					if device_ready = '1' then
					
					else
						-- not ready, wait
						op_buffer_state <= NA_WRITE_FIRST_WRITE;
					end if;
				
				-- NA_WRITE_LAST_READ: Non-aligned write, last word, read for upper byte(s)
				when NA_WRITE_LAST_READ =>
					if device_ready = '1' then
					
					else
						-- not ready, wait
						op_buffer_state <= NA_WRITE_LAST_READ;
					end if;
				
				-- NA_WRITE_LAST_WRITE: Non-aligned write, last word, write using mixed bytes
				when NA_WRITE_LAST_WRITE =>
					if device_ready = '1' then
					
					else
						-- not ready, wait
						op_buffer_state <= NA_WRITE_LAST_WRITE;
					end if;
			end case;
		end if;
	end process;
	
	-- Entities
	-- Address Decode
	addr_decode: entity work.nst_address_decoder
		port map (
			start_address	=> decode_address,
			size			=> decode_size,
			
			cachable		=> decode_cachable,
			device_id		=> decode_device_id,
			device_address	=> decode_device_address,
			device_op_size	=> decode_word,
			boundary		=> boundary_fault
		);
	
	-- Caches
	instruction_cache: entity work.nst_instruction_cache
		port map (
			address		=> irb_address,
			data		=> irb_data,
			data_ready	=> irb_ready,
			
			mem_address	=> icache_address,
			mem_data	=> icache_data,
			mem_read	=> icache_read,
			mem_ready	=> icache_reay,
			
			clear	=> icache_clear,
			
			exec_clk	=> device_exec_clk
		);
	
	-- Devices
	device_op: entity work.nst_memory_device_operator
		port map (
			memory_bus_IN		=> memory_bus_IN,
			memory_bus_OUT		=> memory_bus_OUT,
			memory_bus_OE		=> memory_bus_OE,
			mem_addr_low_clk	=> mem_addr_low_clk,
			mem_addr_high_clk	=> mem_addr_high_clk,
			memory_read			=> memory_read,
			memory_write		=> memory_write,
			
			spi_sel			=> spi_sel,
			spi_cd			=> spi_cd,
			spi_cido		=> spi_cido,
			spi_codi		=> spi_codi,
			spi_clk			=> spi_clk,
			spi_interrupt	=> spi_interrupt,
			
			keypad_sel			=> keypad_sel,
			keypad_data			=> keypad_data,
			keypad_interrupt	=> keypad_interrupt,
			
			leds	=> leds,
			btn_1	=> btn_1,
			btn_2	=> btn_2,
			
			device_exec_clk	=> device_exec_clk,
			device_ram_clk	=> device_ram_clk,
			device_spi_clk	=> device_spi_clk,
			
			device_id	=> operation_device_id,
			device_addr	=> operation_address,
			
			data_in		=> device_data_in,
			data_out	=> device_data_out,
			
			mem_read	=> device_read,
			mem_write	=> device_write,
			ready		=> device_ready
		);
		
end a1;