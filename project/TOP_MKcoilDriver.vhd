--
--
-- [TOP level design entity]
-- 	ESM-34402 Marker Coil Driver unit 
--		PC-Board Number : DR20000110-06  
--								WITHOUT ReTHM functionality
--		Based on 
--			MKcoilDriver 
--			RELEASE2_1 2014/10/09 M.Miyamoto
--
--		REV: 1.0
--			2021/7/3 M.Miyamoto
--			branch :debug_#1 -> merge to main 
--          
--          branch :refactoring_#3 -> marge to main
--          operability confirmed
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


entity top is
	-- determine counter width and max count for 
	--   the wave counter and burst counter

	generic (
		WAVE_CNT_WIDTH : 	integer :=5;
		BURST_CNT_WIDTH :	integer :=3;
		WAVE_COUNT_UPPER_LIM : 	integer :=24;	-- 25-ary counter
		BURST_COUNT_UPPER_LIM : integer :=5;	-- 6-ary counter
		RETHM_FUNCTION_ACTIVATE: boolean := False -- flag for activate ReTHM functionality
	);

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
						--		0	:	ON
						--		1	:	OFF (not really turn off the power, only turn off the output signals)
					
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

		nSYNC, ALM_LOW_BAT	:	out std_logic
						--	nSYNC	: sync signal for MEG system
						--		Activated in 80Hz Mode
						--    Always ON in ReTHM Mode (!!Changed RELEASE2_1!!)
						--		Inactivated in  Power OFF mode
						--			to reduce magnetic noise generated from SYNC signal
						--			transmitted via OPT Data link.
						--
						-- ALM_LOW_BAT	: Low battely alarm ouput
						--		0	:	Normal
						--		1	:	Battery LOW
		);



end top;


architecture Behavioral of top is

    signal	WAVE_CNT:	integer range 0 to WAVE_COUNT_UPPER_LIM;
    signal	BURST_CNT:	integer range 0 to BURST_COUNT_UPPER_LIM;
    
    signal	WAVE_EQ_0, WAVE_SYNC, WAVE_CNT_CARRY: std_logic;
    signal  BLOCK_SYNC, BLOCK_MASK:	std_logic;
    
    signal	SYS_ENABLE, RETHM_ENABLE, MUX_80HZ_DISABLE: std_logic;
    
begin
    
    Process (CLK,nPOWER_ON) begin 
        if ( falling_edge(CLK) ) then
            SYS_ENABLE <= not(nPOWER_ON);
        end if;
    end Process;

--  wave counter
--
--	INPUT: CLK nPOWER_ON
-- 	OUTPUT:	WAVE_CNT, WAVE_EQ_0, WAVE_SYNC, WAVE_CNT_CARRY


    wave_counter: Process (CLK,SYS_ENABLE) begin
        if ( SYS_ENABLE = '0' ) then 
            WAVE_CNT	<=	WAVE_COUNT_UPPER_LIM;
            WAVE_CNT_CARRY <= '0';
        elsif ( rising_edge(CLK) ) then
            if ( WAVE_CNT = WAVE_COUNT_UPPER_LIM ) then
                WAVE_CNT	    <= 0;
                WAVE_CNT_CARRY  <= '1';
            else
                WAVE_CNT	    <=	WAVE_CNT + 1;
                WAVE_CNT_CARRY  <= '0';
            end if;
        end if;
    end process; -- wave_conter

    WAVE_EQ_0 <= WAVE_CNT_CARRY;
        
    generate_waveSync: Process (WAVE_CNT) begin
        if ( WAVE_CNT = 1 ) then
            WAVE_SYNC 	<= '1';
        else 
            WAVE_SYNC	<=	'0';
        end if;
    end process; -- genarate_waveSync

-- Burst Counter 
-- 
--	INPUT: WAVE_CNT_CARRY, SYS_ENABLE
-- 	OUTPUT:	BURST_CNT, BLOCK_SYNC, BLOCK_MASK


    burst_counter: Process (WAVE_CNT_CARRY, SYS_ENABLE) begin
        if (SYS_ENABLE='0') then 
            BURST_CNT	<=	BURST_COUNT_UPPER_LIM ;
        elsif ( rising_edge(WAVE_CNT_CARRY) ) then
            if (BURST_CNT = BURST_COUNT_UPPER_LIM) then		
                BURST_CNT <= 0;
            else
                BURST_CNT <= BURST_CNT + 1;
            end if;
        end if;
    end process; --burst_counter

    generate_blockSync: Process (BURST_CNT) begin
        if ( BURST_CNT = 0 ) then
            BLOCK_SYNC 	<= 	'1';
        else 
            BLOCK_SYNC	<=	'0';
        end if;
    end process; -- genarate_burstSync

    generate_blockMask: Process (BURST_CNT) begin
        if ( BURST_CNT = BURST_COUNT_UPPER_LIM ) then
            BLOCK_MASK 	<=  '1';
        else 
            BLOCK_MASK	<=	'0';
        end if;
    end process;-- generate_blockMask
--	
--	Changing the output channel
--						
--			To avoid gridge on the output, Change the channel at the time when
--			the output is disabled.
                            
    mux_ctrl: Process (CLK, WAVE_EQ_0 ) begin
        if ( falling_edge(CLK) and WAVE_EQ_0='1') then
            CH	<= std_logic_vector( to_unsigned(BURST_CNT, BURST_CNT_WIDTH));
        end if;
    end process;-- mux_ctrl
--	
--	ReTHM Ctrl
--	    Generate ReTHM OSC ctrl ckt based on the status of RETHM_FUNCTION_ACTIVATE			
--		
    rethm_ctrl : if (RETHM_FUNCTION_ACTIVATE) generate
        process( SYS_ENABLE, BLOCK_MASK, RMT_80_nRETHM ) begin
            if (SYS_ENABLE = '0') then
                RETHM_ENABLE <= '0';
            elsif ( rising_edge(BLOCK_MASK) ) then
                RETHM_ENABLE <= not(RMT_80_nRETHM);
            end if;
        end process ; -- rethm_ctrl
    end generate;

    rethm_disable : if (not(RETHM_FUNCTION_ACTIVATE)) generate
        RETHM_ENABLE <='0';
    end generate;

-- power off ReTHM OSC and disable MUX for ReTHM signal
    nRETHM_OE	<= not(RETHM_ENABLE);
    RETHM_POWER	<= RETHM_ENABLE;
    
-- Activate nSYNC(active Low) signal , disabled in ReTHM mode
--
    sync_gen : process(RETHM_ENABLE, WAVE_SYNC, BLOCK_SYNC, SYS_ENABLE) begin
        if (RETHM_ENABLE = '0') then 
            nSYNC <= not(WAVE_SYNC and BLOCK_SYNC and SYS_ENABLE);  
        else 
            nSYNC <= '0';
        end if; 
    end process sync_gen;

    
--  disable output when wave counter = 0 or burst conter = 5 or OFF state (SYS_ENABLE:negate)
    n80_OE <= MUX_80HZ_DISABLE;
    MUX_80HZ_DISABLE <= WAVE_EQ_0 or BLOCK_MASK or not(SYS_ENABLE and not(RETHM_ENABLE));

    AMP(0)	<=	SW_AMP_x10_x1;
    AMP(1)	<=	SW_AMP_x10_x1;
    ZOUT	<=	SW_ZO_10k_100k;
    
    -- Always enable CLK
    CMP_80	<=	'1';

    ALM_LOW_BAT <= '1';
        
end Behavioral;
