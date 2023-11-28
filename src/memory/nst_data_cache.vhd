--
-- Mechafinch
-- NST Handheld Project
-- 
-- nst_data_cache
-- Data cache.
-- 2-way set associative, LRU, read and write
-- 512 sets with 4 byte blocks
-- uses 11 BRAM blocks
--

library ieee;
use ieee.std_logic_1164.all;
use work.nst_types.all;

library efxphysicallib;
use efxphysicallib.efxcomponents.all;

entity nst_data_cache is
	port (
		-- requested operation from memory manager
		request_address		in nst_dword_t;
		request_data_in		in dcache_block_data_t;
		request_data_out	out dcache_block_data_t;
		
		request_read	in std_logic;
		request_write	in std_logic;
		request_ready	out std_logic;
		
		-- memory operation requested by cache
		mem_address:	out nst_dword_t;
		mem_data_in:	in dcache_block_data_t;
		mem_data_out:	out dcache_block_data_t;
		
		mem_read:	out std_logic;
		mem_write:	out std_logic;
		mem_ready:	in std_logic;
		
		clear:	in std_logic;
		
		-- clocking
		exec_clk:	in std_logic;
	);
end nst_data_cache;

architecture a1 of nst_data_cache is
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
			
			WDATA:	in std_logic_vector(9 downto 0);
			WADDR:	in std_logic_vector(8 downto 0);
			RADDR:	in std_logic_vector(8 downto 0);
			RDATA:	out std_logic_vector(9 downto 0)
		);
	end component EFX_RAM_5K;

	type dcache_block_t is record
		data:	dcache_block_data_t; -- array of 4 bytes
		tag:	std_logic_vector(20 downto 0);
		clean:	std_logic;
	end record;
	
	type dcache_set_t is record
		b0:		dcache_block_t;
		b1:		dcache_block_t;
		lru:	std_logic;	-- 0 = b0 LRU, 1 = b1 LRU
		valid:	std_logic;	-- 0 = invalid, 1 = valid
	end record;
	
	type bram_data_t is array (10 downto 0) of std_logic_vector(9 downto 0);
	
	signal current_input:	dcache_set_t;
	signal current_output:	dcache_set_t;
	
	signal bram_write_enable:	std_logic;
	signal bram_address:		std_logic_vector(8 downto 0);
	
	signal bram_inputs:		bram_data_t;
	signal bram_outputs:	bram_data_t;
