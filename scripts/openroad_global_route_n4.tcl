# ==========================================
# ASIC Moving Average
# Global Routing - Direct N=4
# SKY130 HD
# ==========================================

# 1. Cargar diseño post-CTS
read_db results/physical/n4/direct_hold_repaired.odb

# 2. Cargar biblioteca temporal
set LIB "/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"

read_liberty $LIB

# 3. Cargar restricciones
read_sdc constraints/sta_preplacement.sdc

# 4. Utilizar reloj propagado
set_propagated_clock [all_clocks]

# 5. Configurar capas de enrutamiento
set_routing_layers \
    -signal met1-met5 \
    -clock met3-met5

# 6. Configurar estimacion RC
set_wire_rc -signal -layer met2
set_wire_rc -clock -layer met3

# ==========================================
# GLOBAL ROUTING
# ==========================================

puts "\n================================="
puts "INICIANDO GLOBAL ROUTING"
puts "================================="

global_route \
    -guide_file results/physical/n4/direct_route.guide \
    -congestion_report_file results/physical/n4/direct_congestion.rpt \
    -verbose

# ==========================================
# VERIFICACION DE CONGESTION
# ==========================================

puts "\n================================="
puts "VERIFICACION DE CONGESTION"
puts "================================="



# ==========================================
# ANALISIS TEMPORAL
# ==========================================

# Estimar parasiticos usando las rutas globales
estimate_parasitics -global_routing

puts "\n================================="
puts "SETUP POST-GLOBAL ROUTING"
puts "================================="

report_worst_slack -max

puts "\n================================="
puts "HOLD POST-GLOBAL ROUTING"
puts "================================="

report_worst_slack -min

# ==========================================
# GUARDAR RESULTADOS
# ==========================================

write_db results/physical/n4/direct_global_route.odb

write_def results/physical/n4/direct_global_route.def

puts "\nGLOBAL ROUTING COMPLETADO"
