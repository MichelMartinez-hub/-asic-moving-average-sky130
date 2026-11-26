# Measure the routed design before inserting fillers.
read_db direct_ff_detailed_route.odb
read_liberty $::env(FLOW_LIB)
set block [ord::get_db_block]
set dbu [$block getDbUnitsPerMicron]
set area 0
foreach inst [$block getInsts] {
    set master [$inst getMaster]
    set area [expr {$area + double([$master getWidth]) * [$master getHeight]}]
}
set out [open physical_metrics.txt w]
foreach {key rect} [list core [$block getCoreArea] die [$block getDieArea]] {
    puts $out "${key}_area_um2 [expr {double([$rect dx]) * [$rect dy] / $dbu / $dbu}]"
}
puts $out "placed_area_um2 [expr {$area / $dbu / $dbu}]"
puts $out "instances [llength [$block getInsts]]"
puts $out "registers [llength [all_registers]]"
close $out
