proc dualVth {args} {
	parse_proc_arguments -args $args results
	set savings $results(-savings)

	#################################
	### INSERT YOUR COMMANDS HERE ###
	#################################

	# SUPPRESS WARNING MESSAGES
	suppress_message NED-045
	suppress_message LNK-041
	suppress_message PWR-601
	suppress_message PWR-246
	suppress_message PTE-018
	suppress_message UIAT-4

	set time [clock microseconds]

	global leak_LL
	global leak_LH
	global end_power
	global delta_LL
	global delta_LH

	if {$savings == 0.0} {
		puts "Design doesn't need optimization"
		return
	}

	if {$savings >= 1.0} {
		swap [get_cells] LH 
		puts "Leakage Power cannot be 0, the maximum achievable is [get_attribute [get_design] leakage_power]"
		return
	}

	if {$savings < 0.0} {
		puts "Savings parameter must be positive"
		return
	}

	init $savings
	#puts  "init done"

	if {$end_power < $leak_LH} { 
	puts "Required savings exceed the maximum achievable: [get_attribute [get_design] leakage_power]"
	return
	} 

	puts "Begin optimization..."

	if {$delta_LL < $delta_LH} { 
		set gorb 1
	} else {
		set gorb 0
	}


	if {$gorb == 1} {
		#puts  "gorb 1"
		swap [get_cells] LL	

		#set t 0.0 ; #to be defined better
		set c  [get_attribute [get_clock] period]
		set t  [expr $c/2]
		set dt [expr $c/4]

		set nw 1
		set finish false

		while { $finish == false} {

			set gcmatrix_arrival [ggc $t $nw]
			set matrix [lindex $gcmatrix_arrival 0]
			set arrival [lindex $gcmatrix_arrival 1]
			#puts  "ggc done"

			set undo [lindex $matrix 0]
			#puts "undo first item setted correctly : $undo"
			foreach p $matrix { ;# creare una collezione unica e darla in pasto a swap
				set undo [add_to_collection $undo $p -unique]
			}

			#puts "undo setted correctly : $undo"
			#set $undo [filter_collection $undo "swapped_preliminary == false"]
			swap $undo LH 

			if {$end_power > [get_attribute [get_design] leakage_power] } { 
			#puts  "Serve l'euristica"
			
			
			swap $undo LL 
			
			cm $matrix
			#puts  "cm done direct"

			set mult [expr [sizeof_collection  [get_attribute [ get_timing_paths] points ]] >> 3 ]
			if { $mult == 0 } {
				set mult 1
			}
			#puts "mult: $mult"

			shd $matrix $arrival $end_power $mult

			puts "Optimization completed"
			puts "Leakage power: [get_attribute [get_design] leakage_power]"
			puts "Slack: [lindex [get_attribute [get_attribute [get_timing_paths] points] slack] 0]"
			set finish true

			} else {
				set t [expr  $t - $dt]
				if {[sizeof_collection $undo] > 0} {
					incr nw 2
				}
				
				#set_user_attribute $undo swapped_preliminary true -quiet
				#set nw [expr $nw<<1] ######################################## ziooooooo crescilo più piano come l'altro
				#if {$nw >= 64} { set $t [expr  $t - 0.5] }
				#puts "nw: $nw, slack $t"
			}
		}
	} else {
		#puts  "gorb 0"

		set t 0.0 ; 
		set c  [get_attribute [get_clock] period]
		set dt [expr $c/4]

		set nw 1
		set finish false

		while { $finish == false} {

			set bcmatrix_arrival [gbc $t $nw]
			set matrix [lindex $bcmatrix_arrival 0]
			set arrival [lindex $bcmatrix_arrival 1]
			#puts  "gbc done"

			set undo [lindex $matrix 0]
			#puts "undo first item setted correctly : $undo"
			foreach p $matrix { ;# creare una collezione unica e darla in pasto a swap
				set undo [add_to_collection $undo $p -unique]
			}
			#puts "undo setted correctly : $undo"
			#set $undo [filter_collection $undo "swapped_preliminary == false"]
			swap $undo LL


			if {$end_power < [get_attribute [get_design] leakage_power] } { 
			#puts  "Serve l'euristica"

			swap $undo LH
			
			set n_max [ cm $matrix ]
			#puts  "cm done reverse"

			set mult [expr [sizeof_collection  [get_attribute [ get_timing_paths] points ]] >> 3 ]
			if { $mult == 0 } {
				set mult 1
			}
			#puts "mult: $mult"

			shr $matrix $arrival $end_power $n_max $mult

			puts "Optimization completed"
			puts "Leakage power: [get_attribute [get_design] leakage_power]"
			puts "Slack: [lindex [get_attribute [get_attribute [get_timing_paths] points] slack] 0]"
			set finish true

			} else {
				#set nw [expr $nw<<1]

				#incr nw 2
				set t [expr $t + $dt]
				if {[sizeof_collection $undo] > 0} {
					incr nw 2
				}
				#set_user_attribute $undo swapped_preliminary true -quiet

				#incr nw 10
				#if {$nw >= 20} { set t [expr $t + 0.5] }
				#puts "nw: $nw, t $t"
			}

		}
	}




		#puts  "END"
		#puts "[clock microseconds] - $time = [expr [clock microseconds] - $time]"
		return
}

