# Use detailed geometry to detect antenna violations and repair the global guides.
set checkpoint $::env(ANTENNA_CHECKPOINT)
read_db [file join $checkpoint direct_ff_detailed_route.odb]
foreach inst [[ord::get_db_block] getInsts] {
    if {[[$inst getMaster] getType] eq "CORE_SPACER"} {
        error "Antenna repair requires a checkpoint without filler cells"
    }
}
read_liberty $::env(FLOW_LIB)
set_routing_layers -signal met1-met5 -clock met3-met5
read_guides [file join $checkpoint direct_ff_route.guide]
repair_antennas sky130_fd_sc_hd__diode_2 -diode_only
global_connect
write_guides direct_ff_route.guide
write_db direct_ff_global_route.odb
