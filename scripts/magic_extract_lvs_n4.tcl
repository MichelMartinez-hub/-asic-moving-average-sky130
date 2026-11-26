# ==========================================
# ASIC MOVING AVERAGE
# Magic LVS Extraction
# Direct N=4 - SKY130 HD
# ==========================================

# 1. Deshabilitar comprobaciones innecesarias
drc off
locking disable
crashbackups stop

# 2. Preparar seleccion
box 0 0 0 0

# 3. Importar GDSII
gds read /foss/designs/asic_moving_average/results/physical/n4/direct_ff_final.gds

# 4. Cargar celda principal
load moving_average_direct

select top cell

puts "\n================================="
puts "INICIANDO EXTRACCION LVS"
puts "================================="

# 5. Directorio de archivos intermedios
extract path extfiles

# 6. Extraer conectividad
extract all

# 7. Configurar salida para LVS
ext2spice lvs

# 8. Exportar netlist SPICE
ext2spice -p extfiles -o moving_average_direct_extracted.spice

puts "\n================================="
puts "EXTRACCION LVS FINALIZADA"
puts "================================="

quit -noprompt

