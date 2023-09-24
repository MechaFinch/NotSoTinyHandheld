--
-- Mechafinch
-- NST Handheld Project
--
-- nst_debug
-- Outputs debugging info over the SPI bus. 
-- Constantly echoes the state of the register file, the current instruction bytes, and counts of
-- the numbers of executed instructions, exec clock cycles, and memroy clock cycles
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.nst_types.all;

entity nst_debug is
	port (
		-- register file contents
		reg_a:	in nst_word_t;
		reg_b:	in nst_word_t;
		reg_c:	in nst_word_t;
		reg_d:	in nst_word_t;
		reg_i:	in nst_word_t;
		reg_j:	in nst_word_t;
		reg_k:	in nst_word_t;
		reg_l:	in nst_word_t;
		reg_bp:	in nst_dword_t;
		reg_sp:	in nst_dword_t;
		reg_ip:	in nst_dword_t;
		reg_f:	in nst_word_t;
		reg_pf:	in nst_word_t;
		
		-- instruction
		inst_oop:	in nst_byte_t;
		inst_cop:	in nst_byte_t;
		inst_rim:	in nst_byte_t;
		inst_bio:	in nst_byte_t;
		inst_imm:	in nst_dword_t;
		inst_ei8:	in nst_byte_t;
		
		-- counters
		icount:	in nst_dword_t;
		ecount:	in nst_dword_t;
		mcount:	in nst_dword_t;
		
		-- clocks
		exec_clk:	in std_logic;
		mem_clk:	in std_logic;
		spi_clk_in:	in std_logic;
		
		-- control
		debug_enabled:	in std_logic;
		
		-- spi
		spi_sel:		out std_logic_vector(2 downto 0);
		spi_cd:			out std_logic;
		spi_cido:		in std_logic;
		spi_codi:		out std_logic;
		spi_clk_out:	out std_logic
	);
end nst_debug;

architecture a1 of nst_debug is
	-- conveniently, we have 16 values to output
	signal byte_counter:	std_logic_vector(5 downto 0) := "000000";
	signal init_counter:	std_logic_vector(1 downto 0) := "11";
	
	signal current_data:	nst_byte_t;
	
	signal is_reading:		std_logic := '0';
	signal data_available:	std_logic := '0';
	
	-- spi control
	signal spi_addr:	std_logic_vector(1 downto 0) := "00";
	signal spi_in:		nst_byte_t := (others => '0');
	signal spi_out:		nst_byte_t;
	signal spi_read:	std_logic := '0';
	signal spi_write:	std_logic := '0';
