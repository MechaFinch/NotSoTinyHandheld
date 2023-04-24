--
-- Mechafinch
-- NST Handheld Project
--
-- nst_constants
-- Sets of constants for use in the NST cpu
--

library ieee;
use ieee.std_logic_1164.all;
use work.nst_types.all;

package nst_constants is
	-- device constants
	constant MEMORY_DATA_WIDTH:	integer := 16;

	-- opcodes
	constant OP_NOP:			nst_byte_t := x"00";
	constant OP_MOVW_RIM:		nst_byte_t := x"01";
	constant OP_MOVS_RIM:		nst_byte_t := x"02";
	constant OP_MOVZ_RIM:		nst_byte_t := x"03";
	constant OP_MOVS_A_I8:		nst_byte_t := x"04";
	constant OP_MOVS_B_I8:		nst_byte_t := x"05";
	constant OP_MOVS_C_I8:		nst_byte_t := x"06";
	constant OP_MOVS_D_I8:		nst_byte_t := x"07";
	constant OP_MOV_A_I16:		nst_byte_t := x"08";
	constant OP_MOV_B_I16:		nst_byte_t := x"09";
	constant OP_MOV_C_I16:		nst_byte_t := x"0A";
	constant OP_MOV_D_I16:		nst_byte_t := x"0B";
	constant OP_MOV_I_I16:		nst_byte_t := x"0C";
	constant OP_MOV_J_I16:		nst_byte_t := x"0D";
	constant OP_MOV_K_I16:		nst_byte_t := x"0E";
	constant OP_MOV_L_I16:		nst_byte_t := x"0F";
	
	constant OP_MOV_A_BI:		nst_byte_t := x"10";
	constant OP_MOV_B_BI:		nst_byte_t := x"11";
	constant OP_MOV_C_BI:		nst_byte_t := x"12";
	constant OP_MOV_D_BI:		nst_byte_t := x"13";
	constant OP_MOV_A_BIO:		nst_byte_t := x"14";
	constant OP_MOV_B_BIO:		nst_byte_t := x"15";
	constant OP_MOV_C_BIO:		nst_byte_t := x"16";
	constant OP_MOV_D_BIO:		nst_byte_t := x"17";
	constant OP_MOV_BI_A:		nst_byte_t := x"18";
	constant OP_MOV_BI_B:		nst_byte_t := x"19";
	constant OP_MOV_BI_C:		nst_byte_t := x"1A";
	constant OP_MOV_BI_D:		nst_byte_t := x"1B";
	constant OP_MOV_BIO_A:		nst_byte_t := x"1C";
	constant OP_MOV_BIO_B:		nst_byte_t := x"1D";
	constant OP_MOV_BIO_C:		nst_byte_t := x"1E";
	constant OP_MOV_BIO_D:		nst_byte_t := x"1F";
	
	constant OP_MOV_A_O:		nst_byte_t := x"20";
	constant OP_MOV_B_O:		nst_byte_t := x"21";
	constant OP_MOV_C_O:		nst_byte_t := x"22";
	constant OP_MOV_D_O:		nst_byte_t := x"23";
	constant OP_MOV_O_A:		nst_byte_t := x"24";
	constant OP_MOV_O_B:		nst_byte_t := x"25";
	constant OP_MOV_O_C:		nst_byte_t := x"26";
	constant OP_MOV_O_D:		nst_byte_t := x"27";
	
	constant OP_MOV_SP_I32:		nst_byte_t := x"28";
	constant OP_MOV_BP_I32:		nst_byte_t := x"29";
	constant OP_MOV_RIM:		nst_byte_t := x"2A";
	constant OP_XCHG_RIM:		nst_byte_t := x"2B";
	
	constant OP_MOV_A_B:		nst_byte_t := x"2C";
	constant OP_MOV_A_C:		nst_byte_t := x"2D";
	constant OP_MOV_A_D:		nst_byte_t := x"2E";
	constant OP_MOV_B_A:		nst_byte_t := x"2F";
	constant OP_MOV_B_C:		nst_byte_t := x"30";
	constant OP_MOV_B_D:		nst_byte_t := x"31";
	constant OP_MOV_C_A:		nst_byte_t := x"32";
	constant OP_MOV_C_B:		nst_byte_t := x"33";
	constant OP_MOV_C_D:		nst_byte_t := x"34";
	constant OP_MOV_D_A:		nst_byte_t := x"35";
	constant OP_MOV_D_B:		nst_byte_t := x"36";
	constant OP_MOV_D_C:		nst_byte_t := x"37";
	
	constant OP_MOV_AL_BL:		nst_byte_t := x"38";
	constant OP_MOV_AL_CL:		nst_byte_t := x"39";
	constant OP_MOV_AL_DL:		nst_byte_t := x"3A";
	constant OP_MOV_BL_AL:		nst_byte_t := x"3B";
	constant OP_MOV_BL_CL:		nst_byte_t := x"3C";
	constant OP_MOV_BL_DL:		nst_byte_t := x"3D";
	constant OP_MOV_CL_AL:		nst_byte_t := x"3E";
	constant OP_MOV_CL_BL:		nst_byte_t := x"3F";
	constant OP_MOV_CL_DL:		nst_byte_t := x"40";
	constant OP_MOV_DL_AL:		nst_byte_t := x"41";
	constant OP_MOV_DL_BL:		nst_byte_t := x"42";
	constant OP_MOV_DL_CL:		nst_byte_t := x"43";
	
	constant OP_PUSH_A:			nst_byte_t := x"44";
	constant OP_PUSH_B:			nst_byte_t := x"45";
	constant OP_PUSH_C:			nst_byte_t := x"46";
	constant OP_PUSH_D:			nst_byte_t := x"47";
	constant OP_PUSH_I:			nst_byte_t := x"48";
	constant OP_PUSH_J:			nst_byte_t := x"49";
	constant OP_PUSH_K:			nst_byte_t := x"4A";
	constant OP_PUSH_L:			nst_byte_t := x"4B";
	constant OP_PUSH_BP:		nst_byte_t := x"4C";
	constant OP_PUSH_F:			nst_byte_t := x"4D";
	constant OP_PUSH_PF:		nst_byte_t := x"4E";
	constant OP_PUSH_RIM:		nst_byte_t := x"4F";
	
	constant OP_PUSH_I32:		nst_byte_t := x"50";
	constant OP_PUSHA:			nst_byte_t := x"51";
	constant OP_POPA:			nst_byte_t := x"52";
	constant OP_UNDEF_53:		nst_byte_t := x"53";
	constant OP_POP_A:			nst_byte_t := x"54";
	constant OP_POP_B:			nst_byte_t := x"55";
	constant OP_POP_C:			nst_byte_t := x"56";
	constant OP_POP_D:			nst_byte_t := x"57";
	constant OP_POP_I:			nst_byte_t := x"58";
	constant OP_POP_J:			nst_byte_t := x"59";
	constant OP_POP_K:			nst_byte_t := x"5A";
	constant OP_POP_L:			nst_byte_t := x"5B";
	constant OP_POP_BP:			nst_byte_t := x"5C";
	constant OP_POP_F:			nst_byte_t := x"5D";
	constant OP_POP_PF:			nst_byte_t := x"5E";
	constant OP_POP_RIM:		nst_byte_t := x"5F";
	
	constant OP_AND_F_RIM:		nst_byte_t := x"60";
	constant OP_AND_RIM_F:		nst_byte_t := x"61";
	constant OP_OR_F_RIM:		nst_byte_t := x"62";
	constant OP_OR_RIM_F:		nst_byte_t := x"63";
	constant OP_XOR_F_RIM:		nst_byte_t := x"64";
	constant OP_XOR_RIM_F:		nst_byte_t := x"65";
	constant OP_NOT_F:			nst_byte_t := x"66";
	constant OP_MOV_F_RIM:		nst_byte_t := x"67";
	constant OP_MOV_RIM_F:		nst_byte_t := x"68";
	constant OP_MOV_PF_RIM:		nst_byte_t := x"69";
	constant OP_MOV_RIM_PF:		nst_byte_t := x"6A";
	constant OP_LEA_RIM:		nst_byte_t := x"6B";
	constant OP_CMP_RIM:		nst_byte_t := x"6C";
	constant OP_CMP_RIM_I8:		nst_byte_t := x"6D";
	constant OP_CMP_RIM_0:		nst_byte_t := x"6E";
	constant OP_HLT:			nst_byte_t := x"6F";
	
	constant OP_ADD_A_I8:		nst_byte_t := x"70";
	constant OP_ADD_B_I8:		nst_byte_t := x"71";
	constant OP_ADD_C_I8:		nst_byte_t := x"72";
	constant OP_ADD_D_I8:		nst_byte_t := x"73";
	constant OP_ADD_A_I16:		nst_byte_t := x"74";
	constant OP_ADD_B_I16:		nst_byte_t := x"75";
	constant OP_ADD_C_I16:		nst_byte_t := x"76";
	constant OP_ADD_D_I16:		nst_byte_t := x"77";
	constant OP_ADC_A_I8:		nst_byte_t := x"78";
	constant OP_ADC_B_I8:		nst_byte_t := x"79";
	constant OP_ADC_C_I8:		nst_byte_t := x"7A";
	constant OP_ADC_D_I8:		nst_byte_t := x"7B";
	constant OP_ADC_A_I16:		nst_byte_t := x"7C";
	constant OP_ADC_B_I16:		nst_byte_t := x"7D";
	constant OP_ADC_C_I16:		nst_byte_t := x"7E";
	constant OP_ADC_D_I16:		nst_byte_t := x"7F";
	
	constant OP_SUB_A_I8:		nst_byte_t := x"80";
	constant OP_SUB_B_I8:		nst_byte_t := x"81";
	constant OP_SUB_C_I8:		nst_byte_t := x"82";
	constant OP_SUB_D_I8:		nst_byte_t := x"83";
	constant OP_SUB_A_I16:		nst_byte_t := x"84";
	constant OP_SUB_B_I16:		nst_byte_t := x"85";
	constant OP_SUB_C_I16:		nst_byte_t := x"86";
	constant OP_SUB_D_I16:		nst_byte_t := x"87";
	constant OP_SBB_A_I8:		nst_byte_t := x"88";
	constant OP_SBB_B_I8:		nst_byte_t := x"89";
	constant OP_SBB_C_I8:		nst_byte_t := x"8A";
	constant OP_SBB_D_I8:		nst_byte_t := x"8B";
	constant OP_SBB_A_I16:		nst_byte_t := x"8C";
	constant OP_SBB_B_I16:		nst_byte_t := x"8D";
	constant OP_SBB_C_I16:		nst_byte_t := x"8E";
	constant OP_SBB_D_I16:		nst_byte_t := x"8F";
	
	constant OP_ADD_RIM:		nst_byte_t := x"90";
	constant OP_ADD_RIM_I8:		nst_byte_t := x"91";
	constant OP_ADC_RIM:		nst_byte_t := x"92";
	constant OP_ADC_RIM_I8:		nst_byte_t := x"93";
	constant OP_PADD_RIM:		nst_byte_t := x"94";
	constant OP_PADC_RIM:		nst_byte_t := x"95";
	constant OP_ADD_SP_I8:		nst_byte_t := x"96";
	constant OP_UNDEF_97:		nst_byte_t := x"97";
	
	constant OP_SUB_RIM:		nst_byte_t := x"98";
	constant OP_SUB_RIM_I8:		nst_byte_t := x"99";
	constant OP_SBB_RIM:		nst_byte_t := x"9A";
	constant OP_SBB_RIM_I8:		nst_byte_t := x"9B";
	constant OP_PSUB_RIM:		nst_byte_t := x"9C";
	constant OP_PSBB_RIM:		nst_byte_t := x"9D";
	constant OP_SUB_SP_I8:		nst_byte_t := x"9E";
	constant OP_UNDEF_9F:		nst_byte_t := x"9F";
	
	constant OP_MUL_RIM:		nst_byte_t := x"A0";
	constant OP_UNDEF_A1:		nst_byte_t := x"A1";
	constant OP_MULH_RIM:		nst_byte_t := x"A2";
	constant OP_MULSH_RIM:		nst_byte_t := x"A3";
	constant OP_PMUL_RIM:		nst_byte_t := x"A4";
	constant OP_UNDEF_A5:		nst_byte_t := x"A5";
	constant OP_PMULH_RIM:		nst_byte_t := x"A6";
	constant OP_PMULSH_RIM:		nst_byte_t := x"A7";
	
	constant OP_DIV_RIM:		nst_byte_t := x"A8";
	constant OP_DIVS_RIM:		nst_byte_t := x"A9";
	constant OP_DIVM_RIM:		nst_byte_t := x"AA";
	constant OP_DIVMS_RIM:		nst_byte_t := x"AB";
	constant OP_PDIV_RIM:		nst_byte_t := x"AC";
	constant OP_PDIVS_RIM:		nst_byte_t := x"AD";
	constant OP_PDIVM_RIM:		nst_byte_t := x"AE";
	constant OP_PDIVMS_RIM:		nst_byte_t := x"AF";
	
	constant OP_INC_I:			nst_byte_t := x"B0";
	constant OP_INC_J:			nst_byte_t := x"B1";
	constant OP_INC_K:			nst_byte_t := x"B2";
	constant OP_INC_L:			nst_byte_t := x"B3";
	constant OP_ICC_I:			nst_byte_t := x"B4";
	constant OP_ICC_J:			nst_byte_t := x"B5";
	constant OP_ICC_K:			nst_byte_t := x"B6";
	constant OP_ICC_L:			nst_byte_t := x"B7";
	constant OP_DEC_I:			nst_byte_t := x"B8";
	constant OP_DEC_J:			nst_byte_t := x"B9";
	constant OP_DEC_K:			nst_byte_t := x"BA";
	constant OP_DEC_L:			nst_byte_t := x"BB";
	constant OP_DCC_I:			nst_byte_t := x"BC";
	constant OP_DCC_J:			nst_byte_t := x"BD";
	constant OP_DCC_K:			nst_byte_t := x"BE";
	constant OP_DCC_L:			nst_byte_t := x"BF";
	
	constant OP_INC_RIM:		nst_byte_t := x"C0";
	constant OP_ICC_RIM:		nst_byte_t := x"C1";
	constant OP_PINC_RIM:		nst_byte_t := x"C2";
	constant OP_PICC_RIM:		nst_byte_t := x"C3";
	constant OP_DEC_RIM:		nst_byte_t := x"C4";
	constant OP_DCC_RIM:		nst_byte_t := x"C5";
	constant OP_PDEC_RIM:		nst_byte_t := x"C6";
	constant OP_PDCC_RIM:		nst_byte_t := x"C7";
	
	constant OP_SHL_RIM:		nst_byte_t := x"C8";
	constant OP_SHR_RIM:		nst_byte_t := x"C9";
	constant OP_SAR_RIM:		nst_byte_t := x"CA";
	constant OP_ROL_RIM:		nst_byte_t := x"CB";
	constant OP_ROR_RIM:		nst_byte_t := x"CC";
	constant OP_RCL_RIM:		nst_byte_t := x"CD";
	constant OP_RCR_RIM:		nst_byte_t := x"CE";
	constant OP_NEG_RIM:		nst_byte_t := x"CF";
	
	constant OP_AND_RIM:		nst_byte_t := x"D0";
	constant OP_OR_RIM:			nst_byte_t := x"D1";
	constant OP_XOR_RIM:		nst_byte_t := x"D2";
	constant OP_NOT_RIM:		nst_byte_t := x"D3";
	
	constant OP_CALL_I8:		nst_byte_t := x"D4";
	constant OP_CALL_I16:		nst_byte_t := x"D5";
	constant OP_CALL_I32:		nst_byte_t := x"D6";
	constant OP_CALL_RIM:		nst_byte_t := x"D7";
	constant OP_CALLA_I32:		nst_byte_t := x"D8";
	constant OP_CALLA_RIM32:	nst_byte_t := x"D9";
	
	constant OP_JMP_I8:			nst_byte_t := x"DA";
	constant OP_JMP_I16:		nst_byte_t := x"DB";
	constant OP_JMP_I32:		nst_byte_t := x"DC";
	constant OP_JMP_RIM:		nst_byte_t := x"DD";
	constant OP_JMPA_I32:		nst_byte_t := x"DE";
	constant OP_JMPA_RIM32:		nst_byte_t := x"DF";
	
	constant OP_RET:			nst_byte_t := x"E0";
	constant OP_IRET:			nst_byte_t := x"E1";
	constant OP_INT_I8:			nst_byte_t := x"E2";
	constant OP_INT_RIM:		nst_byte_t := x"E3";
	
	constant OP_JC_I8:			nst_byte_t := x"E4";
	constant OP_JC_RIM:			nst_byte_t := x"E5";
	constant OP_JNC_I8:			nst_byte_t := x"E6";
	constant OP_JNC_RIM:		nst_byte_t := x"E7";
	constant OP_JS_I8:			nst_byte_t := x"E8";
	constant OP_JS_RIM:			nst_byte_t := x"E9";
	constant OP_JNS_I8:			nst_byte_t := x"EA";
	constant OP_JNS_RIM:		nst_byte_t := x"EB";
	constant OP_JO_I8:			nst_byte_t := x"EC";
	constant OP_JO_RIM:			nst_byte_t := x"ED";
	constant OP_JNO_I8:			nst_byte_t := x"EE";
	constant OP_JNO_RIM:		nst_byte_t := x"EF";
	
	constant OP_JZ_I8:			nst_byte_t := x"F0";
	constant OP_JZ_RIM:			nst_byte_t := x"F1";
	constant OP_JNZ_I8:			nst_byte_t := x"F2";
	constant OP_JNZ_RIM:		nst_byte_t := x"F3";
	constant OP_JA_I8:			nst_byte_t := x"F4";
	constant OP_JA_RIM:			nst_byte_t := x"F5";
	constant OP_JBE_I8:			nst_byte_t := x"F6";
	constant OP_JBE_RIM:		nst_byte_t := x"F7";
	constant OP_JG_I8:			nst_byte_t := x"F8";
	constant OP_JG_RIM:			nst_byte_t := x"F9";
	constant OP_JGE_I8:			nst_byte_t := x"FA";
	constant OP_JGE_RIM:		nst_byte_t := x"FB";
	constant OP_JL_I8:			nst_byte_t := x"FC";
	constant OP_JL_RIM:			nst_byte_t := x"FD";
	constant OP_JLE_I8:			nst_byte_t := x"FE";
	constant OP_JLE_RIM:		nst_byte_t := x"FF";
end nst_constants;