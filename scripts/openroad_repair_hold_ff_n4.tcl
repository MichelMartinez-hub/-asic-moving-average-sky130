# ==========================================
# ASIC MOVING AVERAGE
# Hold Repair - FF Corner
# Direct N=4 - SKY130 HD
# ==========================================

set ROOT "results/physical/n4"

set LIB "/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ff_n40C_1v95.lib"

# ==========================================
# 1. CARGAR DISENO POST-CTS
# ==========================================

read_db $ROOT/direct_hold_repaired.odb

read_liberty $LIB

# Excluir celdas probe
set_dont_use {
    sky130_fd_sc_hd__probe_p_8
    sky130_fd_sc_hd__probec_p_8
}

read_sdc constraints/sta_preplacement.sdc

set_propagated_clock [all_clocks]

# ==========================================
# 2. ESTIMACION DE PARASITOS
# ==========================================

set_wire_rc -signal -layer met2
set_wire_rc -clock -layer met3

estimate_parasitics -placement

# ==========================================
# 3. TIMING ANTES DE REPARAR
# ==========================================

puts "\n================================="
puts "TIMING FF ANTES DE REPAIR"
puts "================================="

report_worst_slack -max
report_worst_slack -min

# ==========================================
# 4. REPARACION DE HOLD
# ==========================================

puts "\n================================="
puts "REPARANDO HOLD EN FF"
puts "================================="

repair_timing \
    -hold \
    -hold_margin 0.10 \
    -max_utilization 65

# ==========================================
# 5. LEGALIZACION
# ==========================================

detailed_placement

check_placement -verbose

global_connect

estimate_parasitics -placement

# ==========================================
# 6. TIMING DESPUES DE REPARAR
# ==========================================

puts "\n================================="
puts "TIMING FF DESPUES DE REPAIR"
puts "================================="

report_worst_slack -max
report_worst_slack -min

report_design_area

# ==========================================
# 7. GUARDAR CANDIDATO
# ==========================================

write_db $ROOT/direct_hold_ff_candidate.odb

write_def $ROOT/direct_hold_ff_candidate.def

puts "\nREPARACION FF COMPLETADA"
