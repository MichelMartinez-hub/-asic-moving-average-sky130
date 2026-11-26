# ==========================================
# ANALISIS TEMPORAL ESTATICO
# Arquitectura directa - N = 4
# Tecnologia: SKY130
# ==========================================

# 1. Biblioteca tecnologica

set LIB "/foss/pdks/ciel/sky130/versions/1689ac3f2dc763876eaf967227c7dfe831b031ae/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"

read_liberty $LIB

# 2. Cargar netlist sintetizada

read_verilog \
    results/synthesis/n4/direct_sky130_filtered.v

# 3. Establecer modulo principal

link_design moving_average_direct

# 4. Cargar restricciones temporales

read_sdc constraints/sta_preplacement.sdc

# 5. Comprobar configuracion del analisis

check_setup

# 6. Analizar rutas criticas de setup

puts "\n=================================="
puts "RUTAS CRITICAS - SETUP"
puts "=================================="

report_checks \
    -path_delay max \
    -group_path_count 5 \
    -format full

# 7. Reportar peor slack

puts "\n=================================="
puts "WORST SLACK"
puts "=================================="

report_worst_slack -max

puts "\nAnalisis temporal completado."