define_proc_attributes dualVth \
-info "Post-Synthesis Dual-Vth cell assignment" \
-define_args \
{
	{-savings "minimum % of leakage savings in range [0, 1]" lvt float required}
}


proc init { s } {
############################################
#################### INIT ##################
############################################

define_user_attribute PL_LL -class cell -type double
define_user_attribute PL_LH -class cell -type double
define_user_attribute N -class cell -type int 
define_user_attribute dP -class cell -type double
define_user_attribute swapped -class cell -type boolean
#define_user_attribute swapped_preliminary -class cell -type boolean

set_user_attribute [get_cells] N 0 -quiet
set_user_attribute [get_cells] dP 0.0 -quiet
set_user_attribute [get_cells] swapped false -quiet
#set_user_attribute [get_cells] swapped_preliminary false -quiet


global leak_LL
global leak_LH
global end_power
global delta_LL
global delta_LH

set leak_LL [get_attribute [get_design] leakage_power] ;  # 6.58308e-07

foreach_in_collection cell [get_cells] {
	set leakp [get_attribute $cell leakage_power]
	set_user_attribute $cell PL_LL $leakp -quiet
}

swap [get_cells] LH

set leak_LH [get_attribute [get_design] leakage_power]  ;  #2.13187e-09

foreach_in_collection cell [get_cells] {
	set leakp [get_attribute $cell leakage_power]
	set_user_attribute $cell PL_LH $leakp -quiet
}


set end_power [expr (1.0 - $s )*$leak_LL]

set delta_LH [expr $end_power - $leak_LH]
set delta_LL [expr $leak_LL - $end_power]
 

return

}

proc swap { cells  v } {
############################################
################## SWAP ####################
############################################

set new_gates ""

foreach_in_collection cell $cells {
	set old_cell_name [get_attribute $cell ref_name]	

	set alt [get_alternative_lib_cells $cell]
	set alt_name [get_attribute $alt full_name]

	#set s1  [string range $name 0  [string first _  $name]]
	set sample  [string range $old_cell_name  [string last _ $old_cell_name] end]
	#lappend  new_gate_name "$s1$v$s2"
	
	set h [string match  "*L?S_*"  $old_cell_name]

	if { $h == 1 } { 
		set s "S"
		set srch [lsearch $alt_name *$v$s$sample]
		if {$srch != -1} {
			set  new_gate [lindex $alt_name $srch]
			size_cell $cell $new_gate
		}
	 } else {
		set srch [lsearch $alt_name *$v$sample]
		if {$srch != -1} {
	 		set  new_gate [lindex $alt_name $srch ]
			size_cell $cell $new_gate
		}
	 }

	#lappend new_gates $new_gate
	
	#size_cell $cell $new_gate 
}
return
#return $new_gates
}


