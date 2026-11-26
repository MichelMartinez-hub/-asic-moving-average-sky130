# ==========================================
# ASIC Moving Average
# Floorplanning - Direct N=4
# SKY130 HD
# ==========================================

# 1. Cargar la base de datos anterior
read_db results/physical/n4/direct_import.odb

# ==========================================
# CARGAR BIBLIOTECA LIBERTY
# ==========================================

set LIB "/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"

read_liberty $LIB


# 2. Inicializar el floorplan
initialize_floorplan \
    -utilization 40 \
    -aspect_ratio 1.0 \
    -core_space 10.0 \
    -site unithd

# ==========================================
# INSERCION DE TIE CELLS
# ==========================================

puts "\n================================="
puts "INSERTANDO TIE CELLS"
puts "================================="

# Constante logica 0
insert_tiecells \
    sky130_fd_sc_hd__conb_1/LO \
    -prefix TIELO_

# Constante logica 1
insert_tiecells \
    sky130_fd_sc_hd__conb_1/HI \
    -prefix TIEHI_
# ==========================================
# PISTAS DE ENRUTAMIENTO SKY130 HD
# ==========================================

make_tracks li1 \
    -x_offset 0.23 -x_pitch 0.46 \
    -y_offset 0.17 -y_pitch 0.34

make_tracks met1 \
    -x_offset 0.17 -x_pitch 0.34 \
    -y_offset 0.17 -y_pitch 0.34

make_tracks met2 \
    -x_offset 0.23 -x_pitch 0.46 \
    -y_offset 0.23 -y_pitch 0.46

make_tracks met3 \
    -x_offset 0.34 -x_pitch 0.68 \
    -y_offset 0.34 -y_pitch 0.68

make_tracks met4 \
    -x_offset 0.46 -x_pitch 0.92 \
    -y_offset 0.46 -y_pitch 0.92

make_tracks met5 \
    -x_offset 1.70 -x_pitch 3.40 \
    -y_offset 1.70 -y_pitch 3.40

# 3. Obtener informacion fisica
set block [ord::get_db_block]

set die_area [ord::get_die_area]
set core_area [ord::get_core_area]

set rows [llength [$block getRows]]
set instances [llength [$block getInsts]]

# 4. Mostrar resultados
puts "\n================================="
puts "FLOORPLANNING COMPLETADO"
puts "================================="

puts "Arquitectura: Direct"
puts "Ventana: 4"
puts "Instancias: $instances"
puts "Filas de colocacion: $rows"

puts "Die area (um): $die_area"
puts "Core area (um): $core_area"

# 5. Guardar resultados
write_db results/physical/n4/direct_floorplan.odb

write_def results/physical/n4/direct_floorplan.def

puts "\nArchivos ODB y DEF generados."

