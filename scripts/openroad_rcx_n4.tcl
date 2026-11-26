# ==========================================
# ASIC MOVING AVERAGE
# OpenRCX + Post-Routing STA
# Arquitectura: Direct
# Ventana: N=4
# Tecnologia: SKY130 HD
# ==========================================

# Directorios
set ROOT "results/physical/n4"

# Biblioteca Liberty
set LIB "/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"

# Reglas RCX nominales de SKY130A
set RULES "/foss/pdks/sky130A/libs.tech/librelane/rules.openrcx.sky130A.nom.calibre"

# ==========================================
# 1. VERIFICACION DE ARCHIVOS
# ==========================================

if {![file exists $RULES]} {
    error "No se encontraron las reglas RCX: $RULES"
}

if {![file exists $ROOT/direct_detailed_route.odb]} {
    error "No se encontro la base de datos enrutada"
}

# ==========================================
# 2. CARGAR DISENO
# ==========================================

read_db $ROOT/direct_detailed_route.odb

read_liberty $LIB

read_sdc constraints/sta_preplacement.sdc

set_propagated_clock [all_clocks]

# ==========================================
# 3. EXTRACCION DE PARASITOS
# ==========================================

puts "\n================================="
puts "INICIANDO EXTRACCION RC"
puts "================================="

# Definir esquina nominal
define_process_corner -ext_model_index 0 X

# Extraer resistencias y capacitancias
extract_parasitics -ext_model_file $RULES

# Exportar parasitos a SPEF
write_spef $ROOT/direct_extracted.spef

puts "\nEXTRACCION RC COMPLETADA"

# ==========================================
# 4. ANALISIS TEMPORAL POST-ROUTING
# ==========================================

# Cargar parasitos extraidos para STA
read_spef $ROOT/direct_extracted.spef

puts "\n================================="
puts "SETUP POST-ROUTING"
puts "================================="

report_worst_slack -max

puts "\n================================="
puts "HOLD POST-ROUTING"
puts "================================="

report_worst_slack -min

puts "\n================================="
puts "TOTAL NEGATIVE SLACK"
puts "================================="

report_tns

# ==========================================
# 5. GUARDAR RESULTADOS
# ==========================================

write_db $ROOT/direct_extracted.odb

puts "\n================================="
puts "RCX Y STA POST-ROUTING COMPLETADOS"
puts "================================="
