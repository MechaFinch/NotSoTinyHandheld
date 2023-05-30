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
		mem_clk:	in std_logic;
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
--		S0
--			Read Full				bit 1		Set when read full; data can be read
--			Transmit Empty			bit	0		Set when transmit empty; data can be written
--
--	Configuration Bytes
--		C0
--			Device					bit 7:5		Controls the select lines
--			Device Default			bit 4		All bits of sel are set to this when idle/disabled
--			Command/Data			bit 0		The command/data pin is set to this when the device is enabled
--
--		C1
--			Clock Divider			bit 6:4		Selects the clock division bit (divide by 2^n)
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
		unused:					std_logic;
		clock_divider:			std_logic_vector(2 downto 0);
		idle_clock:				std_logic;
		enable_te_interrupts:	std_logic;
		enable_rf_interrupts:	std_logic;
		enable_device:			std_logic;
	end record;
	
	-- clock stuff
	signal spi_clk_divided:		std_logic := '0';
	signal clk_divider_counter:	std_logic_vector(6 downto 0) := (others => '0');
	
	-- status bits
	signal read_full:			std_logic := '0';
	signal transmit_empty:		std_logic := '1';
	signal transmit_waiting:	std_logic := '0';
	
	signal set_read_full:	std_logic_vector(1 downto 0) := "11";
	signal clear_read_full:	std_logic_vector(1 downto 0) := "11";
	
	signal set_transmit_empty:		std_logic_vector(1 downto 0) := "11";
	signal clear_transmit_empty:	std_logic_vector(1 downto 0) := "11";
	
	signal set_transmit_waiting:	std_logic_vector(1 downto 0) := "11";
	signal clear_transmit_waiting:	std_logic_vector(1 downto 0) := "11";
	
	-- configuration bits
	signal c0:	c0_t := (3x"7", '1', 3x"0", '0');
	signal c1:	c1_t := ('0', 3x"0", '0', '0', '0', '0');
	
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
	
	-- edge triggered SR via the fast exec clock
	rfte: process (exec_clk) begin
		if rising_edge(exec_clk) then
			-- change on rising edge
			if set_read_full(0) and not set_read_full(1) then
				read_full <= '1';
			elsif clear_read_full(0) and not clear_read_full(1) then
				read_full <= '0';
			end if;
			
			if set_transmit_empty(0) and not set_transmit_empty(1) then
				transmit_empty <= '1';
			elsif clear_transmit_empty(0) and not clear_transmit_empty(1) then
				transmit_empty <= '0';
			end if;
			
			if set_transmit_waiting(0) and not set_transmit_waiting(1) then
				transmit_waiting <= '1';
			elsif clear_transmit_waiting(0) and not clear_transmit_waiting(1) then
				transmit_waiting <= '0';
			end if;
			
			-- latching twice allows reliable clock domain switching when not phase locked
			-- it also consolidates the edge detection into the same signal
			set_read_full(1)	<= set_read_full(0);
			set_read_full(0)	<= '1' when (transmit_counter = 3x"0") else '0';
			
			clear_read_full(1)	<= clear_read_full(0);
			clear_read_full(0)	<= mem_clk and mem_read and address(0) and address(1);
			
			set_transmit_empty(1)	<= set_transmit_empty(0);
			set_transmit_empty(0)	<= '1' when (transmit_counter = 3x"0") else '0';
			
			clear_transmit_empty(1)	<= clear_transmit_empty(0);
			clear_transmit_empty(0)	<= mem_clk and mem_write and address(0) and address(1);
			
			set_transmit_waiting(1)	<= set_transmit_waiting(0);
			set_transmit_waiting(0)	<= mem_clk and mem_write and address(0) and address(1);
			
			clear_transmit_waiting(1)	<= clear_transmit_waiting(0);
			clear_transmit_waiting(0)	<= (not spi_clk_divided) and transmitting and transmit_waiting;
		end if;
	end process;
	
	-- clock division
	clock_div_proc: process (spi_clk) begin
		if rising_edge(spi_clk) then
			clk_divider_counter <= std_logic_vector(unsigned(clk_divider_counter) + 1);
		end if;
	end process;
	
	clock_sel_proc: process (all) begin
		with c1.clock_divider select spi_clk_divided <=
			clk_divider_counter(6)	when "111",		-- 128
			clk_divider_counter(5)	when "110",		-- 64
			clk_divider_counter(4)	when "101",		-- 32
			clk_divider_counter(3)	when "100",		-- 16
			clk_divider_counter(2)	when "011",		-- 8
			clk_divider_counter(1)	when "010",		-- 4
			clk_divider_counter(0)	when "001",		-- 2
			spi_clk					when others;	-- 1
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
	
	-- memory read
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
			
			when 2x"2" =>	data_out(7)				<= c1.unused;
							data_out(6 downto 4)	<= c1.clock_divider;
							data_out(3)				<= c1.idle_clock;
							data_out(2)				<= c1.enable_te_interrupts;
							data_out(1)				<= c1.enable_rf_interrupts;
							data_out(0)				<= c1.enable_device;
			
			when others =>	data_out <= recieve_buffer;
		end case;
		
		-- writes
		if rising_edge(mem_clk) then
			if mem_write then
				case address is
					when 2x"0" => null; -- S0
					
					when 2x"1" => -- C0
						c0.device			<= data_in(7 downto 5);
						c0.device_default	<= data_in(4);
						c0.unused			<= data_in(3 downto 1);
						c0.command_data		<= data_in(0);
					
					when 2x"2" => -- C1
						c1.unused				<= data_in(7);
						c1.clock_divider		<= data_in(6 downto 4);
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