proc ggc { t nw } {
############################################
#################### GGC ###################
############################################

#GET BAD CELLS TO REMOVE FROM GOOD CELLS#

set bp [get_timing_paths -max_paths 2000000 -nworst $nw -slack_lesser_than $t]
set bpoints [get_attribute $bp points] 
set bobjects [get_attribute $bpoints object]
set bobjects_filtered [filter_collection $bobjects -regexp "pin_direction == out"]
set cells [get_attribute $bobjects_filtered cell -quiet]
set bcells_full_name [get_attribute $cells full_name]

# GET GOOD CELLS TO BE FILTERED#

set gp [get_timing_paths -max_paths 2000000 -nworst $nw -slack_greater_than $t]
set gcmatrix  ""
set arrival ""

#puts "Input cells for the heuristics:"

foreach_in_collection i $gp {
	set gpoints [get_attribute $i points] 
	lappend arrival [lindex [get_attribute $gpoints arrival] end]
	set objects [get_attribute $gpoints object]
	set objects_filtered_partial [filter_collection $objects -regexp "pin_direction == out"]
	set objects_filtered [remove_from_collection $objects_filtered_partial $bobjects_filtered]

	set cells [get_attribute $objects_filtered cell -quiet]

	set cells_full_name [get_attribute $cells full_name]
	
	#puts "$cells_full_name" 
	lappend gcmatrix $cells;#$cells_full_name 
}

return [list $gcmatrix $arrival]

}


proc gbc { t nw } {
############################################
#################### GGC ###################
############################################

#GET BAD CELLS TO REMOVE FROM GOOD CELLS#

set bp [get_timing_paths -max_paths 2000000 -nworst $nw -slack_lesser_than $t ]
set bcmatrix  ""
set arrival ""

#puts "Input cells for the heuristics:"

foreach_in_collection i $bp {
	set bpoints [get_attribute $i points] 
	lappend arrival [lindex [get_attribute $bpoints arrival] 0]
	set objects [get_attribute $bpoints object]
	set objects_filtered [filter_collection $objects -regexp "pin_direction == out"]

	set cells [get_attribute $objects_filtered cell -quiet]

	set cells_full_name [get_attribute $cells full_name]

	#puts "$cells_full_name" 
	lappend bcmatrix $cells;#$cells_full_name 
	}

return [list $bcmatrix $arrival]
}


proc cm { m } {
############################################
#################### CM ############@#######
############################################
set n_max 1
foreach p $m {

	#puts "-------p : $p-------"

	foreach_in_collection c $p {

		set n [get_attribute $c N -quiet]
		#puts "c : $c -- n: $n"
	
		if {$n == 0} {
			set_user_attribute $c N 1 -quiet
			set_user_attribute $c dP [expr [get_attribute $c PL_LL -quiet] - [get_attribute $c PL_LH -quiet]] -quiet
		} else {
			incr n
			set_user_attribute $c N $n -quiet
			if { $n_max < $n } { 
				set n_max $n 
			} 
		}
		
		#set name [get_attribute $c full_name -quiet]
		#set slack [get_attribute $p slack -quiet]
		#set diffP [get_attribute $c dP -quiet]
		#set n [get_attribute $c N -quiet]
		#puts "$name $n $diffP"
		

	}
}

#puts "n_max: $n_max"
#return
return $n_max
}

