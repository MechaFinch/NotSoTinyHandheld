--
-- Mechafinch
-- NST Handheld Project
-- 
-- nst_instruction_cache
-- Instruction cache.
-- 2-way set associative, LRU, read only
-- 256 sets with 8 byte blocks
-- Uses 9 BRAM blocks
--

library ieee;
use ieee.std_logic_1164.all;
use work.nst_types.all;

--library efxphysicallib;
--use efxphysicallib.efxcomponents.all;

entity nst_instruction_cache is
	port (
		-- cpu side
		address:	in nst_dword_t;				-- address the cpu is reading
		data:		out icache_block_data_t;	-- data block for the cpu
		data_ready:	out std_logic;
		
		-- memory side
		mem_address:	out nst_dword_t;		-- address the cache is reading
		mem_data:		in icache_block_data_t;	-- data block for the cache
		mem_read:		out std_logic;
		mem_ready:		in std_logic;
		
		-- clocking
		exec_clk:	in std_logic
	);
end nst_instruction_cache;

architecture a1 of nst_instruction_cache is
	component EFX_RAM_5K is
		generic (
			WCLK_POLARITY:	std_logic;
			WCLKE_POLARITY:	std_logic;
			WE_POLARITY:	std_logic;
			RCLK_POLARITY:	std_logic;
			RE_POLARITY:	std_logic;
			READ_WIDTH:		integer;
			WRITE_WIDTH:	integer;
			OUTPUT_REG:		std_logic;
			WRITE_MODE:		string;
			INIT_0:			std_logic_vector(255 downto 0);
			INIT_1:			std_logic_vector(255 downto 0);
			INIT_2:			std_logic_vector(255 downto 0);
			INIT_3:			std_logic_vector(255 downto 0);
			INIT_4:			std_logic_vector(255 downto 0);
			INIT_5:			std_logic_vector(255 downto 0);
			INIT_6:			std_logic_vector(255 downto 0);
			INIT_7:			std_logic_vector(255 downto 0);
			INIT_8:			std_logic_vector(255 downto 0);
			INIT_9:			std_logic_vector(255 downto 0);
			INIT_A:			std_logic_vector(255 downto 0);
			INIT_B:			std_logic_vector(255 downto 0);
			INIT_C:			std_logic_vector(255 downto 0);
			INIT_D:			std_logic_vector(255 downto 0);
			INIT_E:			std_logic_vector(255 downto 0);
			INIT_F:			std_logic_vector(255 downto 0);
			INIT_10:		std_logic_vector(255 downto 0);
			INIT_11:		std_logic_vector(255 downto 0);
			INIT_12:		std_logic_vector(255 downto 0);
			INIT_13:		std_logic_vector(255 downto 0)
		);
		
		port (
			WCLK, WE, WCLKE:	in std_logic;
			RCLK, RE:			in std_logic;
			
			WDATA:	in std_logic_vector(19 downto 0);
			WADDR:	in std_logic_vector(7 downto 0);
			RADDR:	in std_logic_vector(7 downto 0);
			RDATA:	out std_logic_vector(19 downto 0)
		);
	end component EFX_RAM_5K;

	-- a block; data with tag and dirty bit
	type icache_block_t is record
		data: 	icache_block_data_t; -- array of 8 bytes
		tag:	std_logic_vector(20 downto 0);
		clean:	std_logic; -- 0 = dirty, for ease of initialization
	end record;
	
	-- a set; 2 blocks with LRU and valid bits
	-- There is only one valid bit per set in order to save a BRAM (in doing so not wasting 90% of one)
	-- When data is read into an invalid set, it is written to both blocks (they recieve the same tag)
	-- to prevent false hits. When both blocks in a set match an address, b0 will be used. 
	type icache_set_t is record
		b0:		icache_block_t;
		b1:		icache_block_t;
		lru:	std_logic;	-- 0 = b0 LRU, 1 = b1 LRU
		valid:	std_logic;	-- 0 = invalid, 1 = valid
	end record;
	
	-- bram interfacing stuff
	type bram_data_t is array (8 downto 0) of std_logic_vector(19 downto 0);
	
	signal current_input:	icache_set_t;
	signal current_output:	icache_set_t;
	
	signal bram_write_enable:	std_logic;
	signal bram_read_address:	std_logic_vector(7 downto 0);
	signal bram_write_address:	std_logic_vector(7 downto 0) := 8x"FF";
	
	signal bram_inputs:		bram_data_t;
	signal bram_outputs:	bram_data_t;
	
	signal working_tag:	std_logic_vector(20 downto 0) := 21x"1FFFFF";
	signal working_set:	std_logic_vector(7 downto 0) := 8x"FF";
