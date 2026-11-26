# ==========================================
# ASIC MOVING AVERAGE
# Filler Cell Insertion
# Direct N=4 - SKY130 HD
# ==========================================

set ROOT "results/physical/n4"

# ==========================================
# 1. CARGAR IMPLEMENTACION FISICA
# ==========================================

read_db $ROOT/direct_ff_detailed_route.odb

set block [ord::get_db_block]

set inst_before [llength [$block getInsts]]

puts "\n================================="
puts "INSERCION DE FILLER CELLS"
puts "================================="

puts "Instancias antes: $inst_before"

# ==========================================
# 2. INSERTAR FILLER CELLS
# ==========================================

filler_placement \
    -verbose \
    {
        sky130_fd_sc_hd__fill_8
        sky130_fd_sc_hd__fill_4
        sky130_fd_sc_hd__fill_2
        sky130_fd_sc_hd__fill_1
    }

# ==========================================
# 3. ACTUALIZAR CONEXIONES DE ALIMENTACION
# ==========================================

global_connect

# ==========================================
# 4. VERIFICAR PLACEMENT
# ==========================================

puts "\n================================="
puts "VERIFICACION DE PLACEMENT"
puts "================================="

check_placement -verbose

# ==========================================
# 5. VERIFICAR POWER GRID
# ==========================================

puts "\n================================="
puts "VERIFICACION VDD"
puts "================================="

check_power_grid \
    -net VDD \
    -error_file $ROOT/direct_ff_fillers_vdd.rpt

puts "\n================================="
puts "VERIFICACION VSS"
puts "================================="

check_power_grid \
    -net VSS \
    -error_file $ROOT/direct_ff_fillers_vss.rpt

# ==========================================
# 6. RESULTADOS
# ==========================================

set inst_after [llength [$block getInsts]]

puts "\n================================="
puts "RESULTADOS FILLER INSERTION"
puts "================================="

puts "Instancias antes: $inst_before"
puts "Instancias despues: $inst_after"
puts "Filler cells insertadas: [expr {$inst_after - $inst_before}]"

# ==========================================
# 7. GUARDAR IMPLEMENTACION
# ==========================================

# Guardar base de datos fisica
write_db $ROOT/direct_ff_fillers.odb

# Exportar implementacion a DEF
write_def $ROOT/direct_ff_fillers.def

puts "\n================================="
puts "FILLER INSERTION COMPLETADA"
puts "================================="