proc shd { m a end_power mult} {
	############################################
	#################### SHD ###################
	############################################

		set a [lreverse $a]
		set a_max [lindex $a end]
		#puts "$a"
		set m [lreverse $m]

		#compute max number of swap per iteration for each path (row)
		set toSwap ""
		set i 0
		foreach a_i $a {
			lappend toSwap [expr round( ($mult*$a_max)/$a_i ) ]
		}

		# from n=0 to ... 
		set n 0
		while {[get_attribute [get_design] leakage_power] > $end_power} { ;# loop su N 1-> max N
			incr n

			puts "n = $n"

			set i 0
			foreach p $m {
				# da ogni percorso swappi massimo toSwap[i] ad ogni giro, a ogni nuovo giro selezioni le celle con N <= n
				set sublist [filter_collection $p "N <= $n && swapped == false"]
				set sublist_size [sizeof_collection $sublist]
				set toSwap_i [lindex $toSwap $i]
				#se non hai celle swappabili vai al path successivo
				if {$sublist_size != 0} {
					if {$toSwap_i >= $sublist_size} {  
						# se puoi swappare più celle delle swappabili swappa tutto
						swap $sublist LH
						set_user_attribute $sublist swapped true -quiet
						puts "Swapping [get_attribute $sublist full_name]"
					} else {    
					# se hai un set di celle swappabili maggiore delle celle da swappare parti da N = 1 e vai a salire
						set j 1
						while { $j <= $n } { 
						# da n=1 sino all'n attuale
							set sublist [filter_collection $p "N == $j && swapped == false"]
							set sublist_size [sizeof_collection $sublist]
							if { $sublist_size != 0} {
								if { $toSwap_i >= $sublist_size } {   
								# se con questo n le celle sweappabili sono meno di quelle da swappare swappa tutto
									swap $sublist LH
									set_user_attribute $sublist swapped true -quiet
									incr toSwap_i -$sublist_size
									puts "Swapping [get_attribute $sublist full_name]"
									if { $toSwap_i == $sublist_size } { set j $n } 
									# se le celle da swappare sono uguali alle swappabili esci
								} else {  
								# se puoi scegliere invece, seleziona in base ai dP
									set dP_vector [get_attribute $sublist dP]
									#puts "dP vector $dP_vector"
									set dP_vector [lsort -decreasing -unique $dP_vector]
									puts "dP is taken into account: $dP_vector"					
									foreach dP $dP_vector {  
									# per ogni dP del percorso, dal maggiore al minore..
										set cellToSwap [filter_collection $sublist "dP == $dP && swapped == false"]
										set cellToSwapSize [sizeof_collection $cellToSwap]  

										# con quel dP quante celle getti? più o meno di quelle da swappare?
										if { $toSwap_i > $cellToSwapSize} { 
											swap $cellToSwap LH
											incr toSwap_i -$cellToSwapSize
											set_user_attribute $cellToSwap swapped true -quiet
											puts "Swapping [get_attribute $cellToSwap full_name]" 
											# trick per uscire e passare al prossimo path (row)
										} else { 
										# se sono meno non hai parametri per selezionare, ne prendi un sottoinsieme qualsiasi
												#set $toSwap [expr $toSwap - $cellToSwapSize]
												set toSwapName [get_attribute $cellToSwap full_name]
												set toSwapName [lrange $toSwapName 0 $toSwap_i-1]	

												set cellToSwap [get_cells $toSwapName]
												swap $cellToSwap LH
												set_user_attribute $cellToSwap swapped true -quiet
												set j $n  
												puts "Swapping [get_attribute $cellToSwap full_name]"
												break
												# trick per uscire e passare al prossimo path (row)
										}
										if { [get_attribute [get_design] leakage_power] <= $end_power } { 
											swap $cellToSwap LL
											puts "Fine grain optimization..."
											foreach_in_collection c $cellToSwap {
												swap $c LH
												if { [get_attribute [get_design] leakage_power] <= $end_power } { return  }
											}	
										}	
									}
								}
							}
						    incr j
							if { [get_attribute [get_design] leakage_power] <= $end_power } { 
								swap $sublist LL
								puts "Fine grain optimization..."
								foreach_in_collection c $sublist {
									swap $c LH
									if { [get_attribute [get_design] leakage_power] <= $end_power } { return  }	
								} 
							}
						}
					}
				}
				incr i
				if {[get_attribute [get_design] leakage_power] <= $end_power} {
					swap $sublist LL
					puts "Fine grain optimization..."
					foreach_in_collection c $sublist {
						swap $c LH
						if { [get_attribute [get_design] leakage_power] <= $end_power } { return  }	
					} 
				}
			}

		}
	} 


