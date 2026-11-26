# ==========================================
# ASIC MOVING AVERAGE
# POST-ROUTING PVT ANALYSIS
# Direct N=4 - SKY130 HD
# ==========================================

set ROOT "results/physical/n4"

set LIB_DIR "/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib"
set RCX_DIR "/foss/pdks/sky130A/libs.tech/librelane"

# ==========================================
# 1. SELECCION DE ESQUINA
# ==========================================

if {![info exists ::env(PVT_CORNER)]} {
    error "Definir PVT_CORNER=ss o PVT_CORNER=ff"
}

set PVT $::env(PVT_CORNER)

switch -- $PVT {

    tt {
        set LIB "$LIB_DIR/sky130_fd_sc_hd__tt_025C_1v80.lib"
        set RCX "$RCX_DIR/rules.openrcx.sky130A.nom.calibre"
        set RC_CORNER "nom"
    }

    ss {
        set LIB "$LIB_DIR/sky130_fd_sc_hd__ss_100C_1v60.lib"
        set RCX "$RCX_DIR/rules.openrcx.sky130A.max.calibre"
        set RC_CORNER "max"
    }

    ff {
        set LIB "$LIB_DIR/sky130_fd_sc_hd__ff_n40C_1v95.lib"
        set RCX "$RCX_DIR/rules.openrcx.sky130A.min.calibre"
        set RC_CORNER "min"
    }

    default {
        error "Esquina no soportada: $PVT"
    }
}

# ==========================================
# 2. VERIFICACION DE ARCHIVOS
# ==========================================

foreach FILE [list $LIB $RCX] {
    if {![file isfile $FILE]} {
        error "Archivo no encontrado: $FILE"
    }
}

# ==========================================
# 3. CARGAR DISENO
# ==========================================

read_db $ROOT/direct_ff_detailed_route.odb

read_liberty $LIB

read_sdc constraints/sta_preplacement.sdc

set_propagated_clock [all_clocks]

# ==========================================
# 4. EXTRACCION RC
# ==========================================

puts "\n================================="
puts "EXTRACCION RC: $PVT / $RC_CORNER"
puts "================================="

define_process_corner -ext_model_index 0 X

extract_parasitics -ext_model_file $RCX

set SPEF "$ROOT/direct_ff_candidate_${PVT}_${RC_CORNER}.spef"

write_spef $SPEF

read_spef $SPEF

# ==========================================
# 5. ANALISIS TEMPORAL
# ==========================================

puts "\n================================="
puts "SETUP - $PVT / $RC_CORNER"
puts "================================="

report_worst_slack -max

puts "\n================================="
puts "HOLD - $PVT / $RC_CORNER"
puts "================================="

report_worst_slack -min

# ==========================================
# DIAGNOSTICO DE RUTAS DE HOLD
# ==========================================

puts "\n================================="
puts "RUTAS CRITICAS DE HOLD - $PVT"
puts "================================="

report_checks \
    -path_delay min \
    -group_path_count 5 \
    -fields {slew capacitance fanout} \
    -format full_clock_expanded \
    -digits 4

puts "\n================================="
puts "TOTAL NEGATIVE SLACK"
puts "================================="

puts "\nTNS SETUP"
report_tns -max

puts "\nTNS HOLD"
report_tns -min

puts "\n================================="
puts "ANALISIS $PVT / $RC_CORNER COMPLETADO"
puts "================================="
