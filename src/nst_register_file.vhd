--
-- Mechafinch
-- NST Handheld Project
--
-- nst_register_file
-- Register file.
--

library ieee;
use ieee.std_logic_1164.all;
use work.nst_types.all;

entity nst_register_file is
	port (
		clk:			in std_logic;
		primary_rfi:	in nst_word_t;
		secondary_rfi:	in nst_word_t;
		bulk_data:		in bulk_data_t;	-- for POPA
		sp_offset:		in nst_dword_t;
		f_val:			in nst_word_t;
		popa_en:		in std_logic;
		sp_sel:			in std_logic;	-- 1 for push/pop
		
		al_en:	in std_logic;
		al_sen:	in std_logic;
		ah_en:	in std_logic;
		ah_sen:	in std_logic;
		a_en:	in std_logic;
		a_sen:	in std_logic;
		bl_en:	in std_logic;
		bl_sen:	in std_logic;
		bh_en:	in std_logic;
		bh_sen:	in std_logic;
		b_en:	in std_logic;
		b_sen:	in std_logic;
		cl_en:	in std_logic;
		cl_sen:	in std_logic;
		ch_en:	in std_logic;
		ch_sen:	in std_logic;
		c_en:	in std_logic;
		c_sen:	in std_logic;
		dl_en:	in std_logic;
		dl_sen: in std_logic;
		dh_en:	in std_logic;
		dh_sen:	in std_logic;
		d_en:	in std_logic;
		d_sen:	in std_logic;
		i_en:	in std_logic;
		i_sen:	in std_logic;
		j_en:	in std_logic;
		j_sen:	in std_logic;
		k_en:	in std_logic;
		k_sen:	in std_logic;
		l_en:	in std_logic;
		l_sen:	in std_logic;
		bp_en:	in std_logic;
		sp_en:	in std_logic;
		f_en:	in std_logic;
		pf_en:	in std_logic;
		
		a_out:	out nst_word_t;
		b_out:	out nst_word_t;
		c_out:	out nst_word_t;
		d_out:	out nst_word_t;
		i_out:	out nst_word_t;
		j_out:	out nst_word_t;
		k_out:	out nst_word_t;
		l_out:	out nst_word_t;
		bp_out:	out nst_dword_t;
		sp_out:	out nst_dword_t;
		f_out:	out nst_word_t;
		pf_out:	out nst_word_t
	);
end nst_register_file;

architecture a1 of nst_register_file is
	-- registers
	signal	reg_al, reg_ah, reg_bl, reg_bh,
			reg_cl, reg_ch, reg_dl, reg_dh:	nst_byte_t := (others => '0');
			
	signal	reg_i, reg_j, reg_k, reg_l,
			reg_f, reg_pf: 				nst_word_t := (others => '0');
	
	signal reg_bp, reg_sp: nst_dword_t := (others => '0');
