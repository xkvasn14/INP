-- cpu.vhd: Simple 8-bit CPU (BrainF*ck interpreter)
-- Copyright (C) 2020 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): DOPLNIT
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet ROM
   CODE_ADDR : out std_logic_vector(11 downto 0); -- adresa do pameti
   CODE_DATA : in std_logic_vector(7 downto 0);   -- CODE_DATA <- rom[CODE_ADDR] pokud CODE_EN='1'
   CODE_EN   : out std_logic;                     -- povoleni cinnosti
   
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(9 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- ram[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_WE    : out std_logic;                    -- cteni (0) / zapis (1)
   DATA_EN    : out std_logic;                    -- povoleni cinnosti 
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna
   IN_REQ    : out std_logic;                     -- pozadavek na vstup data
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
   OUT_WE   : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

 -- zde dopiste potrebne deklarace signalu

	-- PC

	signal pc_reg : std_logic_vector (11 downto 0);
	signal pc_add : std_logic;
	signal pc_minus : std_logic;
	signal pc_load  : std_logic;
		
	-- PC

	--RAS
	signal ras_reg  : std_logic_vector (11 downto 0);
	signal ras_push : std_logic;
	signal ras_pop  : std_logic;
	signal ras_popAll: std_logic;
	--RAS


	-- PTR

	signal ptr_reg : std_logic_vector (9 downto 0);
	signal ptr_inc : std_logic;
	signal ptr_dec : std_logic;
	signal ptr_load  : std_logic;
		
	-- PTR
	

	-- STATES
	type fsm_state is (
			s_begining,
			s_loadingUp,
			s_decoding,
			s_pc_add_eins,s_pc_add_two,s_pc_add_last,
			s_pc_less_first,s_pc_less_two,s_pc_less_last,
			s_pointer_goRight,
			s_pointer_goLeft,
			s_while_start, s_while_secondStep,s_while_thirdStep,s_while_BeginEnd,
			s_while_end, s_while_end_end, s_while_end_middle, s_while_end_end_end, s_while_endEnd,
			s_null,
			s_write,
			s_write_done,
			s_get,
			s_getCharDone
		);

	signal state : fsm_state := s_begining;
	signal nState : fsm_state;

	-- STATES

	--MUX
	signal mux_selection : std_logic_vector (1 downto 0) := "00";
	signal mux_Output : std_logic_vector (7 downto 0);
	--MUX
begin
	CODE_ADDR <= pc_reg;
	DATA_ADDR <= ptr_reg;
	OUT_DATA <= DATA_RDATA;
--PC--
 	pc: process (CLK, RESET, pc_add, pc_minus, pc_load) is	
	begin
		if RESET = '1' then
			pc_reg <= (others => '0');
		elsif rising_edge(CLK) then
			if pc_add = '1' then
				pc_reg <= pc_reg + 1;
			elsif pc_minus = '1' then
				pc_reg <= pc_reg - 1;
			elsif pc_load = '1' then
				pc_reg <= (others => '0');
			end if;
		end if;
	end process;
--PC--
	
--PTR--
	ptr: process (CLK, RESET, ptr_inc, ptr_dec, ptr_load) is	
	begin
		if RESET = '1' then
			ptr_reg <= (others => '0');
		elsif rising_edge(CLK) then
			if ptr_inc = '1' then
				ptr_reg <= ptr_reg + 1;
			elsif ptr_dec = '1' then
				ptr_reg <= ptr_reg - 1;
			elsif ptr_load = '1' then
				ptr_reg <= (others => '0');
			end if;
		end if;
	end process;
--PTR--


--RAS--
	ras: process (CLK, RESET, ras_push, ras_pop, ras_popAll) is
	begin
		if RESET = '1' then
			ras_reg <= (others => '0');
		elsif rising_edge(CLK) then
			if ras_push = '1' then
				ras_reg <= ras_reg + 1;
			elsif ras_pop = '1' then
				ras_reg <= ras_reg - 1;
			elsif ras_popAll = '1' then
				ras_reg <= (others => '0');
			end if;
		end if;
	end process;
--RAS--
	
--MUX--
	mux: process (CLK, RESET, mux_selection) is
	begin
		if RESET = '1' then
			mux_Output <= (others => '0');
		elsif rising_edge(CLK) then
			case mux_selection is
				when "00" =>
					mux_Output <= IN_DATA;
				when "01" =>
					mux_Output <= DATA_RDATA + 1;
				when "10" =>
					mux_Output <= DATA_RDATA - 1;
				when others =>
					mux_Output <= (others => '0');
			end case;
		end if;
	end process;
	DATA_WDATA <= mux_Output;
--MUX--


--FSM--
	state_logic : process (CLK, RESET, EN) is
	begin
		if RESET = '1' then
			state <= s_begining;
		elsif rising_edge(CLK) then
			if EN = '1' then
				state <= nState;
			end if;
		end if;
	end process;


	fsm: process (state, OUT_BUSY,ras_reg, IN_VLD, CODE_DATA, DATA_RDATA) is
	begin
		-- inicializace
		pc_add <= '0';
		pc_minus <= '0';
		pc_load <= '0';
		ras_push <= '0';
		ras_pop <= '0';
		ras_popAll <= '0';
		ptr_inc <= '0';
		ptr_dec <= '0';
		ptr_load <= '0';

		CODE_EN <= '0';
		DATA_EN <= '0';
		DATA_WE <= '0';
		IN_REQ <= '0';
		OUT_WE <= '0';
		
		mux_selection <= "00";

		case state is
			when s_begining =>
				pc_load <= '1';
				ptr_load <= '1';
				ras_popAll <= '1';
				nState <= s_loadingUp;
			when s_loadingUp =>
				CODE_EN <= '1';
				nState <= s_decoding;
			when s_decoding =>
				case CODE_DATA is
					when X"00" =>
						nState <= s_null;
					when X"5D" =>
						nState <= s_while_end;
					when X"2E" =>
						nState <= s_write;
					when X"2D" =>
						nState <= s_pc_less_first;
					when X"3C" =>
						nState <= s_pointer_goLeft;
					when X"3E" =>
						nState <= s_pointer_goRight;
					when X"2B" =>
						nState <= s_pc_add_eins;
					when X"2C" =>
						nState <= s_get;
					when X"5B" =>
						nState <= s_while_start;
					when others =>
						pc_add <= '1';
						nState <= s_loadingUp;
				end case;

			when s_pc_less_first =>
				DATA_EN <= '1';
				DATA_WE <= '0';
				nState <= s_pc_less_two;

			when s_pc_less_two =>
				mux_selection <= "10";
				nState <= s_pc_less_last;

			when s_pc_less_last =>
				DATA_EN <= '1';
				DATA_WE <= '1';
				pc_add <= '1';
				nState <= s_loadingUp;

			when s_pointer_goRight =>
				ptr_inc <= '1';
				pc_add <= '1';
				nState <= s_loadingUp;

			
			when s_pc_add_eins =>
				DATA_EN <= '1';
				DATA_WE <= '0';
				nState <= s_pc_add_two;
			
			when s_pc_add_two =>
				mux_selection <= "01";
				nState <= s_pc_add_last;

			when s_pc_add_last =>
				DATA_EN <= '1';
				DATA_WE <= '1';
				pc_add <= '1';
				nState <= s_loadingUp;

			when s_pointer_goLeft =>
				ptr_dec <= '1';
				pc_add <= '1';
				nState <= s_loadingUp;

		------------------------------------------------------------------

			when s_while_secondStep =>
				if DATA_RDATA /= "00000000" then
					nState <= s_loadingUp;
				else
					ras_push <= '1';
					CODE_EN <= '1';
					nState <= s_while_thirdStep;
				end if;

			when s_while_BeginEnd =>
				CODE_EN <= '1';
				nState <= s_while_thirdStep;
	

			when s_while_thirdStep =>
				if ras_reg /= "000000000000" then
					nState <= s_loadingUp;
				else
					if CODE_DATA = X"5B" then
						ras_push <= '1';
       					elsif CODE_DATA = X"5D" then
						ras_pop <= '1';
					end if;
				end if;

				pc_add <= '1';
				nState <= s_while_BeginEnd;

			when s_while_start =>
				pc_add <= '1';
				DATA_EN <= '1';
				DATA_WE <= '0';
				nState <= s_while_secondStep;

		---------------------------------------------------------

			when s_while_end_end_end =>
				if ras_reg = "000000000000" then
					pc_add <= '1';
				else
					pc_minus <= '1';
				end if;
				nState <= s_while_endEnd;

			when s_while_end =>
				DATA_EN <= '1';
				DATA_WE <= '0';
				nState <= s_while_end_end;

			when s_while_end_end =>
				if DATA_RDATA = "00000000" then
					pc_add <= '1';
					nState <= s_loadingUp;
				else
					ras_push <= '1';
					pc_minus <= '1';
					nState <= s_while_endEnd;
				end if;

			when s_while_endEnd =>
				CODE_EN <= '1';
				nState <= s_while_end_middle;

			when s_while_end_middle =>
				if ras_reg = "000000000000" then
					nState <= s_loadingUp;
				else
					if CODE_DATA = X"5D" then
						ras_push <= '1';
					elsif CODE_DATA = X"5B" then
						ras_pop <= '1';
					end if;
					nState <= s_while_end_end_end;
				end if;
			
		---------------------------------------------------------------------

			when s_getCharDone =>
				if IN_VLD /= '1' then
					IN_REQ <= '1';
					mux_selection <= "00";
					nState <= s_getCharDone;
				else
					DATA_EN <= '1';
					DATA_WE <= '1';
					pc_add <= '1';
					nState <= s_loadingUp;
				end if;

			when s_get =>
				IN_REQ <= '1';
				mux_selection <= "00";
				nState <= s_getCharDone;

		----------------------------------------------------------------------	

			when s_write_done =>
				if OUT_BUSY = '1' then
					DATA_EN <= '1';
					DATA_WE <= '0';
					nState <= s_write_done;
				else
					OUT_WE <= '1';
					pc_add <= '1';
					nState <= s_loadingUp;
				end if;

			when s_write =>
				DATA_EN <= '1';
				DATA_WE <= '0';
				nState <= s_write_done;

		----------------------------------------------------------------------	
			when s_null =>
				nState <= s_null;
			when others =>
				null;

		end case;	
				

			
	end process;

--FSM--





	
end behavioral;
 