begin
	-- BRAM independent operation
	operating_proc: process (all) is
		variable input_tag:			std_logic_vector(20 downto 0);
		variable input_set:			std_logic_vector(7 downto 0);
		variable b0_matches_w:		std_logic;
		variable b1_matches_w:		std_logic;
		--variable b0_matches_i:		std_logic;
		--variable b1_matches_i:		std_logic;
		variable tag_matches:		std_logic;
		variable set_matches:		std_logic;
		variable address_matches:	std_logic;
	begin
		-- data is read synchronously, but we can use it asynchronously
		-- we can use this to automatically mark ready upon miss read
		input_tag	:= address(31 downto 11);
		input_set	:= address(10 downto 3);
		
		-- If the tag matches, the block is clean, and the set is valid, it's good to go
		set_matches		:= '1' when input_set = working_set else '0';
		tag_matches		:= '1' when input_tag = working_tag else '0';
		address_matches	:= tag_matches and set_matches;
		
		b0_matches_w	:= '1' when current_output.b0.tag = working_tag else '0';
		b1_matches_w	:= '1' when current_output.b1.tag = working_tag else '0';
		--b0_matches_i	:= '1' when current_output.b0.tag = input_tag else '0';
		--b1_matches_i	:= '1' when current_output.b1.tag = input_tag else '0';
		
		mem_address			<= address;
		current_input.valid	<= '1';
		
		-- brams are written when blocks match (to update LRU) or when data is ready when reading
		bram_write_enable	<= (mem_read and mem_ready) or b0_matches_w or b1_matches_w;
		bram_read_address	<= input_set;
		bram_write_address	<= working_set; --address(10 downto 3);
		
		if rising_edge(exec_clk) then
			working_set	<= input_set;
			working_tag	<= input_tag;
		end if;
		
		if b0_matches_w or b1_matches_w then
			mem_read			<= '0';
			data_ready			<= '1';
			current_input.b0	<= current_output.b0;
			current_input.b1	<= current_output.b1;
			current_input.valid	<= current_output.valid;
			
			if b0_matches_w then
				data				<= current_output.b0.data;
				current_input.lru	<= '1';
			else -- b1_matches_w
				data				<= current_output.b1.data;
				current_input.lru	<= '0';
			end if;
		else
			-- miss - read into appropriate block
			mem_read	<= '1';
			data_ready	<= '0';
			
			if current_output.lru = '0' then
				data <= current_output.b0.data;
			else
				data <= current_output.b1.data;
			end if;
			
			if address_matches then
				-- read in progress, writing new data
				if current_output.lru = '0' then
					-- read into b0
					current_input.b0.data	<= mem_data;
					current_input.b0.tag	<= working_tag; --input_tag;
					current_input.b0.clean	<= '1';
					current_input.b1		<= current_output.b1;
					current_input.lru		<= '1';
				else
					-- read into b1
					data	<= current_output.b1.data;
					
					current_input.b0		<= current_output.b0;
					current_input.b1.data	<= mem_data;
					current_input.b1.tag	<= working_tag; --input_tag;
					current_input.b1.clean	<= '1';
					current_input.lru		<= '0';
				end if;
			else
				-- read is being started, lingering data needs to be written and working set needs to be read
				current_input.b0	<= current_output.b0;
				current_input.b1	<= current_output.b1;
				current_input.lru	<= current_output.lru;
			end if;
		end if;
	end process;
	
	-- it may be beneficial to infer the BRAMs instead, in which case their functionality should be
	-- replicated here instead

	-- handles renaming input/output as a cache set record and as bram signals
	-- using process (all) fails in simulation, because fuck you
	bram_mapping_proc: process (current_input, bram_outputs) begin
		-- BRAM input mapping
		-- block 0: bits 19:0 of b0; bits 19:0 of b0's data
		bram_inputs(0)(7 downto 0)		<= current_input.b0.data(0);
		bram_inputs(0)(15 downto 8)		<= current_input.b0.data(1);
		bram_inputs(0)(19 downto 16)	<= current_input.b0.data(2)(3 downto 0);
		
		-- block 1: bits 39:20 of b0; bits 39:20 of b0's data
		bram_inputs(1)(3 downto 0)		<= current_input.b0.data(2)(7 downto 4);
		bram_inputs(1)(11 downto 4)		<= current_input.b0.data(3);
		bram_inputs(1)(19 downto 12)	<= current_input.b0.data(4);
		
		-- block 2: bits 59:40 of b0; bits 59:40 of b0's data
		bram_inputs(2)(7 downto 0)		<= current_input.b0.data(5);
		bram_inputs(2)(15 downto 8)		<= current_input.b0.data(6);
		bram_inputs(2)(19 downto 16)	<= current_input.b0.data(7)(3 downto 0);
		
		-- block 3: bits 79:60 of b0; bits 63:60 of b0's data, 15:0 of b0's tag
		bram_inputs(3)(3 downto 0)	<= current_input.b0.data(7)(7 downto 4);
		bram_inputs(3)(19 downto 4)	<= current_input.b0.tag(15 downto 0);
		
		-- block 4: bits 85:80 of b0, 7:0 of b1; bits 20:16 of b0's tag, b0's clean bit, bits 7:0 of b1's data
		bram_inputs(4)(4 downto 0)		<= current_input.b0.tag(20 downto 16);
		bram_inputs(4)(5)				<= current_input.b0.clean;
		bram_inputs(4)(11 downto 6)		<= "000000"; -- 6 unused bits, aligns very conveniently
		bram_inputs(4)(19 downto 12)	<= current_input.b1.data(0);
		
		-- block 5: bits 27:8 of b1; bits 27:8 of b1's data
		bram_inputs(5)(7 downto 0)		<= current_input.b1.data(1);
		bram_inputs(5)(15 downto 8)		<= current_input.b1.data(2);
		bram_inputs(5)(19 downto 16)	<= current_input.b1.data(3)(3 downto 0);
		
		-- block 6: bits 47:28 of b1; bits 47:28 of b1's data
		bram_inputs(6)(3 downto 0)		<= current_input.b1.data(3)(7 downto 4);
		bram_inputs(6)(11 downto 4)		<= current_input.b1.data(4);
		bram_inputs(6)(19 downto 12)	<= current_input.b1.data(5);
		
		-- block 7: bits 67:48 of b1; bits 63:48 of b1's data, 3:0 of b1's tag
		bram_inputs(7)(7 downto 0)		<= current_input.b1.data(6);
		bram_inputs(7)(15 downto 8)		<= current_input.b1.data(7);
		bram_inputs(7)(19 downto 16)	<= current_input.b1.tag(3 downto 0);
		
		-- block 8: bits 85:68 of b1, set status bits; bits 20:4 of b1's tag, b1's clean bit, set LRU bit, set valid bit
		bram_inputs(8)(16 downto 0)	<= current_input.b1.tag(20 downto 4);
		bram_inputs(8)(17)			<= current_input.b1.clean;
		bram_inputs(8)(18)			<= current_input.lru;
		bram_inputs(8)(19)			<= current_input.valid;
		
		-- BRAM output mapping (see above)
		current_output.b0.data(0)				<= bram_outputs(0)(7 downto 0);
		current_output.b0.data(1)				<= bram_outputs(0)(15 downto 8);
		current_output.b0.data(2)(7 downto 4)	<= bram_outputs(1)(3 downto 0);
		current_output.b0.data(2)(3 downto 0)	<= bram_outputs(0)(19 downto 16);
		current_output.b0.data(3)				<= bram_outputs(1)(11 downto 4);
		current_output.b0.data(4)				<= bram_outputs(1)(19 downto 12);
		current_output.b0.data(5)				<= bram_outputs(2)(7 downto 0);
		current_output.b0.data(6)				<= bram_outputs(2)(15 downto 8);
		current_output.b0.data(7)(7 downto 4)	<= bram_outputs(3)(3 downto 0);
		current_output.b0.data(7)(3 downto 0)	<= bram_outputs(2)(19 downto 16);
		
		current_output.b0.tag(20 downto 16)	<= bram_outputs(4)(4 downto 0);
		current_output.b0.tag(15 downto 0)	<= bram_outputs(3)(19 downto 4);
		current_output.b0.clean				<= bram_outputs(4)(5);
		
		current_output.b1.data(0)				<= bram_outputs(4)(19 downto 12);
		current_output.b1.data(1)				<= bram_outputs(5)(7 downto 0);
		current_output.b1.data(2)				<= bram_outputs(5)(15 downto 8);
		current_output.b1.data(3)(7 downto 4)	<= bram_outputs(6)(3 downto 0);
		current_output.b1.data(3)(3 downto 0)	<= bram_outputs(5)(19 downto 16);
		current_output.b1.data(4)				<= bram_outputs(6)(11 downto 4);
		current_output.b1.data(5)				<= bram_outputs(6)(19 downto 12);
		current_output.b1.data(6)				<= bram_outputs(7)(7 downto 0);
		current_output.b1.data(7)				<= bram_outputs(7)(15 downto 8);
		
		current_output.b1.tag(20 downto 4)	<= bram_outputs(8)(16 downto 0);
		current_output.b1.tag(3 downto 0)	<= bram_outputs(7)(19 downto 16);
		current_output.b1.clean				<= bram_outputs(8)(17);
		
		current_output.lru		<= bram_outputs(8)(18);
		current_output.valid	<= bram_outputs(8)(19);
	end process;

	-- BRAM instances
	-- Each BRAM is addressed by the set number
	
	-- block 0: bits 19:0 of the set; bits 19:0 of b0; bits 19:0 of b0's data
	bram_0: EFX_RAM_5K
		generic map (
			READ_WIDTH	=> 20,
			WRITE_WIDTH	=> 20,
			OUTPUT_REG	=> '0',
			WRITE_MODE	=> "WRITE_FIRST", 
			
			WCLK_POLARITY	=> '1',	-- rising edge
			WCLKE_POLARITY	=> '1',
			WE_POLARITY		=> '1',
			
			RCLK_POLARITY	=> '1',	-- rising edge
			RE_POLARITY		=> '1',
		
			INIT_0	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_1	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_2	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_3	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_4	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_5	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_6	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_7	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_8	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_9	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_A	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_B	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_C	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_D	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_E	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_F	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_10	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_11	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_12	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_13	=> 256x"0000000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			WCLK	=> exec_clk,
			WE		=> bram_write_enable,
			WCLKE	=> '1',
			RCLK	=> exec_clk,
			RE		=> '1',
			WADDR	=> bram_write_address,
			WDATA	=> bram_inputs(0),
			RADDR	=> bram_read_address,
			RDATA	=> bram_outputs(0)
		);
	
	-- block 1: bits 39:20 of the set; bits 39:20 of b0; bits 39:20 of b0's data
	bram_1: EFX_RAM_5K
		generic map (
			READ_WIDTH	=> 20,
			WRITE_WIDTH	=> 20,
			OUTPUT_REG	=> '0',
			WRITE_MODE	=> "WRITE_FIRST", 
			
			WCLK_POLARITY	=> '1',	-- rising edge
			WCLKE_POLARITY	=> '1',
			WE_POLARITY		=> '1',
			
			RCLK_POLARITY	=> '1',	-- rising edge
			RE_POLARITY		=> '1',
		
			INIT_0	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_1	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_2	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_3	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_4	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_5	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_6	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_7	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_8	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_9	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_A	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_B	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_C	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_D	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_E	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_F	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_10	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_11	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_12	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_13	=> 256x"0000000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			WCLK	=> exec_clk,
			WE		=> bram_write_enable,
			WCLKE	=> '1',
			RCLK	=> exec_clk,
			RE		=> '1',
			WADDR	=> bram_write_address,
			WDATA	=> bram_inputs(1),
			RADDR	=> bram_read_address,
			RDATA	=> bram_outputs(1)
		);
		
	-- block 2: bits 59:40 of the set; bits 59:40 of b0; bits 59:40 of b0's data
	bram_2: EFX_RAM_5K
		generic map (
			READ_WIDTH	=> 20,
			WRITE_WIDTH	=> 20,
			OUTPUT_REG	=> '0',
			WRITE_MODE	=> "WRITE_FIRST", 
			
			WCLK_POLARITY	=> '1',	-- rising edge
			WCLKE_POLARITY	=> '1',
			WE_POLARITY		=> '1',
			
			RCLK_POLARITY	=> '1',	-- rising edge
			RE_POLARITY		=> '1',
		
			INIT_0	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_1	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_2	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_3	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_4	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_5	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_6	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_7	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_8	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_9	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_A	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_B	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_C	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_D	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_E	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_F	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_10	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_11	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_12	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_13	=> 256x"0000000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			WCLK	=> exec_clk,
			WE		=> bram_write_enable,
			WCLKE	=> '1',
			RCLK	=> exec_clk,
			RE		=> '1',
			WADDR	=> bram_write_address,
			WDATA	=> bram_inputs(2),
			RADDR	=> bram_read_address,
			RDATA	=> bram_outputs(2)
		);
		
	-- block 3: bits 79:60 of the set; bits 79:60 of b0; bits 63:60 of b0's data, 15:0 of b0's tag
	bram_3: EFX_RAM_5K
		generic map (
			READ_WIDTH	=> 20,
			WRITE_WIDTH	=> 20,
			OUTPUT_REG	=> '0',
			WRITE_MODE	=> "WRITE_FIRST", 
			
			WCLK_POLARITY	=> '1',	-- rising edge
			WCLKE_POLARITY	=> '1',
			WE_POLARITY		=> '1',
			
			RCLK_POLARITY	=> '1',	-- rising edge
			RE_POLARITY		=> '1',
		
			INIT_0	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_1	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_2	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_3	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_4	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_5	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_6	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_7	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_8	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_9	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_A	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_B	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_C	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_D	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_E	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_F	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_10	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_11	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_12	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_13	=> 256x"0000000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			WCLK	=> exec_clk,
			WE		=> bram_write_enable,
			WCLKE	=> '1',
			RCLK	=> exec_clk,
			RE		=> '1',
			WADDR	=> bram_write_address,
			WDATA	=> bram_inputs(3),
			RADDR	=> bram_read_address,
			RDATA	=> bram_outputs(3)
		);
		
	-- block 4: bits 99:80 of the set; bits 85:80 of b0, 13:0 of b1; bits 20:16 of b0's tag, b0's clean bit, bits 13:0 of b1's data
	bram_4: EFX_RAM_5K
		generic map (
			READ_WIDTH	=> 20,
			WRITE_WIDTH	=> 20,
			OUTPUT_REG	=> '0',
			WRITE_MODE	=> "WRITE_FIRST", 
			
			WCLK_POLARITY	=> '1',	-- rising edge
			WCLKE_POLARITY	=> '1',
			WE_POLARITY		=> '1',
			
			RCLK_POLARITY	=> '1',	-- rising edge
			RE_POLARITY		=> '1',
		
			INIT_0	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_1	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_2	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_3	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_4	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_5	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_6	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_7	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_8	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_9	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_A	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_B	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_C	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_D	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_E	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_F	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_10	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_11	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_12	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_13	=> 256x"0000000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			WCLK	=> exec_clk,
			WE		=> bram_write_enable,
			WCLKE	=> '1',
			RCLK	=> exec_clk,
			RE		=> '1',
			WADDR	=> bram_write_address,
			WDATA	=> bram_inputs(4),
			RADDR	=> bram_read_address,
			RDATA	=> bram_outputs(4)
		);
		
	-- block 5: bits 119:100 of the set; bits 33:14 of b1; bits 33:14 of b1's data
	bram_5: EFX_RAM_5K
		generic map (
			READ_WIDTH	=> 20,
			WRITE_WIDTH	=> 20,
			OUTPUT_REG	=> '0',
			WRITE_MODE	=> "WRITE_FIRST", 
			
			WCLK_POLARITY	=> '1',	-- rising edge
			WCLKE_POLARITY	=> '1',
			WE_POLARITY		=> '1',
			
			RCLK_POLARITY	=> '1',	-- rising edge
			RE_POLARITY		=> '1',
		
			INIT_0	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_1	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_2	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_3	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_4	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_5	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_6	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_7	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_8	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_9	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_A	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_B	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_C	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_D	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_E	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_F	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_10	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_11	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_12	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_13	=> 256x"0000000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			WCLK	=> exec_clk,
			WE		=> bram_write_enable,
			WCLKE	=> '1',
			RCLK	=> exec_clk,
			RE		=> '1',
			WADDR	=> bram_write_address,
			WDATA	=> bram_inputs(5),
			RADDR	=> bram_read_address,
			RDATA	=> bram_outputs(5)
		);
		
	-- block 6: bits 139:120 of the set; bits 53:34 of b1; bits 53:34 of b1's data
	bram_6: EFX_RAM_5K
		generic map (
			READ_WIDTH	=> 20,
			WRITE_WIDTH	=> 20,
			OUTPUT_REG	=> '0',
			WRITE_MODE	=> "WRITE_FIRST", 
			
			WCLK_POLARITY	=> '1',	-- rising edge
			WCLKE_POLARITY	=> '1',
			WE_POLARITY		=> '1',
			
			RCLK_POLARITY	=> '1',	-- rising edge
			RE_POLARITY		=> '1',
		
			INIT_0	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_1	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_2	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_3	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_4	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_5	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_6	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_7	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_8	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_9	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_A	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_B	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_C	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_D	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_E	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_F	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_10	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_11	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_12	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_13	=> 256x"0000000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			WCLK	=> exec_clk,
			WE		=> bram_write_enable,
			WCLKE	=> '1',
			RCLK	=> exec_clk,
			RE		=> '1',
			WADDR	=> bram_write_address,
			WDATA	=> bram_inputs(6),
			RADDR	=> bram_read_address,
			RDATA	=> bram_outputs(6)
		);
		
	-- block 7: bits 159:140 of the set; bits 73:54 of b1; bits 63:54 of b1's data, 9:0 of b1's tag
	bram_7: EFX_RAM_5K
		generic map (
			READ_WIDTH	=> 20,
			WRITE_WIDTH	=> 20,
			OUTPUT_REG	=> '0',
			WRITE_MODE	=> "WRITE_FIRST", 
			
			WCLK_POLARITY	=> '1',	-- rising edge
			WCLKE_POLARITY	=> '1',
			WE_POLARITY		=> '1',
			
			RCLK_POLARITY	=> '1',	-- rising edge
			RE_POLARITY		=> '1',
		
			INIT_0	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_1	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_2	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_3	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_4	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_5	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_6	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_7	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_8	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_9	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_A	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_B	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_C	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_D	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_E	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_F	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_10	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_11	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_12	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_13	=> 256x"0000000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			WCLK	=> exec_clk,
			WE		=> bram_write_enable,
			WCLKE	=> '1',
			RCLK	=> exec_clk,
			RE		=> '1',
			WADDR	=> bram_write_address,
			WDATA	=> bram_inputs(7),
			RADDR	=> bram_read_address,
			RDATA	=> bram_outputs(7)
		);
		
	-- block 8: bits 173:160 of the set; bits 85:74 of b1, set status bits; bits 20:10 of b1's tag, b1's clean bit, set LRU bit, set valid bit
	bram_8: EFX_RAM_5K
		generic map (
			READ_WIDTH	=> 20,
			WRITE_WIDTH	=> 20,
			OUTPUT_REG	=> '0',
			WRITE_MODE	=> "WRITE_FIRST", 
			
			WCLK_POLARITY	=> '1',	-- rising edge
			WCLKE_POLARITY	=> '1',
			WE_POLARITY		=> '1',
			
			RCLK_POLARITY	=> '1',	-- rising edge
			RE_POLARITY		=> '1',
		
			INIT_0	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_1	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_2	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_3	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_4	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_5	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_6	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_7	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_8	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_9	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_A	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_B	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_C	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_D	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_E	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_F	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_10	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_11	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_12	=> 256x"0000000000000000000000000000000000000000000000000000000000000000",
			INIT_13	=> 256x"0000000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			WCLK	=> exec_clk,
			WE		=> bram_write_enable,
			WCLKE	=> '1',
			RCLK	=> exec_clk,
			RE		=> '1',
			WADDR	=> bram_write_address,
			WDATA	=> bram_inputs(8),
			RADDR	=> bram_read_address,
			RDATA	=> bram_outputs(8)
		);
		
	
	
end a1;