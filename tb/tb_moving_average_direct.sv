module tb_moving_average_direct;

    // -----------------------------------------
    // 1. Señales del testbench
    // -----------------------------------------

    logic clk = 0;
    logic rst_n;
    logic enable;
    logic in_valid;
    logic [11:0] in_data;

    logic out_valid;
    logic [11:0] out_data;

    int test_count = 0;

    // -----------------------------------------
    // 2. Generación del reloj
    // -----------------------------------------

    always #5 clk = ~clk;

    // -----------------------------------------
    // 3. Instancia del DUT
    // -----------------------------------------

    moving_average_direct #(
        .DATA_W(12),
        .WINDOW_N(4)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .in_valid(in_valid),
        .in_data(in_data),
        .out_valid(out_valid),
        .out_data(out_data)
    );

    // -----------------------------------------
    // 4. Tarea para aplicar muestras
    // -----------------------------------------

    task automatic apply_cycle(
        input bit en,
        input bit valid,
        input logic [11:0] sample,
        input bit expected_valid,
        input logic [11:0] expected_data
    );

        @(negedge clk);

        enable   = en;
        in_valid = valid;
        in_data  = sample;

        @(posedge clk);
        #1;

        test_count++;

        if (out_valid !== expected_valid) begin
            $fatal(1,
                "ERROR prueba %0d: out_valid=%b esperado=%b",
                test_count, out_valid, expected_valid
            );
        end

        if (expected_valid && out_data !== expected_data) begin
            $fatal(1,
                "ERROR prueba %0d: resultado=%0d esperado=%0d",
                test_count, out_data, expected_data
            );
        end

    endtask

    // -----------------------------------------
    // 5. Secuencia de pruebas
    // -----------------------------------------

    initial begin
        
       // Generar archivo de formas de onda
       $dumpfile("results/sim_direct_n4/direct_n4.vcd");
       $dumpvars(0, tb_moving_average_direct);
        rst_n    = 0;
        enable   = 0;
        in_valid = 0;
        in_data  = 0;

        // Reinicio inicial
        repeat (2) @(posedge clk);
        #1;

        rst_n = 1;

        // Llenado de ventana
        apply_cycle(1, 1, 1000, 0, 0);
        apply_cycle(1, 1, 2000, 0, 0);
        apply_cycle(1, 1, 3000, 0, 0);

        // Primera salida válida
        apply_cycle(1, 1, 4000, 1, 2500);

        // Pausa por in_valid = 0
        apply_cycle(1, 0, 4095, 0, 0);

        // Pausa por enable = 0
        apply_cycle(0, 1, 4095, 0, 0);

        // Continuar adquisición
        apply_cycle(1, 1, 500, 1, 2375);
        apply_cycle(1, 1, 0,   1, 1875);

        // Reiniciar nuevamente
        @(negedge clk);

        rst_n    = 0;
        enable   = 0;
        in_valid = 0;

        @(posedge clk);
        #1;

        if (out_valid !== 0 || out_data !== 0) begin
            $fatal(1, "ERROR: reinicio incorrecto");
        end

        rst_n = 1;

        // Verificar valor máximo del ADC
        apply_cycle(1, 1, 4095, 0, 0);
        apply_cycle(1, 1, 4095, 0, 0);
        apply_cycle(1, 1, 4095, 0, 0);
        apply_cycle(1, 1, 4095, 1, 4095);

        $display("PASS: %0d ciclos verificados", test_count);

        $finish;

    end

endmodule
