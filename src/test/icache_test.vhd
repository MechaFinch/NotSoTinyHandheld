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
	signal address:		nst_dword_t := 32x"00000000";
	signal data:		icache_block_data_t;
	signal data_ready:	std_logic;
	signal mem_address:	nst_dword_t;
	signal mem_data:	icache_block_data_t := (others => (others => '0'));
	signal mem_read:	std_logic;
	signal mem_ready:	std_logic := '0';
	signal clear:		std_logic := '0';
	signal exec_clk:	std_logic := '0';
	
	constant period: time := 15625 ps;
	
	type ta is array (0 to 7) of nst_dword_t;
	
	constant tra: ta := (
		32x"23456789", 32x"23456678", 32x"12345678", 32x"98765432",
		32x"23456789", 32x"23456678", 32x"12345678", 32x"98765432"
	);
	
	signal dynamic_addr: nst_dword_t;
	signal running_dynamic: std_logic := '0';
	
	signal caddr: nst_dword_t := tra(0);
	signal naddr: nst_dword_t := tra(1);
begin

	exec_clk <= not exec_clk after period / 2;
	
	p1: process (all) is
		variable i: integer := 2;
	begin
		dynamic_addr <= naddr when data_ready else caddr;
	
		if running_dynamic then
			if rising_edge(exec_clk) then
				if data_ready then
					caddr <= naddr;
					
					if i < 8 then
						naddr <= tra(i);
					elsif i = 8 then
						clear <= '1';
					elsif i = 9 then
						clear <= '0';
					end if;
					
					i := i + 1;
				end if;
			end if;
		end if;
	end process;
	
	stim: process begin
		running_dynamic <= '0';
		wait until exec_clk = '1';
	
		-- read 12345678 (tag 02468A, block CF, miss)
		address		<= 32x"12345678";
		mem_data	<= (
			8x"01", 8x"02", 8x"03", 8x"04", 8x"05", 8x"06", 8x"07", 8x"08"
		);
		mem_ready	<= '0';
		wait for period * 3;
		
		mem_ready <= '1';
		wait until mem_read = '0';
		mem_ready <= '0';
		
		if data_ready /= '1' then wait until data_ready = '1'; end if;
		wait until exec_clk = '1';
		
		-- read 23456789 (tag 0468AC, block F1, miss)
		address		<= 32x"23456789";
		mem_data	<= (
			8x"02", 8x"03", 8x"04", 8x"05", 8x"06", 8x"07", 8x"08", 8x"09"
		);
		mem_ready	<= '0';
		wait for period * 3;
		
		mem_ready <= '1';
		wait until mem_read = '0';
		mem_ready <= '0';
		
		if data_ready /= '1' then wait until data_ready = '1'; end if;
		wait until exec_clk = '1';
		
		-- read 23456678 (tag 0468AC, block CF, miss)
		address		<= 32x"23456678";
		mem_data	<= (
			8x"02", 8x"03", 8x"04", 8x"05", 8x"06", 8x"06", 8x"07", 8x"08"
		);
		mem_ready	<= '0';
		wait for period * 3;
		
		mem_ready <= '1';
		wait until mem_read = '0';
		mem_ready <= '0';
		
		if data_ready /= '1' then wait until data_ready = '1'; end if;
		wait until exec_clk = '1';
		
		-- read 98765432 (tag 130ECA, block 86, miss)
		address		<= 32x"98765432";
		mem_data	<= (
			8x"09", 8x"08", 8x"07", 8x"06", 8x"05", 8x"04", 8x"03", 8x"02"
		);
		mem_ready	<= '0';
		wait for period * 3;
		
		mem_ready <= '1';
		wait until mem_read = '0';
		mem_ready <= '0';
		
		if data_ready /= '1' then wait until data_ready = '1'; end if;
		wait until exec_clk = '1';
		
		running_dynamic <= '1';
		
		loop
			address <= dynamic_addr;
			wait for 1 ps;
		end loop;
		
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
			
			clear	=> clear,
			
			exec_clk	=> exec_clk
		);
end tb;