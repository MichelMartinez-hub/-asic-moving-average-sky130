# ==========================================
# ASIC Moving Average
# PDN Connectivity Check - Direct N=4
# SKY130 HD
# ==========================================

# Cargar diseño con PDN generada
read_db results/physical/n4/direct_pdn.odb

# ==========================================
# VERIFICACION DE VDD
# ==========================================

puts "\n================================="
puts "VERIFICANDO RED VDD"
puts "================================="

check_power_grid \
    -net VDD \
    -floorplanning \
    -error_file results/physical/n4/vdd_errors.rpt

# ==========================================
# VERIFICACION DE VSS
# ==========================================

puts "\n================================="
puts "VERIFICANDO RED VSS"
puts "================================="

check_power_grid \
    -net VSS \
    -floorplanning \
    -error_file results/physical/n4/vss_errors.rpt

puts "\n================================="
puts "VERIFICACION PDN FINALIZADA"
puts "================================="

