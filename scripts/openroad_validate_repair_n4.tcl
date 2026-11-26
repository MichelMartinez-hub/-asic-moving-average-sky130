# ==========================================
# Validacion post-repair - Direct N=4
# ==========================================

read_db results/physical/n4/direct_repaired.odb

set LIB "/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"

read_liberty $LIB
read_sdc constraints/sta_preplacement.sdc

set_wire_rc -signal -layer met2
set_wire_rc -clock -layer met3

estimate_parasitics -placement

puts "\n=== VERIFICACION ELECTRICA ==="

report_check_types \
    -max_slew \
    -max_capacitance \
    -max_fanout \
    -violators

puts "\n=== VERIFICACION DE PLACEMENT ==="

check_placement -verbose

puts "\n=== METRICAS FINALES ==="

set block [ord::get_db_block]

puts "Instancias totales: [llength [$block getInsts]]"

report_design_area

report_worst_slack -max
report_worst_slack -min
