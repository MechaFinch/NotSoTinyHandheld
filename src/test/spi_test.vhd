--
-- Mechafinch
-- NST Handheld Project
--
-- spi_test
-- Testbench for the spi interface
--

library ieee;
use ieee.std_logic_1164.all;
use work.nst_types.all;

entity spi_test is
end spi_test;

architecture tb of spi_test is
	-- interface signals
	signal address:		std_logic_vector(1 downto 0) := 2x"0";
	signal data_in:		nst_byte_t := 8x"00";
	signal data_out:	nst_byte_t;
	
	signal spi_clk:		std_logic := '0';
	signal mem_clk:		std_logic := '0';
	signal mem_read:	std_logic := '0';
	signal mem_write:	std_logic := '0';
	
	signal interrupt:	std_logic;
	
	signal clk:		std_logic;
	signal sel:		std_logic_vector(2 downto 0);
	signal cd:		std_logic;
	signal cido:	std_logic := '0';
	signal codi:	std_logic;
	
	-- test record
	type tr is record
		address:	std_logic_vector(1 downto 0) := 2x"0";
		data_in:	nst_byte_t := 8x"00";
		--data_out:	nst_byte_t;
	
		--spi_clk:	std_logic := '0';
		--mem_clk:	std_logic := '0';
		mem_write:	std_logic := '0';
		
		--interrupt:	std_logic;
		
		--clk:	std_logic;
		--sel:	std_logic_vector(2 downto 0);
		--cd:		std_logic;
		cido:	std_logic := '0';
		--codi:	std_logic;
		
		len:	time;
	end record;
	
	type tra is array (natural range <>) of tr;
	
	-- just inputs, manual verification
	constant tests: tra := (
		(2x"0", 8x"00", '0', '0', 100 ns)
	);
begin
	uut: entity work.nst_spi_interface
		port map (
			address		=> address,
			data_in		=> data_in,
			data_out	=> data_out,
			spi_clk		=> spi_clk,
			mem_clk		=> mem_clk,
			mem_write	=> mem_write,
			interrupt	=> interrupt,
			clk			=> clk,
			sel			=> sel,
			cd			=> cd,
			cido		=> cido,
			codi		=> codi
		);
	
	spi_clk	<= not spi_clk after 10 ns;
	mem_clk	<= not mem_clk after 20 ns;
	
	stim: process begin
		for i in tests'range loop
			address		<= tests(i).address;
			data_in		<= tests(i).data_in;
			mem_write	<= tests(i).mem_write;
			cido		<= tests(i).cido;
			
			wait for tests(i).len;
		end for;
		
		-- stop sim
		assert false report
			"tests complete"
			severity failure;
	end process;
end tb;