begin	
	-- process for controlling spi
	spi_control: process (exec_clk) begin
		-- memory actions take place on the rising edge, change on the falling
		if falling_edge(exec_clk) then
			-- are we on
			if debug_enabled then
				-- initialization
				if init_counter /= "00" then
					init_counter <= std_logic_vector(unsigned(init_counter) - 1);
				
					case init_counter is
						when "11"	=> -- write C0: device 2, default 111, no recieve, c/d high
							spi_addr	<= "01";
							spi_in		<= "10110001";
							spi_write	<= '1';
						
						when "10"	=> -- write C1: clock div 128, no idle clk, no interrupts, device enabled
							spi_addr	<= "10";
							spi_in		<= "11010001";
						
						when others	=> -- stop writing
							spi_write	<= '0';
					end case;
				else
					-- normal operation
					if is_reading then
						-- read S0 to wait for transmit empty
						spi_addr		<= "00";
						spi_write		<= '0';
						spi_read		<= '1';
						data_available	<= '1';
						
						if data_available and spi_out(0) then
							-- transmit is empty, next byte
							is_reading	<= '0';
							
							if byte_counter /= "110110" then
								byte_counter <= std_logic_vector(unsigned(byte_counter) + 1);
							else
								byte_counter <= "000000";
							end if;
						end if;
					else
						-- write
						data_available	<= '0';
						spi_write		<= '1';
						spi_read		<= '0';
						is_reading		<= '1';
						
						-- c/d low on counter zero, c/d high on counter 2
						if byte_counter = "000000" then
							spi_addr	<= "01";
							spi_in		<= "10110000";
						elsif byte_counter = "000010" then
							spi_addr	<= "01";
							spi_in		<= "10110001";
						else
							-- otherwise write the byte
							spi_addr	<= "11";
							spi_in		<= current_data;
						end if;
					end if;
				end if;
			else
				-- disabled - reset initialization
				init_counter <= "11";
			end if;
		end if;
	end process;
	
	-- process for selecing working data
	data_sel: process (all) begin
		with byte_counter select current_data <=
			reg_ip(7 downto 0)		when "000001",
			reg_ip(15 downto 8)		when "000011",
			reg_ip(23 downto 16)	when "000100",
			reg_ip(31 downto 24)	when "000101",
			
			reg_bp(7 downto 0)		when "000110",
			reg_bp(15 downto 8)		when "000111",
			reg_bp(23 downto 16)	when "001000",
			reg_bp(31 downto 24)	when "001001",
			
			reg_sp(7 downto 0)		when "001010",
			reg_sp(15 downto 8)		when "001011",
			reg_sp(23 downto 16)	when "001100",
			reg_sp(31 downto 24)	when "001101",
			
			reg_a(7 downto 0)		when "001110",
			reg_a(15 downto 8)		when "001111",
			
			reg_b(7 downto 0)		when "010000",
			reg_b(15 downto 8)		when "010001",
			
			reg_c(7 downto 0)		when "010010",
			reg_c(15 downto 8)		when "010011",
			
			reg_d(7 downto 0)		when "010100",
			reg_d(15 downto 8)		when "010101",
			
			reg_i(7 downto 0)		when "010110",
			reg_i(15 downto 8)		when "010111",
			
			reg_j(7 downto 0)		when "011000",
			reg_j(15 downto 8)		when "011001",
			
			reg_k(7 downto 0)		when "011010",
			reg_k(15 downto 8)		when "011011",
			
			reg_l(7 downto 0)		when "011100",
			reg_l(15 downto 8)		when "011101",
			
			reg_f(7 downto 0)		when "011110",
			reg_f(15 downto 8)		when "011111",
			
			reg_pf(7 downto 0)		when "100000",
			reg_pf(15 downto 8)		when "100001",
			
			inst_oop				when "100010",
			inst_cop				when "100011",
			inst_rim				when "100100",
			inst_bio				when "100101",
			
			inst_imm(7 downto 0)	when "100110",
			inst_imm(15 downto 8)	when "100111",
			inst_imm(23 downto 16)	when "101000",
			inst_imm(31 downto 24)	when "101001",
			
			inst_ei8				when "101010",
			
			icount(7 downto 0)		when "101011",
			icount(15 downto 8)		when "101100",
			icount(23 downto 16)	when "101101",
			icount(31 downto 24)	when "101110",
			
			ecount(7 downto 0)		when "101111",
			ecount(15 downto 8)		when "110000",
			ecount(23 downto 16)	when "110001",
			ecount(31 downto 24)	when "110010",
			
			mcount(7 downto 0)		when "110011",
			mcount(15 downto 8)		when "110100",
			mcount(23 downto 16)	when "110101",
			mcount(31 downto 24)	when "110110",
			
			x"00"					when others;
	end process;

	-- instantiate spi interface
	spi: entity work.nst_spi_interface
		port map (
			address		=> spi_addr,
			data_in		=> spi_in,
			data_out	=> spi_out,
			exec_clk	=> exec_clk,
			spi_clk		=> spi_clk_in,
			mem_read	=> '0',
			mem_write	=> spi_write,
			interrupt	=> open,
			
			clk		=> spi_clk_out,
			sel		=> spi_sel,
			cd		=> spi_cd,
			cido	=> spi_cido,
			codi	=> spi_codi
		);
end a1;