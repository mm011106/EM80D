-- TOP level design entity for Marker Coil Driver unit REV01
--		DR20000110-01 
--		with ReTHM functionality
--    
-- 						
--					V2.0 2014/09/10 M.Miyamoto
--						branched from V1.0
--
--					RELEASE2_0 2014/09/11 M.Miyamoto
--						Modified based on the DR20000110-01 Circuit diagram.
--						And checked.
--
--					RELEASE2_1 2014/10/09 M.Miyamoto
--						Activate FLAME_SYNC anytime in ReTHM mode(in case RMT_80_nRETHM=0).
--						And checked.


library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity top is
	port	(	
		-- Analog part control IO
		CLK: 	in	std_logic;
						-- CLK input around 80Hz. Output of the anaolg OSC.
																								
		AMP:	out std_logic_vector(1 downto 0);
						-- signal amplitude ctrl 
						--		00 x1 	0.5Vo-p
						--		01	x1		0.5Vo-p
						--		10	x1		0.5Vo-p
						--		11	x2		1.0Vo-p
										
		CH	:	out std_logic_vector(2 downto 0);
						--  Output channel select
						--  only 0-4 is available (5ch)
						
		ZOUT:	out std_logic;
						-- ZOUT: Z out select
						--		0	:	100kohm
						--		1	:	10kohm
										
		nRETHM_OE, n80_OE:	out std_logic;
						-- nRETHM_OE: Activate ReTHM signal
						--		0	:	Active
						--		1	:	Negate
						
						-- n80_OE: Activate 80Hz signal
						--		0	:	Active
						--		1	:	Negate
										
		CMP_80, RETHM_POWER:	out std_logic;
						-- CMP_80: Activate 80Hz comparator
						--		0	:	Negate
						--		1	:	Active
					
						-- RETHM_POWER: Activate ReTHM OSC circuit
						--		0	:	Negate
						--		1	:	Active
									
		--	Remote Control input
		RMT_80_nRETHM,	nPOWER_ON:	in std_logic;
						-- RMT_80_nRETHM: Ctrl OSC mode between 80Hz and ReTHM OSC
						--		0	:	ReTHM
						--		1	:	80Hz
						
						-- nPOWER_ON: POWER CTRL
						--		0	:	OFF (not really turn off the power, only turn off the output signals)
						--		1	:	ON
					
		--	SYNC inputs
		RETHM_F0, RETHM_F1, RETHM_F2, RETHM_F3, RETHM_F4:	in std_logic;
						-- SYNC input for ReTHM OSC

		-- Sw inputs
		SW_80_nRETHM, SW_ZO_10k_100k,	SW_AMP_x10_x1,	SW_OPTION:	in std_logic;
						--	SW_80_nRETHM: Control 80Hz Mode/ReTHM mode
						--			This switch is ignored on this version
						--			Always in 80Hz mode
						
						--	SW_ZO_10k_100k	: Control output imepdance
						--		0	:	100kohm
						--		1	:	10kohm

						--	SW_AMP_x10_x1	: Control output amplitude
						--		0	x1 	0.1Vo-p
						--		1	x10	1.0Vo-p
						
						--	SW_OPTION	: OPTIONAL sw (unused)

		-- Interface signals
		nLOW_BATT	:	in std_logic;
										
						--	nLOW_BATT	: Warning of low battery
						--		0	:	Battery LOW
						--		1	:	Normal

		FLAME_SYNC, ALM_LOW_BAT	:	out std_logic
						--	FLAME_SYNC	: sync signal for MEG system
						--		Activated in 80Hz Mode
						--    Always ON in ReTHM Mode (!!Changed RELEASE2_1!!)
						--		Inactivated in  Power OFF mode
						--			to reduce magnetic noise generated from FRAME_SYNC signal
						--			transmitted via OPT Data link.
						--
						-- ALM_LOW_BAT	: Low battely alarm ouput
						--		0	:	Normal
						--		1	:	Battery LOW
		);
end top;


architecture Behavioral of top is

signal	Q5_INT:	std_logic_vector(4 downto 0);
signal	Q3_INT:	std_logic_vector(2 downto 0);
signal	CH_SYNC, BLOCK_SYNC, BLOCK_MUSK, BURST_SYNC, OUTPUT_INH:	std_logic;

begin
		
--		Counter for slecting output channels 
--
--

-- MOD 24 counter
--
--  Counts No. of waves comes out from each channel.
--
--     activate CH_SYNC signal when the MOD24 counter = 0
 
	Process (CLK,nPOWER_ON) begin
		if (nPOWER_ON='1') then 
			Q5_INT	<=	"11000";
			OUTPUT_INH	<= '1';
		elsif (CLK'event and CLK='1') then
			OUTPUT_INH	<=	'0';
			if (Q5_int="11000") then
				Q5_int	<= "00000";
				CH_SYNC 	<= '1';
			else
				Q5_INT	<=	Q5_INT+'1';
				CH_SYNC 	<= '0';
			end if;
		end if;
	end process;
	
	Process (Q5_INT, BURST_SYNC) begin
		if (Q5_INT = "00001") then
			BURST_SYNC 	<= '1';
		else 
			BURST_SYNC	<=	'0';
		end if;
	end process;

-- Mod 5 counter 
-- 
-- Counts output channels
--
--

	Process (CH_SYNC, nPOWER_ON) begin
		if (nPOWER_ON='1') then 
			Q3_INT	<=	"101";
		elsif (CH_SYNC'event and CH_SYNC='1') then
			if (Q3_int="101") then		
				Q3_int	<= "000";
				BLOCK_SYNC <= '1';
			else
				Q3_INT	<=	Q3_INT+'1';
				BLOCK_SYNC	<= '0';
			end if;
		end if;
	end process;

	Process (Q3_INT, BLOCK_MUSK) begin
		if (Q3_INT = "101") then
			BLOCK_MUSK 	<= '1';
		else 
			BLOCK_MUSK	<=	'0';
		end if;
	end process;
--	
--	Changing the output channel
--						
--			To avoid gridge on the output, Change the channel at the time when
--			the output is disabled.
							
	Process (CLK, CH_SYNC) begin
		if (CLK'event and CLK='0' and CH_SYNC='1') then
			CH	<= Q3_INT;
		end if;
	end process;
	
	
	-- Activate FLAME_SYNC signal when ch counter = 0 	
	--   and desabled when ReTHM function activated
	--
	FLAME_SYNC <= not(BURST_SYNC and BLOCK_SYNC) and RMT_80_nRETHM;
	
	AMP(0)	<=	SW_AMP_x10_x1;
	AMP(1)	<=	SW_AMP_x10_x1;
	ZOUT		<=	SW_ZO_10k_100k;
	
	--  disable output when wave counter = 0 or channel conter = 5 or POWER OFF state (OUTPUT_INH = '1') or ReTHM mode
	n80_OE	<=	CH_SYNC or BLOCK_MUSK or OUTPUT_INH or (not(RMT_80_nRETHM));
	CMP_80	<=	not(nPOWER_ON) and (RMT_80_nRETHM);
	
	
	nRETHM_OE	<= not( not(RMT_80_nRETHM) and (not(OUTPUT_INH)));
	RETHM_POWER	<=	( not(RMT_80_nRETHM) and (not(OUTPUT_INH)));
	
end Behavioral;
