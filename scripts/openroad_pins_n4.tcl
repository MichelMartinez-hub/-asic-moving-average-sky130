# ==========================================
# ASIC Moving Average
# IO Pin Placement - Direct N=4
# SKY130 HD
# ==========================================

# 1. Cargar floorplan
read_db results/physical/n4/direct_floorplan.odb

# 2. Obtener base de datos
set block [ord::get_db_block]

# 3. Contar puertos
set ports [$block getBTerms]

puts "\n================================="
puts "COLOCACION DE PINES"
puts "================================="

puts "Puertos encontrados: [llength $ports]"

# 4. Colocacion automatica
place_pins \
    -hor_layers met3 \
    -ver_layers met2

# 5. Guardar base de datos
write_db results/physical/n4/direct_pins.odb

# 6. Exportar DEF
write_def results/physical/n4/direct_pins.def

puts "\n================================="
puts "PIN PLACEMENT COMPLETADO"
puts "================================="

puts "Archivo ODB generado."
puts "Archivo DEF generado."
