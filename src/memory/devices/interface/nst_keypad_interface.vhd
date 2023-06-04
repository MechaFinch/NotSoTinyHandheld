--
-- Mechafinch
-- NST Handheld Project
--
-- nst_keypad_interface
-- Interface for the keypad. The keypad is a matrix of up to 32 buttons accessed with a selector
-- and a data pin. This module should track the state of the buttons, send interrupts on state
-- changes when enabled, and handle memory-mapped configuration.
--
-- Memory Map
--	3:0	Data
--		32 bits of data. If a key is pressed, it reads 1, and 0 if unpressed.
--
--	4	Last Pressed
--		Contains the last button ID to be pressed
--
--	5	Last Released
--		Contains the last button ID to be released
--
--	6	Config
--		Enable Release Interrupts	bit 2	If set, interrupt will be set when a button is released
--		Enable Press Interrupts		bit 1	If set, interrupt will be set when a button is pressed
--		Enable Device				bit 0		
--
-- Operation
--	The Data register can be read to recieve the status of every button.
--	The Last Pressed and Last Released registers can be read to recieve the most recent respective
--	event
--	If interrupts are enabled, reading the Data register will clear both interrupt source. Reading
--	the Last Pressed and Last Released registers will only clear their respective interrupt.
--

library ieee;
use ieee.std_logic_1164.all;
use work.nst_types.all;

entity nst_keypad_interface is
	port (
		-- memory mapped control
		address:	in std_logic_vector(2 downto 0);
		data_in:	in nst_byte_t;
		data_out:	out nst_byte_t;
		
		exec_clk:	in std_logic;
		mem_read:	in std_logic;
		mem_write:	in std_logic;
		
		interrupt:	out std_logic;
		
		-- IO
		sel:	out std_logic_vector(4 downto 0);
		data:	in std_logic
	);
end nst_keypad_interface;

architecture a1 of nst_keypad_interface is
	-- device state
	type button_state_array_t is array (31 downto 0) of std_logic;
	signal button_states:		button_state_array_t;
	signal current_selection:	std_logic_vector(4 downto 0) := "00000";
	
	signal press_interrupt_active:		std_logic := '0';
	signal release_interrupt_active:	std_logic := '0';
	
	signal last_pressed:	nst_byte_t := x"00";
	signal last_released:	nst_byte_t := x"00";
	
	signal config:	nst_byte_t := x"00";
begin
	-- combinational output
	sel			<= current_selection when config(0) else (others => '0');
	interrupt	<= config(0) and (
		(press_interrupt_active and config(1)) or
		(release_interrupt_active and config(2))
	);
	
	-- button monitoring
	button_proc: process (all) is
		variable current_integer: integer;
	begin
		current_integer := to_integer(unsigned(current_selection);
		
		if rising_edge(exec_clk) then
			-- if enabled
			if config(0) then
				-- update button state and working id
				button_states(current_integer)	<= data;
				current_selection				<= std_logic_vector(unsigned(current_selection) + 1);
			
				-- check edges
				if data and (not button_states(current_integer)) then
					last_pressed <= ((others => '0'), current_selection);
					
					-- press interrupt enabled and an interrupt-clearing address isn't being read
					if config(1) and ((not mem_read) or (address = 3x"5") or (address = 3x"6") or (address = 3x"7")) then
						press_interrupt_active <= '1';
					end if;
				elsif (not data) and button_states(current_integer) then
					last_released <= ((others => '0'), current_selection);
					
					-- release interrupt enabled and an interrupt-clearing address isn't being read
					if config(2) and ((not mem_read) or (address = 3x"4") or (address = 3x"6") or (address = 3x"7")) then
						release_interrupt_active <= '1';
					end if;
				end if;
			end if;
		end if;
	end process;
	
	-- memory control process
	mem_proc: process (all) begin
		-- combinational read
		case address is
			when 3x"0" =>	data_out <= button_states(7 downto 0);
			when 3x"1" =>	data_out <= button_states(15 downto 8);
			when 3x"2" =>	data_out <= button_states(23 downto 16);
			when 3x"3" =>	data_out <= button_states(31 downto 24);
			when 3x"4" =>	data_out <= last_pressed;
			when 3x"5" =>	data_out <= last_released;
			when 3x"6" =>	data_out <= config;
			when others =>	data_out <= (others => '0');
		end case;
		
		-- clocked write/interrupt clearing
		if rising_edge(exec_clk) then
			if mem_write then
				case address is
					when 3x"6" =>	config <= data_in;
					
					when others =>	null;
				end case;
			end if;
			
			if mem_read then
				case address is
					when 3x"0" |
						 3x"1" |
						 3x"2" |
						 3x"3" =>	press_interrupt_active		<= '0';
									release_interrupt_active	<= '0';
					when 3x"4" =>	press_interrupt_active		<= '0';
					when 3x"5" =>	release_interrupt_active	<= '0';
					
					when others =>	null;
				end case;
			end if;
		end if;
	end process;
end a1;