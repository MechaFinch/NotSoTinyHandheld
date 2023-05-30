--
-- Mechafinch
-- NST Handheld Project
--
-- nst_chip
-- Entity representing the fpga board. This will instantiate components (cpu, spi driver, etc) and
-- map IO pins
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.nst_types.all;

entity nst_chip is
	port (
		-- GPIO
		memory_bus_IN:		in std_logic_vector(15 downto 0);
		memory_bus_OUT:		out std_logic_vector(15 downto 0);
		memory_bus_OE:		out std_logic_vector(15 downto 0);
		mem_addr_low_clk:	out std_logic;
		mem_addr_high_clk:	out std_logic;
		memory_read:		out std_logic;
		memory_write:		out std_logic;
		
		spi_sel:	out std_logic_vector(2 downto 0);
		spi_cd:		out std_logic;
		spi_cido:	in std_logic;
		spi_codi:	out std_logic;
		spi_clk:	out std_logic;
		
		keypad_sel:		out std_logic_vector(4 downto 0);
		keypad_data:	in std_logic;
		
		leds:	out std_logic_vector(3 downto 0);
		btn_1:	in std_logic;
		btn_2:	in std_logic;
		
		-- Device Signals
		-- PLL clocks
		device_exec_clk:	in std_logic;	-- 64 MHz	TBD based on cpu performance
		device_mem_clk:		in std_logic;	-- 4 MHz	TBD based on breadboard memory performance, potentially up to 16 MHz
		device_spi_clk:		in std_logic;	-- 8 MHz	ILI9341 max spi clock is 10 MHz
		device_10khz_clk:	in std_logic	-- 10 kHz	from the oscillator
	);
end nst_chip;

architecture a1 of nst_chip is
	-- counters so we can see things changing
	signal dword_counter:	nst_dword_t := x"12345678";
	signal abcd_counter:	nst_word_t := x"1234";
	signal ijkl_counter:	nst_word_t := x"5678";
	signal fpf_counter:		nst_word_t := x"9ABC";
	signal instr:			nst_dword_t := x"5353F390";
	signal inst_imm:		nst_dword_t := x"21436576";
	signal inst_ei8:		nst_byte_t := x"EF";
	signal icount:			nst_dword_t := (others => '0');
	signal ecount:			nst_dword_t := (others => '0');
	signal mcount:			nst_dword_t := (others => '0');
	
	-- singal OE for the full memory bus
	signal mem_bus_oe:	std_logic;
begin
	-- debug test
	ledproc: process (all) begin
		-- leds are active low
		leds(3)	<= not spi_cd;
		leds(2)	<= not spi_cido;
		leds(1)	<= not spi_codi;
		leds(0)	<= not spi_clk;
		
		keypad_sel(0)			<= device_10khz_clk;
		keypad_sel(4 downto 1)	<= (others => '0');
	end process;
	
	--keypad_sel	<= "00000";
	
	counter_proc: process (all) begin
		if rising_edge(device_exec_clk) then
			ecount <= std_logic_vector(unsigned(ecount) + 1);
		end if;
		
		if rising_edge(device_mem_clk) then
			mcount <= std_logic_vector(unsigned(mcount) + 1);
		end if;
		
		if rising_edge(device_10khz_clk) then
			icount <= std_logic_vector(unsigned(icount) + 1);
			
			if icount(11 downto 0) = 12x"000" then
				dword_counter	<= std_logic_vector(unsigned(dword_counter) + 1);
				abcd_counter	<= std_logic_vector(unsigned(abcd_counter) + 1);
				ijkl_counter	<= std_logic_vector(unsigned(ijkl_counter) + 1);
				fpf_counter		<= std_logic_vector(unsigned(fpf_counter) + 1);
			end if;
		end if;
	end process;
	
	debug: entity work.nst_debug
		port map (
			reg_a	=> abcd_counter,
			reg_b	=> abcd_counter,
			reg_c	=> abcd_counter,
			reg_d	=> abcd_counter,
			reg_i	=> ijkl_counter,
			reg_j	=> ijkl_counter,
			reg_k	=> ijkl_counter,
			reg_l	=> ijkl_counter,
			reg_bp	=> dword_counter,
			reg_sp	=> dword_counter,
			reg_ip	=> dword_counter,
			reg_f	=> fpf_counter,
			reg_pf	=> fpf_counter,
			
			inst_oop	=> instr(31 downto 24),
			inst_cop	=> instr(23 downto 16),
			inst_rim	=> instr(15 downto 8),
			inst_bio	=> instr(7 downto 0),
			inst_imm	=> inst_imm,
			inst_ei8	=> inst_ei8,
			
			icount	=> icount,
			ecount	=> ecount,
			mcount	=> mcount,
			
			exec_clk	=> device_exec_clk,
			mem_clk		=> device_mem_clk,
			spi_clk_in	=> device_10khz_clk,
			
			spi_sel		=> spi_sel,
			spi_cd		=> spi_cd,
			spi_cido	=> spi_cido,
			spi_codi	=> spi_codi,
			spi_clk_out	=> spi_clk
		);

	-- just keep things off until we use them
	-- to be handled by memory interface
	memory_bus_OUT		<= (others => '0');
	memory_bus_OE		<= (others => mem_bus_oe);
	mem_bus_oe			<= '0';
	mem_addr_low_clk	<= '0';
	mem_addr_high_clk	<= '0';
	memory_read			<= '0';
	memory_write		<= '0';
	
	-- to be handled by SPI interface
	--spi_sel				<= "000";
	--spi_cd				<= '0';
	--spi_codi			<= '0';
	--spi_clk				<= '0';
end a1;