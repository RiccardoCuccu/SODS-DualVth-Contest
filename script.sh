#!/bin/bash

cd ./WORK_SYNTHESIS

# Run Synopsys DC-Compiler #
#dc_shell-xg-t -f ./scripts/synthesis.tcl

cd ./saved/c1908/post_synthesis_sim
cp ../synthesis/c1908_postsyn.v .
vsim &

# Run Synopsys PrimeTime-PX #
#pt_shell -f ./scripts/pt_analysis.tcl

cd ../../../..
#pt_shell -f ./dualVth.tcl
rm -f *.log