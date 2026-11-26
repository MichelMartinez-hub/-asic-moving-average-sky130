# ==========================================
# ASIC Moving Average
# Detailed Placement - Direct N=4
# SKY130 HD
# ==========================================

# 1. Cargar diseño con global placement
read_db results/physical/n4/direct_global_place.odb

# 2. Obtener base de datos
set block [ord::get_db_block]

puts "\n================================="
puts "INICIANDO DETAILED PLACEMENT"
puts "================================="

# 3. Legalizar las posiciones de las celdas
detailed_placement

# 4. Verificar legalidad de la colocacion
puts "\n================================="
puts "VERIFICACION DE PLACEMENT"
puts "================================="

check_placement -verbose

# 5. Mostrar numero de instancias
set instances [llength [$block getInsts]]

puts "\n================================="
puts "DETAILED PLACEMENT COMPLETADO"
puts "================================="

puts "Instancias totales: $instances"

# 6. Guardar resultados
write_db results/physical/n4/direct_detailed_place.odb

write_def results/physical/n4/direct_detailed_place.def

puts "\nArchivos ODB y DEF generados."
