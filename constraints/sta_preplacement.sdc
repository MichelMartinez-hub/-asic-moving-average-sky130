# ------------------------------------------
# Restricciones temporales preliminares
# ASIC Moving Average - SKY130
# ------------------------------------------

# Reloj principal: 50 MHz
create_clock -name core_clk \
    -period 20.0 [get_ports clk]

# Incertidumbre del reloj: 0.2 ns
set_clock_uncertainty -setup 0.2 \
    [get_clocks core_clk]

# Retardo externo de entrada
set_input_delay -clock core_clk -max 1.0 \
    [get_ports {in_data* in_valid enable rst_n}]

set_input_delay -clock core_clk -min 0.0 \
    [get_ports {in_data* in_valid enable rst_n}]

# Retardo externo de salida
set_output_delay -clock core_clk -max 1.0 \
    [get_ports {out_data* out_valid}]

set_output_delay -clock core_clk -min 0.0 \
    [get_ports {out_data* out_valid}]

# Carga capacitiva de salida: 0.02 pF
set_load 0.02 \
    [get_ports {out_data* out_valid}]