begin
	-- assign outputs
	a_out	<= (reg_ah, reg_al);
	b_out	<= (reg_bh, reg_bl);
	c_out	<= (reg_ch, reg_cl);
	d_out	<= (reg_dh, reg_dl);
	i_out	<= reg_i;
	j_out	<= reg_j;
	k_out	<= reg_k;
	l_out	<= reg_l;
	bp_out	<= reg_bp;
	sp_out	<= reg_sp;
	f_out	<= reg_f;
	pf_out	<= reg_pf;
	
	-- process for A
	a_proc: process (clk) is begin
		if rising_edge(clk) then
			-- AL
			if (popa_en = '1') or (a_en = '1') or (a_sen = '1') or (al_en = '1') or (al_sen = '1') then
				reg_al <=	bulk_data(9)(7 downto 0)	when popa_en = '1' else
							secondary_rfi(7 downto 0)	when (al_sen = '1') or (a_sen = '1') else
							primary_rfi(7 downto 0);
			end if;
			
			-- AH
			if (popa_en = '1') or (a_en = '1') or (a_sen = '1') or (ah_en = '1') or (ah_sen = '1') then
				reg_ah <=	bulk_data(9)(15 downto 8)	when popa_en = '1' else
							secondary_rfi(7 downto 0)	when ah_sen = '1' else
							secondary_rfi(15 downto 8)	when a_sen = '1' else
							primary_rfi(7 downto 0);
			end if;
		end if;
	end process a_proc;
	
	-- process for B
	b_proc: process (clk) is begin
		if rising_edge(clk) then
			-- BL
			if (popa_en = '1') or (b_en = '1') or (b_sen = '1') or (bl_en = '1') or (bl_sen = '1') then
				reg_bl <=	bulk_data(8)(7 downto 0)	when popa_en = '1' else
							secondary_rfi(7 downto 0)	when (bl_sen = '1') or (b_sen = '1') else
							primary_rfi(7 downto 0);
			end if;
			
			-- BH
			if (popa_en = '1') or (b_en = '1') or (b_sen = '1') or (bh_en = '1') or (bh_sen = '1') then
				reg_bh <=	bulk_data(8)(15 downto 8)	when popa_en = '1' else
							secondary_rfi(7 downto 0)	when bh_sen = '1' else
							secondary_rfi(15 downto 8)	when b_sen = '1' else
							primary_rfi(7 downto 0);
			end if;
		end if;
	end process b_proc;
	
	-- process for C
	c_proc: process (clk) is begin
		if rising_edge(clk) then
			-- CL
			if (popa_en = '1') or (c_en = '1') or (c_sen = '1') or (cl_en = '1') or (cl_sen = '1') then
				reg_cl <=	bulk_data(7)(7 downto 0)	when popa_en = '1' else
							secondary_rfi(7 downto 0)	when (cl_sen = '1') or (c_sen = '1') else
							primary_rfi(7 downto 0);
			end if;
			
			-- CH
			if (popa_en = '1') or (c_en = '1') or (c_sen = '1') or (ch_en = '1') or (ch_sen = '1') then
				reg_ch <=	bulk_data(7)(15 downto 8)	when popa_en = '1' else
							secondary_rfi(7 downto 0)	when ch_sen = '1' else
							secondary_rfi(15 downto 8)	when c_sen = '1' else
							primary_rfi(7 downto 0);
			end if;
		end if;
	end process c_proc;
	
	-- process for D
	d_proc: process (clk) is begin
		if rising_edge(clk) then
			-- DL
			if (popa_en = '1') or (d_en = '1') or (d_sen = '1') or (dl_en = '1') or (dl_sen = '1') then
				reg_dl <=	bulk_data(6)(7 downto 0)	when popa_en = '1' else
							secondary_rfi(7 downto 0)	when (dl_sen = '1') or (d_sen = '1') else
							primary_rfi(7 downto 0);
			end if;
			
			-- DH
			if (popa_en = '1') or (d_en = '1') or (d_sen = '1') or (dh_en = '1') or (dh_sen = '1') then
				reg_dh <=	bulk_data(6)(15 downto 8)	when popa_en = '1' else
							secondary_rfi(7 downto 0)	when dh_sen = '1' else
							secondary_rfi(15 downto 8)	when d_sen = '1' else
							primary_rfi(7 downto 0);
			end if;
		end if;
	end process d_proc;
	
	-- process for I
	i_proc: process (clk) is begin
		if rising_edge(clk) then
			if (popa_en = '1') or (i_en = '1') or (i_sen = '1') then
				reg_i <=	bulk_data(5)	when popa_en = '1' else
							secondary_rfi	when i_sen = '1' else
							primary_rfi;
			end if;
		end if;
	end process i_proc;
	
	-- process for J
	j_proc: process (clk) is begin
		if rising_edge(clk) then
			if (popa_en = '1') or (j_en = '1') or (j_sen = '1') then
				reg_j <=	bulk_data(4)	when popa_en = '1' else
						secondary_rfi	when j_sen = '1' else
						primary_rfi;
			end if;
		end if;
	end process j_proc;
	
	-- process for K
	k_proc: process (clk) is begin
		if rising_edge(clk) then
			if (popa_en = '1') or (k_en = '1') or (k_sen = '1') then
				reg_k <=	bulk_data(3)	when popa_en = '1' else
							secondary_rfi	when k_sen = '1' else
							primary_rfi;
			end if;
		end if;
	end process k_proc;
	
	-- process for L
	l_proc: process (clk) is begin
		if rising_edge(clk) then
			if (popa_en = '1') or (l_en = '1') or (l_sen = '1') then
				reg_l <=	bulk_data(2)	when popa_en = '1' else
							secondary_rfi	when l_sen = '1' else
							primary_rfi;
			end if;
		end if;
	end process l_proc;
	
	-- process for BP
	bp_proc: process (clk) is begin
		if rising_edge(clk) then
			if (popa_en = '1') or (bp_en = '1') then
				reg_bp <=	(bulk_data(1), bulk_data(0))	when popa_en = '1' else
							(secondary_rfi, primary_rfi);
			end if;
		end if;
	end process bp_proc;
	
	-- process for SP
	sp_proc: process (clk) is begin
		if rising_edge(clk) then
			if sp_en = '1' then
				reg_sp <=	sp_offset						when sp_sel = '1' else
							(secondary_rfi, primary_rfi);
			end if;
		end if;
	end process sp_proc;
	
	-- process for F
	f_proc: process (clk) is begin
		if rising_edge(clk) then
			if f_en = '1' then
				reg_f <= f_val;
			end if;
		end if;
	end process f_proc;
	
	-- process for PF
	pf_proc: process (clk) is begin
		if rising_edge(clk) then
			if pf_en = '1' then
				reg_pf <= primary_rfi;
			end if;
		end if;
	end process pf_proc;
end a1;