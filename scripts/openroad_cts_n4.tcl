# ==========================================
# ASIC Moving Average
# Clock Tree Synthesis - Direct N=4
# SKY130 HD
# ==========================================

# 1. Cargar diseño optimizado
read_db results/physical/n4/direct_repaired.odb

# 2. Cargar biblioteca
set LIB "/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"

read_liberty $LIB

# Excluir celdas incompatibles con el flujo fisico
set_dont_use {
    sky130_fd_sc_hd__probe_p_8
    sky130_fd_sc_hd__probec_p_8
}

# 3. Cargar restricciones
read_sdc constraints/sta_preplacement.sdc

# 4. Configurar modelos RC
set_wire_rc -signal -layer met2
set_wire_rc -clock -layer met3

estimate_parasitics -placement

# 5. Registrar instancias iniciales
set block [ord::get_db_block]
set instances_before [llength [$block getInsts]]

puts "\n================================="
puts "INICIANDO CLOCK TREE SYNTHESIS"
puts "================================="

# 6. Construir árbol de reloj
clock_tree_synthesis \
    -buf_list {
        sky130_fd_sc_hd__clkbuf_1
        sky130_fd_sc_hd__clkbuf_2
        sky130_fd_sc_hd__clkbuf_4
        sky130_fd_sc_hd__clkbuf_8
    } \
    -root_buf sky130_fd_sc_hd__clkbuf_4

# 7. Legalizar buffers insertados
detailed_placement
check_placement -verbose

# 8. Actualizar conexiones globales de alimentación
global_connect

# 9. Utilizar reloj propagado
set_propagated_clock [all_clocks]

# 10. Recalcular parasíticos estimados
estimate_parasitics -placement

# 11. Reportar resultados CTS
puts "\n================================="
puts "RESULTADOS CTS"
puts "================================="

report_cts

set instances_after [llength [$block getInsts]]

puts "Instancias antes: $instances_before"
puts "Instancias despues: $instances_after"
puts "Instancias añadidas: [expr {$instances_after - $instances_before}]"

# 12. Analizar temporización
puts "\n================================="
puts "SETUP POST-CTS"
puts "================================="

report_worst_slack -max

puts "\n================================="
puts "HOLD POST-CTS"
puts "================================="

report_worst_slack -min

# 13. Guardar resultados
write_db results/physical/n4/direct_cts.odb
write_def results/physical/n4/direct_cts.def

puts "\nCLOCK TREE SYNTHESIS COMPLETADO"
