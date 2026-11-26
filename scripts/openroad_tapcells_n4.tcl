# ==========================================
# ASIC Moving Average
# Tapcell Insertion - Direct N=4
# SKY130 HD
# ==========================================

# 1. Cargar diseño con pines colocados
read_db results/physical/n4/direct_pins.odb

# 2. Obtener base de datos
set block [ord::get_db_block]

# 3. Contar instancias originales
set instances_before [llength [$block getInsts]]

puts "\n================================="
puts "INSERCION DE TAPCELLS"
puts "================================="

puts "Instancias antes: $instances_before"

# 4. Insertar tapcells
tapcell \
    -distance 14 \
    -tapcell_master sky130_fd_sc_hd__tapvpwrvgnd_1

# 5. Contar instancias posteriores
set instances_after [llength [$block getInsts]]

set tapcells_added [expr {
    $instances_after - $instances_before
}]

puts "\n================================="
puts "TAPCELL INSERTION COMPLETADA"
puts "================================="

puts "Instancias antes: $instances_before"
puts "Instancias despues: $instances_after"
puts "Tapcells añadidas: $tapcells_added"

# 6. Guardar resultados
write_db results/physical/n4/direct_tapcells.odb

write_def results/physical/n4/direct_tapcells.def

puts "\nArchivos ODB y DEF generados."
