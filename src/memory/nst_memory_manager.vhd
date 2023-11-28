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
		NA_READ_FIRST, NA_READ_LAST,
		NA_WRITE_FIRST_READ, NA_WRITE_FIRST_WRITE,
		NA_WRITE_LAST_READ, NA_WRITE_LAST_WRITE
	);

	signal operation_buffer:	bulk_data_t;						-- data being read/written
	signal remaining_op_size:	integer range 0 to 20;				-- number of bytes left to read/write
	signal op_buffer_state:		operation_state_t := IDLE;			-- current state
	signal buffer_offset:		integer range 0 to 19;				-- where are we placing data
	
	signal operation_address:	nst_dword_t;						-- working base address
	signal operation_id:		device_id_t;						-- working device id
	signal operation_word:		integer range 1 to 4;				-- working word size
	signal operation_ready:		std_logic;							-- working ready signal
	signal operation_data_in:	array (3 downto 0) of nst_byte_t;	-- working data source
	
	-- dcache operation buffer
	type dcop_state_t is (
		IDLE,
		A_READ,
		A_WRITE
	);
	
	signal dcop_buffer:		array (3 downto 0) of nst_byte_t;
	signal dcop_remaining:	integer range 0 to 4;
	signal dcop_state:		dcop_state_t := IDLE;
	signal dcop_offset:		integer range 0 to 3;
	
	signal dcop_address:	nst_dword_t;
	signal dcop_id:			device_id_t;
	signal dcop_word:		integer range 1 to 2;
	signal dcop_ready:		std_logic;
	signal dcop_data_in:	array (3 downto 0) of nst_byte_t;
	
	-- instruction cache
	signal icache_address:	nst_dword_t;
	signal icache_data:		icache_block_data_t;
	signal icache_read:		std_logic;
	signal icache_ready:	std_logic;
	signal icache_clear:	std_logic;
	
	-- data cache
	signal dcache_data_in:		dcache_block_data_t;
	signal dcache_data_out:		dcache_block_data_t;
	signal dcache_ready_out:	std_logic;
	
	-- devie operation
	signal device_id:	device_id_t;
	
	signal device_data_in:	nst_word_t;
	signal device_data_out:	nst_word_t;
	
	signal device_read:		std_logic;
	signal device_write:	std_logic;
	signal device_ready:	std_logic;
	
	-- ready state
	signal known_address:	nst_dword_t := 32x"FFFFFFFF";
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
	
	-- Operation Buffer
	-- IDLE:
	--	memop_read high -> start read op
	--		- set remaining_op_size to memop_size
	--		- reset buffer_offset
	--		- set operation_id to device/dcache
	--		- set operation_address to the aligned global address for dcache or local address for device
	--		- set operation_word to the device word size (4 for dcache)
	--		- set op_buffer_state to aligned/not aligned read
	--	memop_write high -> start write op
	--		- set remaining_op_size to memop_size
	--		- reset buffer_offset
	--		- latch memop_data_in to operation_buffer
	--		- set operation_id to device/dcache
	--		- set operation_address to aligned global/device address
	--		- set operation_word to device word size (4 for dcache)
	--		if aligned:
	--			- set dcache_data_in or device_data_in to the start of memop_data_in
	--			- set op_buffer_state according to whether multiple words are required
	--		otherwise
	--			- set op_buffer_state to not aligned write first (read)
	--	icache_read high -> start read for icache
	--		- set remaining_op_size to 8
	--		- reset buffer_offset
	--		- set operation_id to device id
	--		- set operation_address to local address
	--		- set operation_word to device word size
	--		- set op_buffer_state to aligned read
	--
	-- ALIGNED READ:
	--	when the operation is ready;
	--		- latch the read bytes into operation_buffer
	--		- increment buffer_offset by operation_word
	--		- increment operation_address by operation_word
	--		- decrement remaining_op_size by operation_word
	--		if the next amount remaining is zero:
	--			- set ready high
	--			- set op_buffer_state to idle
	--		if the next amount remaining is less than the word size:
	--			- set op_buffer_state to not aligned read last
	--		otherwise
	--			- set op_buffer_state to aligned read
	--
	-- ALIGNED WRITE:
	--	when the operation is ready:
	--		- increment buffer_offset by operation_word
	--		- increment operation_address by operation_word
	--		- decrement remaining_op_size by operation_word
	--		if the next amount remaining is zero:
	--			- set ready high
	--			- set op_buffer_state to idle
	--		if the next amount remaining is less than the word size
	--			- set op_buffer_state to not aligned write last (read)
	--		otherwise
	--			- set dcache_data_in or device_data_in to the next set of operation_buffer bytes
	--			- set op_buffer_state to aligned write
	--
	-- NOT ALIGNED READ FIRST:
	--	when the operation is ready;
	--		- latch the read bytes into operation_buffer, accounting for misalignment
	--		- increment buffer_offset by (operation_word - misalignment)
	--		- decrement remaining_op_size by (operation_word - misalignment)
	--		- increment operation_address by operation_word
	--		if the next amount remaining is zero:
	--			- set ready high
	--			- set op_buffer_state to idle
	--		if the next amount remaining is less than the word size:
	--			- set op_buffer_state to not aligned read last
	--		otherwise
	--			- set op_buffer_state to aligned read
	--
	-- NOT ALIGNED READ LAST
	--	when the operation is ready;
	--		- latch the read bytes into operation_buffer, accounting for misalignment
	--		- set ready high
	--		- set op_buffer_state to idle
	--
	-- NOT ALIGNED WRITE FIRST (READ):
	--	when the operation is ready:
	--		- latch read bytes into dcache_data_in or device_data_in, lower part
	--		- latch misaligned operation_buffer bytes into dcache_data_in or device_data_in, upper part
	--		- set op_buffer_state to not aligned write first (write)
	--
	-- NOT ALIGNED WRITE FIRST (WRITE):
	--	when the operation is ready:
	--		- increment buffer_offset by (operation_word - misalignment)
	--		- increment operation_address by operation_word
	--		if the next amount remaining is zero:
	--			- set ready high
	--			- set op_buffer_state to idle
	--		if the next amount remaining is less than the word size
	--			- set op_buffer_state to not aligned write last (read)
	--		otherwise
	--			- set dcache_data_in or device_data_in to the next set of operation_buffer bytes
	--			- set op_buffer_state to aligned write
	--
	-- NOT ALIGNED WRITE LAST (READ):
	--	when the operation is ready:
	--		- latch misaligned operation_buffer bytes into dcache_data_in or device_data_in, lower part
	--		- latch read bytes into dcache_data_in or device_data_in, upper part
	--		- set op_buffer_state to not aligned write last (write)
	--
	-- NOT ALIGNED WRITE LAST (WRITE):
	--	when the operation is ready:
	--		- set ready high
	--		- set op_buffer_state to idle
	--
	
	comb_proc: process (all) is
	begin
		-- async ready reset
		if known_address /= address then
			ready <= '0';
		end if;
	
		-- combinational logic related to the op buffers
		decode_address <= 	dcop_address when dcop_state /= IDLE else
							memop_address when (memop_read = '1' or memop_write = '1') else
							icache_read_address;
		
		decode_size <=	4 when dcop_state /= IDLE else
						memop_size when (memop_read = '1' or memop_write = '1') else
						8;
		
		icache_data	<= operation_buffer(7 downto 0);
		
		operation_ready	<= 	dcache_ready_out when operation_id = DCACHE else
							device_ready;
		
		operation_data_in(1 downto 0) <=	dcache_data_out(1 downto 0) when operation_id = DCACHE else
											device_data_out;
		operation_data_in(3 downto 2) <=	dcache_data_out(3 downto 2);
		
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
				
			when NA_READ_FIRST =>
				device_read		<= '1';
				device_write	<= '0';
			
			when NA_READ_LAST =>
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
	
	op_buffer_state_proc: process (device_exec_clk) is
		variable device_misalignment:		integer range 0 to 7 := 0;
		variable cache_misalignment:		integer range 0 to 3 := 0;
		variable truncated_word:			integer range 0 to 7 := 0;
		variable next_remaining:			integer range 0 to 20 := 0;
		
		variable decode_device_address_aligned:	nst_dword_t;
	begin
		-- Check for alignment, align device address
		case decode_word is
			when 2 =>
				device_misalignment 						:= 1 when decode_device_address(0) = '1' else 0;
				device_misalignment_last					:= 1 when remaining_op_size = 1 else 0;
				decode_device_address_aligned(31 downto 3)	:= decode_device_address(31 downto 1);
				decode_device_address_aligned(0)			:= "0";
				
			when 4 =>
				device_misalignment 						:= to_integer(unsigned(decode_device_address(1 downto 0)));
				decode_device_address_aligned(31 downto 2)	:= decode_device_address(31 downto 2);
				decode_device_address_aligned(1 downto 0)	:= "00";
					
			when 8 =>
				device_misalignment		 					:= to_integer(unsigned(decode_device_address(2 downto 0)));
				decode_device_address_aligned(31 downto 3)	:= decode_device_address(31 downto 3);
				decode_device_address_aligned(2 downto 0)	:= "000";
				
			when others =>
				device_misalignment 			:= 0;
				decode_device_address_aligned	:= decode_device_address;
			
		end case;
		
		-- Aligned to dcache block size?
		cache_misalignment	:= to_integer(unsigned(memop_address(1 downto 0)));
	
		if rising_edge(device_exec_clk) then
			case op_buffer_state is
				-- IDLE: Wait for an operation
				when IDLE =>
					if memop_read = '1' then
						-- Read.
						remaining_op_size	<= memop_size;
						buffer_offset		<= 0;
						
						if decode_cachable then
							operation_id					<= DCACHE;
							operation_address(31 downto 2)	<= memop_address(31 downto 2); -- global address (aligned)
							operation_address(1 downto 0)	<= "00";
							operation_word					<= 4;
							
							op_buffer_state	<=	A_READ when cache_misalignment = 0 else
												NA_READ_FIRST;
						else
							operation_id		<= decode_device_id;
							operation_address	<= decode_device_address_aligned; -- local address
							operation_word		<= decode_word;
							
							op_buffer_state	<=	A_READ when device_misalignment = 0 else
												NA_READ_FIRST;
						end if;
					elsif memop_write = '1' then
						-- Write.
						remaining_op_size	<= memop_size;
						buffer_offset		<= 0;
						opeartion_buffer	<= memop_data_in;
						
						if decode_cachable then
							operation_id		<= DCACHE;
							operation_address(31 downto 2)	<= memop_address(31 downto 2); -- global address (aligned)
							operation_address(1 downto 0)	<= "00";
							operation_word		<= 4;
							
							if cache_misalignment = 0 then
								dcache_data_in	<= memop_data_in(3 downto 0);
								op_buffer_state	<= 	A_WRITE when memop_size >= 4 else
													NA_WRITE_LAST_READ;
							else
								op_buffer_state	<= NA_WRITE_FIRST_READ;
							end if;
						else
							operation_id		<= decode_device_id;
							operation_address	<= decode_device_address_aligned; -- local address
							operation_word		<= decode_word;
							operation_buffer	<= memop_data_in;
							
							if device_misalignment = 0 then
								device_data_in	<= memop_data_in(1 downto 0);
								op_buffer_state	<= 	A_WRITE when memop_size >= decode_word else
													NA_WRITE_LAST_READ;
							else
								op_buffer_state	<= NA_WRITE_FIRST_READ;
							end if;
							
							op_buffer_state	<=	A_WRITE when device_aligned else
												NA_WRITE_FIRST_READ;
						end if;
					elsif icache_read = '1' then
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
					if operation_ready = '1' then
						next_remaining := remaining_op_size - operation_word;
						
						operation_buffer(buffer_offset + operation_word - 1 downto buffer_offset) <= opeartion_data_in(operation_word - 1 downto 0);
						
						buffer_offset		<= buffer_offset + operation_word;
						operation_address	<= std_logic_vector(unsigned(operation_address) + operation_word);
						remaining_op_size	<= next_remaining;
						
						if next_remaining = 0 then
							-- done
							ready			<= '1';
							op_buffer_state	<= IDLE;
						elsif next_remaining < operation_word then
							-- not done, last word isn't aligned
							op_buffer_state	<= NA_READ_LAST;
						else
							-- not done, word aligned
							op_buffer_state	<= A_READ;
						end if;
					else
						-- not ready, wait
						op_buffer_state <= A_READ;
					end if;
					
				-- A_WRITE: Aligned write, no special action
				when A_WRITE =>
					if operation_ready = '1' then
						next_remaining := remaining_op_size - operation_word;
						
						buffer_offset 		<= buffer_offset + operation_word;
						operation_address	<= std_logic_vector(unsigned(operation_address) + operation_word);
						remaining_op_size	<= next_remaining;
						
						if next_remaining = 0 then
							-- no input
							ready			<= '1';
							op_buffer_state	<= IDLE;
						elsif next_remaining < operation_word then
							-- input will be set in this step
							op_buffer_state	<= NA_WRITE_LAST_READ;
						else
							-- set input, we know it exists
							if operation_id = DCACHE then
								dcache_data_in	<= operation_buffer(buffer_offset + 8 - 1 downto buffer_offset + 4);
							else
								device_data_in	<= operation_buffer(buffer_offset + operation_word + operation_word - 1 downto buffer_offset + operation_word);
							end if;
						
							op_buffer_state	<= A_WRITE;
						end if;
					else
						-- not ready, wait
						op_buffer_state <= A_WRITE;
					end if;
				
				-- NA_READ_FIRST: Non-aligned read, first word, lower byte(s) discarded
				when NA_READ_FIRST =>
					if operation_ready = '1' then
						if operation_id = DCACHE then
							truncated_word	:= operation_word - cache_misalignment;
							next_remaining	:= remaining_op_size - truncated_word;
							
							buffer_offset		<= buffer_offset + truncated_word;
							operation_address	<= std_logic_vector(unsigned(operation_address) + truncated_word);
							remaining_op_size	<= next_remaining;
							
							operation_buffer(buffer_offset + truncated_word - 1 downto buffer_offset) <= opeartion_data_in(operation_word - 1 downto cache_misalignment);
						else
							truncated_word	:= operation_word - device_misalignment
							next_remaining 	:= remaining_op_size - truncated_word;
							
							buffer_offset		<= buffer_offset + truncated_word;
							operation_address	<= std_logic_vector(unsigned(operation_address) + operation_word);
							remaining_op_size	<= next_remaining;
							
							operation_buffer(buffer_offset + truncated_word - 1 downto buffer_offset) <= opeartion_data_in(operation_word - 1 downto device_misalignment);
						end if;
						
						if next_remaining = 0 then
							ready			<= '1';
							op_buffer_state	<= IDLE;
						elsif next_remaining < operation_word then
							op_buffer_state	<= NA_READ_LAST;
						else
							op_buffer_state	<= A_READ;
						end if;
					else
						-- not ready, wait
						op_buffer_state <= NA_READ;
					end if;
				
				-- NA_READ_LAST: Non-aligned read, last word, upper byte(s) discarded
				when NA_READ_LAST =>
					if operation_ready = '1' then
						operation_buffer(buffer_offset + remaining_op_size - 1 downto buffer_offset) <= operation_data_in(remaining_op_size - 1 downto 0);
						
						ready			<= '1';
						op_buffer_state	<= IDLE;
					else
						-- not ready, wait
						op_buffer_state <= NA_READ;
					end if;
				
				-- NA_WRITE_FIRST_READ: Non-aligned write, first word, read for lower byte(s)
				when NA_WRITE_FIRST_READ =>
					if operation_ready = '1' then
						if operation_id = DCACHE then
							truncated_word	:= operation_word - cache_misalignment;
							
							dcache_data_in(cache_misalignment - 1 downto 0)				<= operation_data_in(cache_misalignment - 1 downto 0); -- lower gets misalignment
							dcache_data_in(operation_word downto cache_misalignment)	<= operation_buffer(buffer_offset + truncated_word - 1 downto buffer_offset);
						else
							truncated_word	:= operation_word - device_misalignment;
							
							device_data_in(device_misalignment - 1 downto 0)			<= operation_data_in(device_misalignment - 1 downto 0);
							device_data_in(operation_word downto device_misalignment)	<= operation_buffer(buffer_offset + truncated_word - 1 downto buffer_offset);
						end if;
						
						op_buffer_state	<= NA_WRITE_FIRST_WRITE;
					else
						-- not ready, wait
						op_buffer_state <= NA_WRITE_FIRST_READ;
					end if;
				
				-- NA_WRITE_FIRST_WRITE: Non-aligned write, first word, write using mixed bytes
				when NA_WRITE_FIRST_WRITE =>
					if operation_ready = '1' then
						if operation_id = DCACHE then
							truncated_word	:= operation_word - cache_misalignment;
							next_remaining	:= remaining_op_size - truncated_word;
							
							buffer_offset		<= buffer_offset + truncated_word;
							remaining_op_size	<= next_remaining; 
						else
							truncated_word	:= operation_word - device_misalignment;
							next_remaining	:= remaining_op_size - truncated_word;
							
							buffer_offset		<= buffer_offset + truncated_word;
							remaining_op_size	<= next_remaining; 
						end if;
						
						if next_remaining = 0 then
							ready			<= '1';
							op_buffer_state	<= IDLE;
						elsif next_remaining <= operation_word then
							op_buffer_state	<= NA_WRITE_LAST_READ;
						else
							if operation_id = DCACHE then
								dcache_data_in	<= operation_buffer(buffer_offset + 8 - 1 downto buffer_offset + 4);
							else
								device_data_in	<= operation_buffer(buffer_offset + operation_word + operation_word - 1 downto buffer_offset + operation_word);
							end if;
						
							op_buffer_state	<= A_WRITE;
						end if;
					else
						-- not ready, wait
						op_buffer_state <= NA_WRITE_FIRST_WRITE;
					end if;
				
				-- NA_WRITE_LAST_READ: Non-aligned write, last word, read for upper byte(s)
				when NA_WRITE_LAST_READ =>
					if operation_ready = '1' then
						if operation_id = DCACHE then
							dcache_data_in(remaining_op_size - 1 downto 0)				<= operation_buffer(buffer_offset + remaining_op_size - 1 downto buffer_offset);		
							dcache_data_in(operation_word - 1 downto remaining_op_size)	<= operation_data_in(operation_word - 1 downto remaining_op_size);
						else
							device_data_in(remaining_op_size - 1 downto 0)				<= operation_buffer(buffer_offset + remaining_op_size - 1 downto buffer_offset);		
							device_data_in(operation_word - 1 downto remaining_op_size)	<= operation_data_in(operation_word - 1 downto remaining_op_size);
						end if;
						
						op_buffer_state	<= NA_WRITE_LAST_WRITE;
					else
						-- not ready, wait
						op_buffer_state <= NA_WRITE_LAST_READ;
					end if;
				
				-- NA_WRITE_LAST_WRITE: Non-aligned write, last word, write using mixed bytes
				when NA_WRITE_LAST_WRITE =>
					if operation_ready = '1' then
						ready			<= '1';
						op_buffer_state	<= IDLE;
					else
						-- not ready, wait
						op_buffer_state <= NA_WRITE_LAST_WRITE;
					end if;
			end case;
		end if;
	end process;
	
	-- DCache Operation Buffer
	-- Like the above operation buffer, but simpler as it doesn't have to account for misalignment
	-- While idle
	--	On dcache read, reset operation size to 4 & offset to 0, latch address, state -> A_READ
	--	On dcache write, reset operation size to 4 & offset to 0, latch address, latch data, state -> A_WRITE
	-- While reading
	--	Send read & address to decoded device
	--	When device ready
	--		Latch (word size) bytes
	--		Increment offset by (word size)
	-- While writing
	--	Send data
	--	Write word
	--	Increment offset by (word size)
	
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