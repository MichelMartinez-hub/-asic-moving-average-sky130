# ==========================================
# POST-ROUTING TIMING ANALYSIS
# Direct N=4 - SKY130 HD
# ==========================================

set ROOT "results/physical/n4"

set LIB "/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"

# Cargar diseño y biblioteca
read_db $ROOT/direct_detailed_route.odb
read_liberty $LIB

# Cargar restricciones
read_sdc constraints/sta_preplacement.sdc

# Utilizar el arbol de reloj fisico
set_propagated_clock [all_clocks]

# Cargar parasitos extraidos
read_spef $ROOT/direct_extracted.spef

# ==========================================
# HOLD
# ==========================================

puts "\n================================="
puts "CINCO RUTAS CRITICAS DE HOLD"
puts "================================="

report_checks \
    -path_delay min \
    -group_path_count 5 \
    -fields {slew capacitance fanout} \
    -format full_clock_expanded \
    -digits 4

# ==========================================
# SETUP
# ==========================================

puts "\n================================="
puts "TRES RUTAS CRITICAS DE SETUP"
puts "================================="

report_checks \
    -path_delay max \
    -group_path_count 3 \
    -fields {slew capacitance fanout} \
    -format full_clock_expanded \
    -digits 4

# ==========================================
# RESUMEN
# ==========================================

# ==========================================
# SETUP REGISTER-TO-REGISTER
# ==========================================

puts "\n================================="
puts "SETUP INTERNO REG-TO-REG"
puts "================================="

report_checks \
    -path_delay max \
    -from [all_registers] \
    -to [all_registers] \
    -group_path_count 5 \
    -fields {slew capacitance fanout} \
    -format full_clock_expanded \
    -digits 4

# ==========================================
# HOLD REGISTER-TO-REGISTER
# ==========================================

puts "\n================================="
puts "HOLD INTERNO REG-TO-REG"
puts "================================="

report_checks \
    -path_delay min \
    -from [all_registers] \
    -to [all_registers] \
    -group_path_count 5 \
    -fields {slew capacitance fanout} \
    -format full_clock_expanded \
    -digits 4



puts "\n================================="
puts "RESUMEN TEMPORAL"
puts "================================="

report_worst_slack -max
report_worst_slack -min
report_tns

puts "\nANALISIS FINALIZADO"

