#/**************************************************/
#/* Compile Script for Synopsys                    */
#/*                                                */
#/* dc_shell-t -f compile_dc.tcl                   */
#/*                                                */
#/* OSU FreePDK 45nm                               */
#/* Modified for OSU ami05 - Rice U. 2018          */
#/*                                                */
#/**************************************************/

#/* User Input Data Section: List files, module, clock, frequency below. */
#/* Edit this part only of the file.                                     */
#/* Add all verilog files, separated by spaces after keyword "list"      */

set my_verilog_files [list instruction_mem.v alu.v data_mem_cached.v decode.v processor.v reg_file.v system_top.v]

#/* Top-level Module Name update                             */
set my_toplevel system_top

#/* The name of the clock pin(s). For multiple clocks, list them all. */
#/* Example for two phase clock: [list clka clkb]                    */
set my_clock_pins [list clka clkb]

#/* Target frequency in MHz. If clocks have different frequencies,   */
#/* list them in the same order as my_clock_pins.                    */                                        */
set my_clk_freqs_MHz [list 50 50]

#/* Delay of input signals (Clock-to-Q, Package etc.)  */
set my_input_delay_ns 1

#/* Reserved time for output signals (Holdtime etc.)   */
set my_output_delay_ns 1

#/*Default driving cell applied to all inputs     */
set my_driving_cell INVX1

set my_clock_group_mode logically_exclusive

set my_clock_io_map [list \
    [list clka [list reset_pi instr_valid_pi load_done_pi] [list halted_po ready_po dbg_data_po[*]]] \
    [list clkb [list instr_data_pi[*] dbg_addr_pi[*]] [list]] \
]


#/********************************************************************/
#/********************************************************************/
#/* No modifications needed below. Do not edit or remove.            */
#/*                                                                  */
#/* Paths updated for Rice U. on CLEAR cluster 2018.                 */
#/********************************************************************/
#/********************************************************************/

#/* Start of Synopsys library cells location data.               */
set OSUcells "/clear/apps/osu/soc/synopsys/lib/ami05"
set search_path [concat  $search_path $OSUcells]
set alib_library_analysis_path $OSUcells

set link_library [set target_library [concat  [list osu05_stdcells.db] [list dw_foundation.sldb]]]
set target_library "osu05_stdcells.db"
#/* End of Synopsys library cells location data.                  */

define_design_lib WORK -path ./WORK
set verilogout_show_unconnected_pins "true"

analyze -f verilog $my_verilog_files

elaborate $my_toplevel

current_design $my_toplevel

link
uniquify


#################### MODIFICATION START ####################

# --- Create all clocks defined in the user list ---
set clock_names [list]
set i 0
foreach clock_pin $my_clock_pins {
    set freq [lindex $my_clk_freqs_MHz $i]
    set period [expr 1000.0 / $freq]

    set find_clock [find port [list $clock_pin]]
    if { $find_clock != [list] } {
        echo "Info: Found clock port '$clock_pin'. Creating clock with period ${period}ns."
        create_clock -name $clock_pin -period $period [get_ports $clock_pin]
        lappend clock_names $clock_pin
    } else {
        echo "Warning: Clock port '$clock_pin' not found in design. Skipping clock creation for it."
    }
    incr i
}

# MODIFICATION: Define relationship among clocks in a general way (not hard-coded to 2 clocks).
if { [llength $clock_names] > 1 } {
    if { $my_clock_group_mode == "logically_exclusive" } {
        echo "Info: Defining clock groups as logically exclusive."
        # MODIFICATION: Build a set_clock_groups command with one -group per clock.
        set scg_cmd "set_clock_groups -logically_exclusive"
        foreach clk $clock_names {
            append scg_cmd " -group \[get_clocks $clk\]"
        }
        eval $scg_cmd
    } else {
        echo "Info: Clock grouping disabled (my_clock_group_mode = '$my_clock_group_mode')."
    }
}

# --- Set I/O constraints with respect to the correct clock phase ---
# The I/O ports are grouped based on their likely corresponding clock phase.
# Please verify this matches your design's specific architecture.
if { [llength $clock_names] > 0 } {

    echo "Info: Setting I/O constraints for the multi-clock design."

    # MODIFICATION: Set a default driving cell for all inputs (optional via my_driving_cell).
    if { $my_driving_cell != "" } {
        set non_clk_inputs [remove_from_collection [all_inputs] [get_ports $my_clock_pins]]
        set_driving_cell -lib_cell $my_driving_cell $non_clk_inputs
    } else {
        echo "Info: Skipping set_driving_cell because my_driving_cell is empty."
    }

    # MODIFICATION: Apply per-clock I/O delays based on user-defined mapping in the top section.
    foreach entry $my_clock_io_map {

        set clk_pin      [lindex $entry 0]
        set in_list_raw  [lindex $entry 1]
        set out_list_raw [lindex $entry 2]

        # MODIFICATION: Only apply constraints if this clock actually exists/was created.
        if { [lsearch -exact $clock_names $clk_pin] < 0 } {
            echo "Warning: Clock '$clk_pin' not found/created. Skipping its I/O constraints."
            continue
        }

        set this_clk [get_clocks $clk_pin]

        # MODIFICATION: Resolve inputs/outputs using get_ports on the patterns provided.
        set this_inputs  [get_ports $in_list_raw]
        set this_outputs [get_ports $out_list_raw]

        if { [llength $this_inputs] > 0 } {
            set_input_delay $my_input_delay_ns -clock $this_clk $this_inputs
        }
        if { [llength $this_outputs] > 0 } {
            set_output_delay $my_output_delay_ns -clock $this_clk $this_outputs
        }
    }
}
#################### MODIFICATION END ####################


compile -ungroup_all -map_effort medium

compile -incremental_mapping -map_effort medium

check_design
report_constraint -all_violators

set filename [format "%s%s"  $my_toplevel ".vh"]
write -f verilog -output $filename

set filename [format "%s%s"  $my_toplevel ".sdc"]
write_sdc $filename

report_cell 
report_area 
report_timing -path full -delay max -max_paths 3 -nworst 1
report_power

redirect timing.rep { report_timing }
redirect cell.rep { report_cell }
redirect power.rep { report_power }

quit
