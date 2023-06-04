--
-- Mechafinch
-- NST Handheld Project
--
-- icache_test
-- Tests the instruction cache
--

library ieee;
use ieee.std_logic_1164.all;
use work.nst_types.all;

entity icache_test is
end icache_test;

architecture tb of icache_test is
	signal address:		nst_dword_t;
	signal data:		icache_block_data_t;
	signal data_ready:	std_logic;
	signal mem_address:	nst_dword_t;
	signal mem_data:	icache_block_data_t;
	signal mem_read:	std_logic;
	signal mem_ready:	std_logic;
	signal exec_clk:	std_logic := '0';
	
	constant period: time := 15625 ps;
begin

	exec_clk <= not exec_clk after period / 2;
	
	stim: process begin
		address		<= 32x"12345678";
		mem_data	<= (
			8x"00", 8x"01", 8x"02", 8x"03", 8x"04", 8x"05", 8x"06", 8x"07"
		);
		mem_ready	<= '0';
		wait for period;
		
		mem_ready <= '1';
		wait for period / 2;
		mem_ready <= '0';
		wait for period / 2;
		
		address		<= 32x"23455678";
		mem_data	<= (
			8x"02", 8x"03", 8x"04", 8x"05", 8x"05", 8x"06", 8x"07", 8x"08"
		);
		wait for period * 4;
		
		mem_ready <= '1';
		wait for period / 2;
		mem_ready <= '0';
		wait for period / 2;
		
		address		<= 32x"34565678";
		mem_data	<= (
			8x"03", 8x"04", 8x"05", 8x"06", 8x"05", 8x"06", 8x"07", 8x"08"
		);
		wait for period * 3;
		
		mem_ready <= '1';
		wait for period / 2;
		mem_ready <= '0';
		wait for period / 2;
		
		address		<= 32x"23455678";
		wait for period * 2;
		address		<= 32x"34565678";
		wait;
	end process;
	
	uut: entity work.nst_instruction_cache
		port map (
			address		=> address,
			data		=> data,
			data_ready	=> data_ready,
			
			mem_address	=> mem_address,
			mem_data	=> mem_data,
			mem_read	=> mem_read,
			mem_ready	=> mem_ready,
			
			exec_clk	=> exec_clk
		);
end tb;