proc shr { m a end_power n_max mult} {
	############################################
	#################### SHR ###################
	############################################

		#puts "$a"
		
		set a_min [lindex $a end]
		set toSwap ""

		foreach a_i $a {
			lappend toSwap [expr round(($mult*$a_i)/$a_min)]			
		}
		

		# from n=n_max to ... 1
		set n $n_max
		while {$n > 0} { 

			puts "n = $n"

			set i 0
			foreach p $m {
				# da ogni percorso swappi massimo toSwap[i] ad ogni giro, a ogni nuovo giro selezioni le celle con N >= n
				set sublist [filter_collection $p "N >= $n && swapped == false"]
				set sublist_size [sizeof_collection $sublist]
				set toSwap_i [lindex $toSwap $i]
				#se non hai celle swappabili vai al path successivo
				if {$sublist_size != 0} {
					if {$toSwap_i >= $sublist_size} {  
						# se puoi swappare più celle delle swappabili swappa tutto
						swap $sublist LL
						set_user_attribute $sublist swapped true -quiet

						set last_cells $sublist

						incr toSwap_i -$sublist_size
						puts "Swapping [get_attribute $sublist full_name]"
					} else {   
					# se hai un set di celle swappabili maggiore delle celle da swappare parti da N = n_max e vai a scendere sino a n
						
						set j $n_max
						while { $j >= $n } { 
						# da j=n_max sino all'n attuale
							set sublist [filter_collection $p "N == $j && swapped == false"]
							set sublist_size [sizeof_collection $sublist]
							if { $sublist_size != 0} {
								if { $toSwap_i >= $sublist_size } {   
								# se con questo n le celle sweappabili sono meno di quelle da swappare swappa tutto
									swap $sublist LL
									set_user_attribute $sublist swapped true -quiet

									set last_cells $sublist

									incr toSwap_i -$sublist_size
									puts "Swapping [get_attribute $sublist full_name]"
									if { $toSwap_i == 0 } { set j $n } 
									# se le celle da swappare sono uguali alle swappabili esci
								} else {  
								# se puoi scegliere invece, seleziona in base ai dP
									set dP_vector [get_attribute $sublist dP]
									#puts "dP vector $dP_vector"
									set dP_vector [lsort -increasing -unique $dP_vector]
									puts "dP is taken into account: $dP_vector"					
									foreach dP $dP_vector {  
									# per ogni dP del percorso, dal maggiore al minore..
										if { $toSwap_i != 0 } {
											#puts "new dP $dP"
											set cellToSwap [filter_collection $sublist "dP == $dP && swapped == false"]
											set cellToSwapSize [sizeof_collection $cellToSwap]  

											# con quel dP quante celle getti? più o meno di quelle da swappare?
											if { $toSwap_i > $cellToSwapSize} { 
												swap $cellToSwap LL
												set_user_attribute $cellToSwap swapped true -quiet

												set last_cells $cellToSwap

												incr toSwap_i -$cellToSwapSize
												puts "Swapping [get_attribute $cellToSwap full_name]"
												#puts "toSwap : $toSwap_i"
											} else { 
											# se sono meno non hai parametri per selezionare, ne prendi un sottoinsieme qualsiasi
													#set $toSwap [expr $toSwap - $cellToSwapSize]
													set toSwapName [get_attribute $cellToSwap full_name]
													set toSwapName [lrange $toSwapName 0 $toSwap_i-1]	

													set cellToSwap [get_cells $toSwapName]
													swap $cellToSwap LL
													set_user_attribute $cellToSwap swapped true -quiet

													set last_cells $cellToSwap
												
													puts "Swapping [get_attribute $cellToSwap full_name]"
													set  toSwap_i 0
													set j $n 
													# trick per uscire e passare al prossimo path (row)
											}
										}
										if { [get_attribute [get_design] leakage_power] >= $end_power } {
											puts "Fine grain optimization..." 
											foreach_in_collection c $last_cells {
												swap $c LH
												if {[get_attribute [get_design] leakage_power] <= $end_power} { return } 
											}
										}
									}
								}
							}
							incr j -1
							if { [get_attribute [get_design] leakage_power] >= $end_power } {  
								puts "Fine grain optimization..."
								foreach_in_collection c $last_cells {
									swap $c LH
									if {[get_attribute [get_design] leakage_power] <= $end_power} { return } 
								}
							}
						}
					}
				}
				incr i
				if { [get_attribute [get_design] leakage_power] >= $end_power } { 
					puts "Fine grain optimization..."
					foreach_in_collection c $last_cells {
						swap $c LH
						if { [get_attribute [get_design] leakage_power] <= $end_power } { return } 
					}
				}
			}
			incr n -1
		}

}

	
proc clean {} {
	swap [get_cells] LL
}
