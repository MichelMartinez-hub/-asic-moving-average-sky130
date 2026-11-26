# ==========================================
# STA PARAMETRIZABLE
# ASIC Moving Average - SKY130
# ==========================================

# Parametros recibidos desde Bash
set ARCH $::env(ARCH)
set N $::env(N)

# Biblioteca Liberty
set LIB "/foss/pdks/ciel/sky130/versions/1689ac3f2dc763876eaf967227c7dfe831b031ae/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"

# Seleccionar nombre de netlist
if {$N == 4} {
    set SUFFIX "_sky130_filtered"
} else {
    set SUFFIX "_sky130"
}

set NETLIST "results/synthesis/n${N}/${ARCH}${SUFFIX}.v"

set TOP "moving_average_${ARCH}"

# Comprobar archivos
if {![file exists $LIB]} {
    error "Biblioteca Liberty no encontrada"
}

if {![file exists $NETLIST]} {
    error "Netlist no encontrada: $NETLIST"
}

# Cargar tecnologia y netlist
read_liberty $LIB
read_verilog $NETLIST

# Establecer modulo principal
link_design $TOP

# Aplicar restricciones temporales
read_sdc constraints/sta_preplacement.sdc

# Revisar configuracion
check_setup

# Reportar ruta critica
puts "\n================================="
puts "ARQUITECTURA: $ARCH"
puts "VENTANA: $N"
puts "================================="

report_checks \
    -path_delay max \
    -group_path_count 1 \
    -format full

# Peor margen temporal
puts "\n================================="
puts "WORST SLACK"
puts "================================="

report_worst_slack -max

# ==========================================
# ANALISIS DE FANOUT Y CAPACITANCIA
# ==========================================

puts "\n================================="
puts "FANOUT Y CARGA DE RUTA CRITICA"
puts "================================="

report_checks \
    -path_delay max \
    -group_path_count 1 \
    -fields {slew cap fanout} \
    -format full
# ==========================================
# ANALISIS REGISTRO A REGISTRO
# ==========================================

puts "\n================================="
puts "RUTA CRITICA REGISTRO A REGISTRO"
puts "================================="

# Obtener pines de los registros
set REG_CLK  [all_registers -clock_pins]
set REG_DATA [all_registers -data_pins]

# Analizar solamente rutas internas
report_checks \
    -from $REG_CLK \
    -to $REG_DATA \
    -path_delay max \
    -group_path_count 1 \
    -fields {slew cap fanout} \
    -format full
# ==========================================
# REALIMENTACION DEL ACUMULADOR
# Arquitectura recursiva, N = 32
# ==========================================

if {$ARCH eq "recursive" && $N == 32} {

    puts "\n================================="
    puts "REALIMENTACION RUNNING_SUM"
    puts "================================="

    report_checks \
        -from [get_pins _2982_/CLK] \
        -to [get_pins _2997_/D] \
        -path_delay max \
        -group_path_count 1 \
        -fields {slew cap fanout} \
        -format full
}

# ==========================================
# PEOR RUTA DE REALIMENTACION DEL ACUMULADOR
# ==========================================

if {$ARCH eq "recursive" && $N == 32} {

    puts "\n================================="
    puts "PEOR REALIMENTACION DEL ACUMULADOR"
    puts "================================="

    # Construir listas de pines de los 16 registros
    set acc_clk_pins {}
    set acc_data_pins {}

    for {set i 2982} {$i <= 2997} {incr i} {

        lappend acc_clk_pins "_${i}_/CLK"
        lappend acc_data_pins "_${i}_/D"

    }

    # Buscar la peor ruta entre los registros
    report_checks \
        -from [get_pins $acc_clk_pins] \
        -to [get_pins $acc_data_pins] \
        -path_delay max \
        -group_path_count 1 \
        -fields {slew cap fanout} \
        -format full
}

# ==========================================
# AUDITORIA DE RESTRICCIONES TEMPORALES
# ==========================================

puts "\n================================="
puts "VERIFICACION DE RESTRICCIONES"
puts "================================="

check_setup -verbose


# ==========================================
# ANALISIS HOLD
# ==========================================

puts "\n================================="
puts "PEOR RUTA HOLD"
puts "================================="

report_checks \
    -path_delay min \
    -group_path_count 1 \
    -format full

puts "\n================================="
puts "WORST HOLD SLACK"
puts "================================="

report_worst_slack -min
