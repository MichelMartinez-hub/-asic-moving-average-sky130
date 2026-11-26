# ==========================================
# ASIC Moving Average
# Global Placement - Direct N=4
# SKY130 HD
# ==========================================

# 1. Cargar diseño físico
read_db results/physical/n4/direct_pdn.odb

# 2. Cargar biblioteca temporal
set LIB "/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"

read_liberty $LIB

# 3. Cargar restricciones
read_sdc constraints/sta_preplacement.sdc

# 4. Global placement
puts "\n================================="
puts "INICIANDO GLOBAL PLACEMENT"
puts "================================="

global_placement \
    -density 0.55

# 5. Obtener informacion
set block [ord::get_db_block]

set instances [llength [$block getInsts]]

puts "\n================================="
puts "GLOBAL PLACEMENT COMPLETADO"
puts "================================="

puts "Instancias totales: $instances"

# 6. Guardar resultados
write_db results/physical/n4/direct_global_place.odb

write_def results/physical/n4/direct_global_place.def

puts "\nArchivos ODB y DEF generados."
