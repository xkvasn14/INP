proc isim_script {} {

   add_divider "Signals of the Vigenere Interface"
   add_wave_label "" "CLK" /testbench/clk
   add_wave_label "" "RST" /testbench/rst
   add_wave_label "-radix ascii" "DATA" /testbench/tb_data
   add_wave_label "-radix ascii" "KEY" /testbench/tb_key
   add_wave_label "-radix ascii" "CODE" /testbench/tb_code

   add_divider "Vigenere Inner Signals"
   add_wave_label "" "state" /testbench/uut/state
   # sem doplnte vase vnitrni signaly. chcete-li v diagramu zobrazit desitkove
   # cislo, vlozte do prvnich uvozovek: -radix dec
	add_wave_label "-radix unsigned"  "MOV" /testbench/uut/mov
	add_wave_label "-radix ascii"  "ADD" /testbench/uut/addCorrect
	add_wave_label "-radix ascii"  "REMOVE" /testbench/uut/removeCorrect

	add_wave_label ""  "STATE" /testbench/uut/state
	add_wave_label ""  "NEXTSTATE" /testbench/uut/nextState
	
	add_wave_label "" "FSM_OUT" /testbench/uut/fsmout
	
   run 8 ns
}
