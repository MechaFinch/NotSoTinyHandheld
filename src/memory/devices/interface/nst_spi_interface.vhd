--
-- Mechafinch
-- NST Handheld Project
--
-- nst_spi_interface
-- SPI bus interface. This module will operate the SPI bus, including interrupts, memory-mapped
-- IO/config, and so on.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.nst_types.all;

entity nst_spi_interface is
	port (
		-- memory-mapped control
		address:	in std_logic_vector(1 downto 0);
		data_in:	in nst_byte_t;
		data_out:	out nst_byte_t;
		
		exec_clk:	in std_logic;
		spi_clk:	in std_logic;
		mem_read:	in std_logic;
		mem_write:	in std_logic;
		
		interrupt:	out std_logic;
	
		-- IO
		clk:		out std_logic;						-- clock
		sel:		out std_logic_vector(2 downto 0);	-- select lines or selection number depending on wiring
		cd:			out std_logic;						-- command/data
		cido:		in std_logic;						-- controller in device out
		codi:		out std_logic := '0'				-- controller out device in
	);
end nst_spi_interface;

-- Description of Operation
--	Register Offsets
--		S0	0
--		C0	1
--		C1	2
--		D	3
--
--	Status Bytes
--		S0	0
--			Read Full				bit 1		Set when read full; data can be read
--			Transmit Empty			bit	0		Set when transmit empty; data can be written
--
--	Configuration Bytes
--		C0	1
--			Device					bit 7:5		Controls the select lines
--			Device Default			bit 4		All bits of sel are set to this when idle/disabled
--			Recieve Data			bit 1		If set, data is recieved during transmit. If clear, the recieve buffer is unaffected by transmit.
--			Command/Data			bit 0		The command/data pin is set to this when the device is enabled
--
--		C1	2
--			Clock Divider			bit 7:4		Selects the clock division bit (divide by 2^n)
--			Idle Clock				bit 3		If set, the clock will continue while idle
--			Enable TE Interrupts	bit 2		If set, interrupt will be set while S0 Transmit Empty is set
--			Enable RF Interrupts	bit 1		If set, interrupt will be set while S0 Read Full is set
--			Enable Device			bit 0		If set, the device is enabled. When disabled, outputs will take default values
--
--	Operation
--		To transmit and/or recieve data, data to be transmitted is written to the D register
--		If the Transmit Empty bit of S0 is not set, writes are ignored. When a write is accepted,
--		the Transmit Empty bit is cleared.
--		To read recieved data, the D register is read. If the Read Full bit of S0 is not set,
--		the read data may not be valid. When the D register is read, the Read Full bit is cleared.
--
--		To select a device for operation, set the C0 field Device. While tramitting, this field
--		will be output to the corresponding pins. While idle or disabled, the pins will take the
--		value of C0 field Device Default. 
--

architecture a1 of nst_spi_interface is
	-- register types
	type c0_t is record
		device:			std_logic_vector(2 downto 0);
		device_default:	std_logic;
		unused:			std_logic_vector(2 downto 0);
		command_data:	std_logic;
	end record;
	
	type c1_t is record
		clock_divider:			std_logic_vector(3 downto 0);
		idle_clock:				std_logic;
		enable_te_interrupts:	std_logic;
		enable_rf_interrupts:	std_logic;
		enable_device:			std_logic;
	end record;
	
	-- clock stuff
	signal spi_clk_divided:		std_logic := '0';
	signal clk_divider_counter:	std_logic_vector(14 downto 0) := (others => '0');
	
	-- status bits
	signal read_full:			std_logic := '0';
	signal transmit_empty:		std_logic := '1';
	signal transmit_waiting:	std_logic := '0';
	
	signal transmit_counter_zero:	std_logic_vector(1 downto 0) := "00";
	signal transmit_ongoing:		std_logic_vector(1 downto 0) := "00";
	
	-- configuration bits
	signal c0:	c0_t := (3x"7", '1', 3x"0", '0');
	signal c1:	c1_t := (4x"0", '0', '0', '0', '0');
	
	-- internal state
	signal transmitting:		std_logic := '0';
	signal transmit_counter:	std_logic_vector(2 downto 0) := "000";
	
	signal transmit_buffer:		nst_byte_t := x"00";
	signal transmit_mem_buffer:	nst_byte_t := x"00";
	signal recieve_buffer:		nst_byte_t := x"00";
