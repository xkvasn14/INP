library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

-- rozhrani Vigenerovy sifry
entity vigenere is
   port(
         CLK : in std_logic;
         RST : in std_logic;
         DATA : in std_logic_vector(7 downto 0);
         KEY : in std_logic_vector(7 downto 0);

         CODE : out std_logic_vector(7 downto 0)
    );
end vigenere;


architecture behavioral of vigenere is

signal mov: std_logic_vector(7 downto 0);
signal addCorrect: std_logic_vector(7 downto 0);
signal removeCorrect: std_logic_vector(7 downto 0);

type tState is (add, remove);
signal state: tState := add;
signal nextState:  tState := remove;


signal fsmOut: std_logic_vector (1 downto 0);

signal hashtag: std_logic_vector (7 downto 0) := "00100011";



begin




stateLogic: process (CLK, RST) is
begin
if(RST = '1') then
	state <= add;
elsif rising_edge(CLK) then
	state <= nextState;

end if;
end process;




fsm_mealy: process (state, DATA, RST) is
begin


if state = add then
	nextState <= remove;
	fsmOut <= "01";
elsif state = remove then
	nextState <= add;
	fsmOut <= "10";
end if;


if(DATA > 47 and DATA < 58) then
	fsmOut <= "00";
end if;

if(RST = '1') then
	fsmOut <= "00";
end if;

end process;



mux: process (fsmOut,removeCorrect,addCorrect) is
begin
if (fsmOut = "01")  then
	CODE <= addCorrect;
elsif  (fsmOut = "10")  then
	CODE <= removeCorrect;
else
	CODE <= hashtag;
end if;

end process;






movProcess: process (DATA, KEY) is
begin
mov <= KEY - 64;

end process;

addProcesss: process (mov, DATA) is
	variable tmp: std_logic_vector (7 downto 0);
begin
tmp := DATA;
tmp := tmp + mov;
if(tmp > 90) then
	tmp := tmp - 26;
end if;

addCorrect <= tmp;
end process;



removeProcess: process (mov, DATA) is
	variable tmp: std_logic_vector (7 downto 0);
begin
tmp := DATA;
tmp := tmp - mov;
if(tmp < 65) then
	tmp := tmp + 26;
end if;

removeCorrect <= tmp;
end process;

end behavioral;
