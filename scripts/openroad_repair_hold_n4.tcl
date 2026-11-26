# ==========================================
# ASIC Moving Average
# Post-CTS Hold Repair - Direct N=4
# SKY130 HD
# ==========================================

# 1. Cargar diseño post-CTS
read_db results/physical/n4/direct_cts.odb

# 2. Cargar biblioteca temporal
set LIB "/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"

read_liberty $LIB

# Excluir celdas incompatibles con la implementacion fisica
set_dont_use {
    sky130_fd_sc_hd__probe_p_8
    sky130_fd_sc_hd__probec_p_8
}

# 3. Cargar restricciones
read_sdc constraints/sta_preplacement.sdc

# 4. Configurar reloj propagado
set_propagated_clock [all_clocks]

# 5. Estimar parasiticos
set_wire_rc -signal -layer met2
set_wire_rc -clock -layer met3

estimate_parasitics -placement

# 6. Registrar estado inicial
set block [ord::get_db_block]

set instances_before [llength [$block getInsts]]

puts "\n================================="
puts "ANTES DE HOLD REPAIR"
puts "================================="

report_worst_slack -max
report_worst_slack -min

report_checks \
    -path_delay min \
    -group_path_count 1

# 7. Reparar hold
puts "\n================================="
puts "EJECUTANDO HOLD REPAIR"
puts "================================="

repair_timing \
    -hold \
    -max_utilization 65

# 8. Legalizar nuevas celdas
detailed_placement

check_placement -verbose

# 9. Actualizar conexiones de alimentacion
global_connect

# 10. Actualizar estimacion de parasiticos
estimate_parasitics -placement

# 11. Registrar estado final
set instances_after [llength [$block getInsts]]

puts "\n================================="
puts "DESPUES DE HOLD REPAIR"
puts "================================="

puts "Instancias antes: $instances_before"
puts "Instancias despues: $instances_after"
puts "Instancias añadidas: [expr {$instances_after - $instances_before}]"

report_design_area

puts "\nSETUP WNS:"
report_worst_slack -max

puts "\nHOLD WNS:"
report_worst_slack -min

report_checks \
    -path_delay min \
    -group_path_count 1

# 12. Guardar diseño
write_db results/physical/n4/direct_hold_repaired.odb

write_def results/physical/n4/direct_hold_repaired.def

puts "\nHOLD REPAIR FINALIZADO"