begin
	-- basic stuff
	clk	<= c1.enable_device and spi_clk_divided and (transmitting or c1.idle_clock);
	
	sel	<=	c0.device when transmitting else
			(others => c0.device_default);
	
	cd	<=	c1.enable_device and c0.command_data;
	
	interrupt <=	c1.enable_device and (
						(c1.enable_te_interrupts and transmit_empty) or
						(c1.enable_rf_interrupts and read_full)
					);
	
	-- state management
	rfte: process (exec_clk) begin
		if rising_edge(exec_clk) then
			-- edge detectors
			transmit_counter_zero(1)	<= transmit_counter_zero(0);
			transmit_counter_zero(0)	<= '1' when (transmit_counter = 3x"0") else '0';
			
			transmit_ongoing(1)	<= transmit_ongoing(0);
			transmit_ongoing(1)	<= (not spi_clk_divided) and transmitting and transmit_waiting;
		
			-- read full is set on the transition to transmit counter = 0
			-- read full is cleared when data is read
			if mem_read and address(0) and address(1) then
				read_full <= '0';
			elsif transmit_counter_zero(0) and not transmit_counter_zero(1) then
				read_full <= '1';
			end if;
			
			-- transmit empty is set on the transition to transmit counter = 0
			-- transmit empty is cleared when data is written
			-- transmit waiting is set when data is written
			-- transmit waiting is cleared when transmission begins
			if mem_write and address(0) and address(1) then
				transmit_empty		<= '0';
				transmit_waiting	<= '1';
			else
				if transmit_counter_zero(0) and not transmit_counter_zero(1) then
					transmit_empty <= '1';
				end if;
				
				if transmit_ongoing(0) and not transmit_ongoing(1) then
					transmit_waiting <= '0';
				end if;
			end if;
		end if;
	end process;
	
	-- clock division
	clock_div_proc: process (spi_clk) begin
		if rising_edge(spi_clk) then
			clk_divider_counter <= std_logic_vector(unsigned(clk_divider_counter) + 1);
		end if;
	end process;
	
	clock_sel_proc: process (all) begin
		with c1.clock_divider select spi_clk_divided <=	--		64 MHz		8 MHz		10 kHz
			clk_divider_counter(14)	when "1111",	-- 32768	1.95 kHz	244 Hz		0.31 Hz
			clk_divider_counter(13)	when "1110",	-- 16384	3.91 kHz	488 Hz		0.61 Hz
			clk_divider_counter(12)	when "1101",	-- 8192		7.81 kHz	977 Hz		1.22 Hz
			clk_divider_counter(11)	when "1100",	-- 4069		15.63 kHz	1.95 kHz	2.44 Hz
			clk_divider_counter(10)	when "1011",	-- 2048		31.25 kHz	3.91 kHz	4.88 Hz
			clk_divider_counter(9)	when "1010",	-- 1024		62.5 kHz	7.81 kHz	9.77 Hz
			clk_divider_counter(8)	when "1001",	-- 512		125 kHz		15.63 kHz	19.5 Hz
			clk_divider_counter(7)	when "1000",	-- 256		250 kHz		31.25 kHz	39 Hz
			clk_divider_counter(6)	when "0111",	-- 128		500 kHz		62.5 kHz	78 Hz
			clk_divider_counter(5)	when "0110",	-- 64		1 MHz		125 kHz		156 Hz
			clk_divider_counter(4)	when "0101",	-- 32		2 MHz		250 kHz		313 Hz
			clk_divider_counter(3)	when "0100",	-- 16		4 MHz		500 kHz		625 Hz
			clk_divider_counter(2)	when "0011",	-- 8		8 MHz		1 MHz		1.25 kHz
			clk_divider_counter(1)	when "0010",	-- 4		16 MHz		2 MHz		2.5 kHz
			clk_divider_counter(0)	when "0001",	-- 2		32 MHz		4 MHz		5 kHz
			spi_clk					when others;	-- 1		64 MHz		8 MHz		10 kHz
	end process;
	
	-- operating process
	spi_proc: process (spi_clk_divided) begin
		-- most things happen on the falling edge
		if falling_edge(spi_clk_divided) then
			if c1.enable_device then
				if transmitting then
					-- transmitting: 
					if transmit_counter = 3x"7" then
						transmitting	<= '0';
					end if;
					
					transmit_counter	<= std_logic_vector(unsigned(transmit_counter) + 1);
					codi				<= transmit_buffer(7);
					
					transmit_buffer(7 downto 1)	<= transmit_buffer(6 downto 0);
					transmit_buffer(0)			<= '0';
				else
					-- not transmitting: wait for something to transmit
					if transmit_waiting then
						transmitting		<= '1';
						
						transmit_counter	<= 3x"0";
						codi				<= transmit_mem_buffer(7);
						
						transmit_buffer(7 downto 1)	<= transmit_mem_buffer(6 downto 0);
						transmit_buffer(0)			<= '0';
					end if;
				end if;
			end if;
		end if;
		
		-- data is read on the rising edge
		if rising_edge(spi_clk_divided) then
			if c1.enable_device and transmitting then
				recieve_buffer(7 downto 1)	<= recieve_buffer(6 downto 0);
				recieve_buffer(0)			<= cido;
			end if;
		end if;
	end process;
	
	-- memory control process
	mem_proc: process (all) begin
		-- reads
		case address is
			when 2x"0" =>	data_out(7 downto 2)	<= (others => '0');
							data_out(1)				<= read_full;
							data_out(0)				<= transmit_empty;
			
			when 2x"1" =>	data_out(7 downto 5)	<= c0.device;
							data_out(4)				<= c0.device_default;
							data_out(3 downto 1)	<= c0.unused;
							data_out(0)				<= c0.command_data;
			
			when 2x"2" =>	data_out(7 downto 4)	<= c1.clock_divider;
							data_out(3)				<= c1.idle_clock;
							data_out(2)				<= c1.enable_te_interrupts;
							data_out(1)				<= c1.enable_rf_interrupts;
							data_out(0)				<= c1.enable_device;
			
			when others =>	data_out <= recieve_buffer;
		end case;
		
		-- writes
		if rising_edge(exec_clk) then
			if mem_write then
				case address is
					when 2x"0" => null; -- S0
					
					when 2x"1" => -- C0
						c0.device			<= data_in(7 downto 5);
						c0.device_default	<= data_in(4);
						c0.unused			<= data_in(3 downto 1);
						c0.command_data		<= data_in(0);
					
					when 2x"2" => -- C1
						c1.clock_divider		<= data_in(7 downto 4);
						c1.idle_clock			<= data_in(3);
						c1.enable_te_interrupts	<= data_in(2);
						c1.enable_rf_interrupts	<= data_in(1);
						c1.enable_device		<= data_in(0);
					
					when others => -- D
						-- start a write if possible
						if not transmitting then
							transmit_mem_buffer	<= data_in;
						end if;
				end case;
			end if;
		end if;
	end process;
end a1;