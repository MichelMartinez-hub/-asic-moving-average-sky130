# ==========================================
# ASIC Moving Average
# OpenROAD - Importacion del diseño
# Arquitectura directa, N = 4
# ==========================================

# Directorio del PDK
set PDK "/foss/pdks/sky130A"

# Archivos tecnologicos
set TECH_LEF "$PDK/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef"

set CELL_LEF "$PDK/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef"

set LIB "$PDK/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"

# Netlist sintetizada
set NETLIST "results/synthesis/n4/direct_sky130_filtered.v"

set TOP "moving_average_direct"

# ==========================================
# 1. CARGAR TECNOLOGIA
# ==========================================

puts "\n[clock format [clock seconds]] - Cargando tecnologia"

read_lef -tech -library  $TECH_LEF

# ==========================================
# 2. CARGAR CELDAS ESTANDAR
# ==========================================

read_lef -library $CELL_LEF

# ==========================================
# 3. CARGAR BIBLIOTECA DE TIMING
# ==========================================

read_liberty $LIB

# ==========================================
# 4. CARGAR NETLIST
# ==========================================

read_verilog $NETLIST

link_design $TOP

# ==========================================
# 5. VERIFICAR BASE DE DATOS
# ==========================================

set block [ord::get_db_block]

set instances [$block getInsts]

puts "\n================================="
puts "IMPORTACION COMPLETADA"
puts "================================="

puts "Diseño: $TOP"
puts "Instancias: [llength $instances]"

# ==========================================
# 6. GUARDAR BASE DE DATOS
# ==========================================

write_db results/physical/n4/direct_import.odb

puts "\nBase de datos guardada correctamente."

