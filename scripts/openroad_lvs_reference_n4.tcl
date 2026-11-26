# ==========================================
# ASIC MOVING AVERAGE
# LVS Reference Netlist
# Direct N=4 - SKY130 HD
# ==========================================

set ROOT "results/physical/n4"

set MASTER \
    "/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/spice/sky130_fd_sc_hd.spice"

set INPUT_DB "$ROOT/direct_ff_fillers.odb"

set OUTPUT_CDL "$ROOT/direct_ff_reference.cdl"

# ==========================================
# 1. VERIFICAR ARCHIVOS
# ==========================================

if {![file isfile $MASTER]} {
    error "Biblioteca SPICE no encontrada: $MASTER"
}

if {![file isfile $INPUT_DB]} {
    error "Base de datos no encontrada: $INPUT_DB"
}

# ==========================================
# 2. CARGAR IMPLEMENTACION FINAL
# ==========================================

read_db $INPUT_DB

set block [ord::get_db_block]

puts "\n================================="
puts "GENERANDO REFERENCIA LVS"
puts "================================="

puts "Diseno: [$block getName]"
puts "Instancias: [llength [$block getInsts]]"

# ==========================================
# 3. EXPORTAR NETLIST CDL
# ==========================================

write_cdl \
    -masters [list $MASTER] \
    -include_fillers \
    $OUTPUT_CDL

puts "\n================================="
puts "REFERENCIA LVS GENERADA"
puts "================================="

puts "Archivo: $OUTPUT_CDL"
