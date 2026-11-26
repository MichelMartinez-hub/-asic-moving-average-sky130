read_db $::env(POWER_ODB)
read_liberty $::env(POWER_LIB)
read_sdc $::env(POWER_SDC)
set clocks [all_clocks]
if {[llength $clocks] != 1 || [get_name [lindex $clocks 0]] ne "core_clk"
    || abs([get_property [lindex $clocks 0] period] - 20.0) > 1e-9} {
    error "Expected the SDC core_clk at 50 MHz"
}
set_propagated_clock $clocks
read_spef $::env(POWER_SPEF)
report_parasitic_annotation -report_unannotated
report_worst_slack -max -digits 9
report_worst_slack -min -digits 9

set data [get_ports {in_data*}]
set controls [get_ports {rst_n enable in_valid}]
if {[llength $data] != 12 || [llength $controls] != 3 || [llength [all_inputs]] != 16} {
    error "Unexpected primary input interface"
}
set_power_activity -input_ports $data -activity 0.1 -duty 0.5 -clock $clocks
set_case_analysis 1 $controls
set_power_activity -input_ports $controls -activity 0 -duty 1 -clock $clocks
report_activity_annotation -report_annotated

set block [ord::get_db_block]
puts "POWER_DESIGN [$block getName] [llength [$block getInsts]]"
set masters {}
foreach instance [$block getInsts] {
    set master [$instance getMaster]
    dict set masters [$master getName] [$master getType]
    foreach pin [$instance getITerms] {
        if {[[$pin getMTerm] getIoType] ne "OUTPUT"} {
            continue
        }
        set net [$pin getNet]
        if {$net eq "NULL" || ([llength [$net getITerms]] == 1 && [llength [$net getBTerms]] == 0)} {
            puts "POWER_UNLOADED [$instance getName]/[[$pin getMTerm] getName]"
        }
    }
}
dict for {name type} $masters {
    if {[llength [get_lib_cells -quiet $name]] != 1} {
        if {$type ne "CORE_WELLTAP" || $name ne "sky130_fd_sc_hd__tapvpwrvgnd_1"} {
            error "Missing or ambiguous Liberty cell: $name ($type)"
        }
        puts "POWER_PHYSICAL_ONLY $name $type"
        continue
    }
    puts "POWER_MASTER $name $type"
}
report_power -digits 10
report_power -digits 10 -format json > $::env(POWER_JSON)
puts "POWER_COMPLETED"
