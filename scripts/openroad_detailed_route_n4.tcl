# ==========================================
# ASIC Moving Average
# Detailed Routing - Direct N=4
# SKY130 HD
# ==========================================

# 1. Cargar diseño post-Global Routing
read_db results/physical/n4/direct_global_route.odb

# 2. Cargar guias de enrutamiento
read_guides results/physical/n4/direct_route.guide

# ==========================================
# DETAILED ROUTING
# ==========================================

puts "\n================================="
puts "INICIANDO DETAILED ROUTING"
puts "================================="

# 3. Ejecutar TritonRoute
detailed_route \
    -output_drc results/physical/n4/direct_route_drc.rpt \
    -output_maze results/physical/n4/direct_route_maze.log \
    -verbose 1

# ==========================================
# RESULTADOS
# ==========================================

puts "\n================================="
puts "RESULTADOS DETAILED ROUTING"
puts "================================="

# 4. Contar violaciones reportadas
set drc_count [detailed_route_num_drvs]

puts "Violaciones DRC: $drc_count"

# 5. Comprobar si las redes estan enrutadas
if {[design_is_routed]} {
    puts "Estado de enrutamiento: COMPLETO"
} else {
    puts "Estado de enrutamiento: INCOMPLETO"
}

# ==========================================
# GUARDAR RESULTADOS
# ==========================================

write_db results/physical/n4/direct_detailed_route.odb

write_def results/physical/n4/direct_detailed_route.def

puts "\n================================="
puts "DETAILED ROUTING FINALIZADO"
puts "================================="
