# SODS-DualVth-Contest
Assignment of the "Synthesis and Optimization of Digital Systems" course of the master degree in Embedded System (Electronic Engineering) of Politecnico di Torino, academic year 2017/2018.

## Description
Write a plug-in for PrimeTime that implements a post-synthesis power minimization procedure. The new command, written in TCL, runs a leakage-constrained Dual-Vth cell assignment s.t. slack penalties are minimized.
The only input argument consists of the leakage savings to be reached after the assignment process; it is measured as follows:

<p align="center">
<img src=
"https://render.githubusercontent.com/render/math?math=%5Cdisplaystyle+%5Cbegin%7Balign%2A%7D%0Asavings+%3D+%5Cfrac%7Bstart%5C_power+-+end%5C_power%7D%7Bstart%5C_power%7D%0A%5Cend%7Balign%2A%7D%0A" 
alt="\begin{align*}
savings = \frac{start\_power - end\_power}{start\_power}
\end{align*}
">

Allowed input values may range from 0 (no leakage minimization) to 1 (maximum leakage savings).

Note: logic gates must keep the same cell footprint during the optimization loop, i.e. same size and area

### SYNOPSIS
```
dualVth –leakage $savings$
```
### EXAMPLE
```
dualVth –leakage 0.5 ;#50% of leakage savings w.r.t. the loaded design
```

### Evaluation Metrics
The following metrics will be used for evaluation:
1. compliance to input constraints, i.e. leakage savings and cell footprint
2. slack penalty due to leakage minimization, i.e., difference between the original circuit slack and the slack after leakage optimization
3. execution time, i.e. difference between start-time and end-time (using the tcl clock command)

The best algorithm is the one that matches the leakage savings constraint while reaching the smallest slack
penalty using the lowest amount of CPU time.
### Basic Rules for the Competition
1. Combinational circuits used as benchmarks: {`c1908.v`,`c5315.v`} Note: the algorithm must be general and will be tested on other benchmarks, too.
2. The command will be executed under PrimeTime, just after the script `pt_analysis.tcl`
3. The benchmark is first synthesized under a fixed timing constraint (e.g., `clockPeriod` = 3.0 ns) using the `synthesis.tcl` with single-VT target library, the `CORE65_LP_LVT`.
4. All the groups are invited (mandatory) to use the template available on the webpage of the course. Other additional procedures can be used only if invoked within the `dualVth` procedure.
  
[//]: # (https://tex-image-link-generator.herokuapp.com/)
