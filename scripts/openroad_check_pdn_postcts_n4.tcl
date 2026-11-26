# ==========================================
# ASIC Moving Average
# PDN Check Post-CTS - Direct N=4
# SKY130 HD
# ==========================================

# 1. Cargar diseño post-CTS y hold repair
read_db results/physical/n4/direct_hold_repaired.odb

# 2. Verificar placement
puts "\n================================="
puts "VERIFICACION DE PLACEMENT"
puts "================================="

check_placement -verbose

# 3. Verificar alimentacion VDD
puts "\n================================="
puts "VERIFICACION COMPLETA VDD"
puts "================================="

check_power_grid \
    -net VDD \
    -error_file results/physical/n4/vdd_postcts_errors.rpt

# 4. Verificar alimentacion VSS
puts "\n================================="
puts "VERIFICACION COMPLETA VSS"
puts "================================="

check_power_grid \
    -net VSS \
    -error_file results/physical/n4/vss_postcts_errors.rpt

# 5. Contar instancias
set block [ord::get_db_block]

puts "\n================================="
puts "ESTADO FINAL"
puts "================================="

puts "Instancias: [llength [$block getInsts]]"

puts "\nVERIFICACION FINALIZADA"