begin
	-- TODO
	
	-- Operation
	--	When a read is requested
	--		If a write is ongoing, the ready signal is clear.
	--		If no write is ongoing
	--			The requested address is latched when the set is read.
	--			If the set hits, the block can be output and the ready signal set.
	--			If the set misses, the ready signal is clear and a block read begins.
	--	When reading a block
	--		If the 
	--		Memory is read from the aligned address
	--		Once memory is ready, the read data can be written to bram
	--
	
	-- it may be beneficial to infer the BRAMs instead, in which case their functionality should be
	-- replicated here instead
	
	-- rename input/output between cache set record and raw bram signals
	bram_mapping_proc: process (all) begin
		bram_address(8 downto 0)	<= address(10 downto 2);
		
		-- BRAM input mapping
		-- block 0: bits 9:0 of b0.data
		bram_inputs(0)(7 downto 0)	<= current_input.b0.data(0);
		bram_inputs(0)(9 downto 8)	<= current_input.b0.data(1)(1 downto 0);
		
		-- block 1: bits 19:10 of b0.data
		bram_inputs(1)(5 downto 0)	<= current_input.b0.data(1)(7 downto 2);
		bram_inputs(1)(9 downto 6)	<= current_input.b0.data(2)(3 downto 0);
		
		-- block 2: bits 29:20 of b0.data
		bram_inputs(2)(3 downto 0)	<= current_input.b0.data(2)(7 downto 4);
		bram_inputs(2)(9 downto 4)	<= current_input.b0.data(3)(5 downto 0);
		
		-- block 3: bits 31:30 of b0.data, bits 7:0 of b0.tag
		bram_inputs(3)(1 downto 0)	<= current_input.b0.data(3)(7 downto 6);
		bram_inputs(3)(9 downto 2)	<= current_input.b0.tag(7 downto 0);
		
		-- block 4: bits 17:8 of b0.tag
		bram_inputs(4)(9 downto 0)	<= current_input.b0.tag(17 downto 8);
		
		-- block 5: bits 20:18 of b0.tag, b0.clean, set lru, set valid, b1.clean, bits 2:0 of b1.data
		bram_inputs(5)(2 downto 0)	<= current_input.b0.tag(20 downto 18);
		bram_inputs(5)(3)			<= current_input.b0.clean;
		bram_inputs(5)(4)			<= current_input.lru;
		bram_inputs(5)(5)			<= current_input.valid;
		bram_inputs(5)(6)			<= current_input.b1.clean;
		bram_inputs(5)(9 downto 7)	<= current_input.b1.data(0)(2 downto 0);
		
		-- block 6: bits 12:3 of b1.data
		bram_inputs(6)(4 downto 0)	<= current_input.b1.data(0)(7 downto 3);
		bram_inputs(6)(9 downto 5)	<= current_input.b1.data(1)(4 downto 0);
		
		-- block 7: bits 22:13 of b1.data
		bram_inputs(7)(2 downto 0)	<= current_input.b1.data(1)(7 downto 5);
		bram_inputs(7)(9 downto 3)	<= current_input.b1.data(2)(6 downto 0);
		
		-- block 8: bits 31:23 of b1.data, bit 0 of b1.tag
		bram_inputs(8)(0)			<= current_input.b1.data(2)(7);
		bram_inputs(8)(8 downto 1)	<= current_input.b1.data(3)(7 downto 0);
		bram_inputs(8)(9)			<= current_input.b1.tag(0);
		
		-- block 9: bits 10:1 of b1.tag
		bram_inputs(9)(9 downto 0)	<= current_input.b1.tag(10 downto 1);
		
		-- block 10: bits 20:11 of b1.tag
		bram_inputs(10)(9 downto 0)	<= current_input.b1.tag(20 downto 11);
		
		-- BRAM output mapping
		current_output.b0.data(0)				<= bram_outputs(0)(7 downto 0);
		current_output.b0.data(1)(7 downto 2)	<= bram_outputs(1)(5 downto 0);
		current_output.b0.data(1)(1 downto 0)	<= bram_outputs(0)(9 downto 8);
		current_output.b0.data(2)(7 downto 4)	<= bram_outputs(2)(3 downto 0);
		current_output.b0.data(2)(3 downto 0)	<= bram_outputs(1)(9 downto 6);
		current_output.b0.data(3)(7 downto 6)	<= bram_outputs(3)(1 downto 0);
		current_output.b0.data(3)(5 downto 0)	<= bram_outputs(2)(9 downto 4);
		
		current_output.b0.tag(20 downto 18)	<= bram_outputs(5)(2 downto 0);
		current_output.b0.tag(17 downto 8)	<= bram_outputs(4)(9 downto 0);
		current_output.b0.tag(7 downto 0)	<= bram_outputs(3)(9 downto 2);
		current_output.b0.clean				<= bram_outputs(5)(3);
		
		current_output.lru		<= bram_outputs(5)(4);
		current_output.valid	<= bram_outputs(5)(5);
		
		current_output.b1.data(0)(7 downto 3)	<= bram_outputs(6)(4 downto 0);
		current_output.b1.data(0)(2 downto 0)	<= bram_outputs(5)(9 downto 7);
		current_output.b1.data(1)(7 downto 5)	<= bram_outputs(7)(2 downto 0);
		current_output.b1.data(1)(4 downto 0)	<= bram_outputs(6)(9 downto 5);
		current_output.b1.data(2)(7)			<= bram_outputs(8)(0);
		current_output.b1.data(2)(6 downto 0)	<= bram_outputs(7)(9 downto 3);
		current_output.b1.data(3)				<= bram_outputs(8)(8 downto 1);
		
		current_output.b1.tag(0)			<= bram_outputs(8)(9);
		current_output.b1.tag(10 downto 1)	<= bram_outputs(9);
		current_output.b1.tag(20 downto 11)	<= bram_outputs(10);
		current_output.b1.clean				<= bram_outputs(5)(6);
	end process;
	
	-- BRAM instances
	
	-- block 0: bits 9:0 of b0.data
	bram_0: EFX_RAM_5K
		generic map (
			READ_WIDTH	=> 10,
			WRITE_WIDTH	=> 10,
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
			WADDR	=> bram_address,
			WDATA	=> bram_inputs(0),
			RADDR	=> bram_address,
			RDATA	=> bram_outputs(0)
		);
	
	-- block 1: bits 19:10 of b0.data
	bram_1: EFX_RAM_5K
		generic map (
			READ_WIDTH	=> 10,
			WRITE_WIDTH	=> 10,
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
			WADDR	=> bram_address,
			WDATA	=> bram_inputs(1),
			RADDR	=> bram_address,
			RDATA	=> bram_outputs(1)
		);
	
	-- block 2: bits 29:20 of b0.data
	bram_2: EFX_RAM_5K
		generic map (
			READ_WIDTH	=> 10,
			WRITE_WIDTH	=> 10,
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
			WADDR	=> bram_address,
			WDATA	=> bram_inputs(2),
			RADDR	=> bram_address,
			RDATA	=> bram_outputs(2)
		);
	
	-- block 3: bits 31:30 of b0.data, bits 7:0 of b0.tag
	bram_3: EFX_RAM_5K
		generic map (
			READ_WIDTH	=> 10,
			WRITE_WIDTH	=> 10,
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
			WADDR	=> bram_address,
			WDATA	=> bram_inputs(3),
			RADDR	=> bram_address,
			RDATA	=> bram_outputs(3)
		);
	
	-- block 4: bits 17:8 of b0.tag
	bram_4: EFX_RAM_5K
		generic map (
			READ_WIDTH	=> 10,
			WRITE_WIDTH	=> 10,
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
			WADDR	=> bram_address,
			WDATA	=> bram_inputs(4),
			RADDR	=> bram_address,
			RDATA	=> bram_outputs(4)
		);
	
	-- block 5: bits 20:18 of b0.tag, b0.clean, set lru, set valid, b1.clean, bits 2:0 of b1.data
	bram_5: EFX_RAM_5K
		generic map (
			READ_WIDTH	=> 10,
			WRITE_WIDTH	=> 10,
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
			WADDR	=> bram_address,
			WDATA	=> bram_inputs(5),
			RADDR	=> bram_address,
			RDATA	=> bram_outputs(5)
		);
	
	-- block 6: bits 12:3 of b1.data
	bram_6: EFX_RAM_5K
		generic map (
			READ_WIDTH	=> 10,
			WRITE_WIDTH	=> 10,
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
			WADDR	=> bram_address,
			WDATA	=> bram_inputs(6),
			RADDR	=> bram_address,
			RDATA	=> bram_outputs(6)
		);
	
	-- block 7: bits 22:13 of b1.data
	bram_7: EFX_RAM_5K
		generic map (
			READ_WIDTH	=> 10,
			WRITE_WIDTH	=> 10,
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
			WADDR	=> bram_address,
			WDATA	=> bram_inputs(7),
			RADDR	=> bram_address,
			RDATA	=> bram_outputs(7)
		);
	
	-- block 8: bits 31:23 of b1.data, bit 0 of b1.tag
	bram_8: EFX_RAM_5K
		generic map (
			READ_WIDTH	=> 10,
			WRITE_WIDTH	=> 10,
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
			WADDR	=> bram_address,
			WDATA	=> bram_inputs(8),
			RADDR	=> bram_address,
			RDATA	=> bram_outputs(8)
		);
	
	-- block 9: bits 10:1 of b1.tag
	bram_9: EFX_RAM_5K
		generic map (
			READ_WIDTH	=> 10,
			WRITE_WIDTH	=> 10,
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
			WADDR	=> bram_address,
			WDATA	=> bram_inputs(9),
			RADDR	=> bram_address,
			RDATA	=> bram_outputs(9)
		);
	
	-- block 10: bits 20:11 of b1.tag
	bram_10: EFX_RAM_5K
		generic map (
			READ_WIDTH	=> 10,
			WRITE_WIDTH	=> 10,
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
			WADDR	=> bram_address,
			WDATA	=> bram_inputs(10),
			RADDR	=> bram_address,
			RDATA	=> bram_outputs(10)
		);
	
end a1;