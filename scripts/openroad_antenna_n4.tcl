# ==========================================
# ASIC MOVING AVERAGE
# Antenna Verification
# Direct N=4 - SKY130 HD
# ==========================================

set ROOT "results/physical/n4"

# 1. Cargar implementacion corregida
read_db $ROOT/direct_ff_detailed_route.odb

# 2. Verificar reglas de antena
puts "\n================================="
puts "INICIANDO ANTENNA CHECK"
puts "================================="

check_antennas \
    -report_file $ROOT/direct_ff_antenna.rpt

puts "\n================================="
puts "ANTENNA CHECK FINALIZADO"
puts "================================="

