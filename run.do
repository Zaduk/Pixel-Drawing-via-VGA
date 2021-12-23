vlib work
vlog fsm.v
vsim fsm
log {/*}
add wave -r {/*}

#create clock
force {CLOCK_50} 0 0ns, 1 {2ns} -r 5ns;


force {KEY[0]} 0;
force {KEY[1]} 1;
force {KEY[2]} 1;
force {KEY[3]} 1;
force {SW[6]} 0;
force {SW[5]} 0;
force {SW[4]} 0;
force {SW[3]} 0;
force {SW[2]} 0;
force {SW[1]} 0;
force {SW[0]} 0;

force {SW[9]} 0;
force {SW[8]} 0;
force {SW[7]} 0;
run 10ns
force {KEY[0]} 1;
run 10ns
force {KEY[0]} 1;
force {SW[6]} 1;
force {SW[5]} 1;
force {SW[4]} 0;
force {SW[3]} 0;
force {SW[2]} 1;
force {SW[1]} 0;
force {SW[0]} 0;

force {SW[9]} 1;
force {SW[8]} 1;
force {SW[7]} 0;
run 10000ns
force {KEY[3]} 0;
run 10000ns
force {KEY[3]} 1;
run 100ns
force {KEY[1]} 0;
run 100000ns
force {KEY[1]} 1;
run 1000000ns
force {SW[6]} 0;
force {SW[5]} 1;
force {SW[4]} 1;
force {SW[3]} 0;
force {SW[2]} 0;
force {SW[1]} 1;
force {SW[0]} 0;
run 100ns
force {KEY[3]} 0;
run 10000ns
force {KEY[3]} 1;
run 100ns
force {KEY[1]} 0;
run 100000ns
force {KEY[1]} 1;
run 100000ns
force {KEY[2]} 0;
run 100000ns
force {KEY[2]} 1;
run 192400ns