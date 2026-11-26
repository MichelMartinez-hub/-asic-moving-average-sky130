module tb_filter_equivalence #(
    parameter int DATA_W   = 12,
    parameter int WINDOW_N = 4
);

    // -----------------------------------------
    // 1. Señales de entrada
    // -----------------------------------------

    logic clk = 0;
    logic rst_n = 0;
    logic enable = 0;
    logic in_valid = 0;
    logic [DATA_W-1:0] in_data = '0;

    // -----------------------------------------
    // 2. Salidas de ambas arquitecturas
    // -----------------------------------------

    logic direct_valid;
    logic recursive_valid;

    logic [DATA_W-1:0] direct_data;
    logic [DATA_W-1:0] recursive_data;

    // -----------------------------------------
    // 3. Modelo matemático independiente
    // -----------------------------------------

    int unsigned ref_history [0:WINDOW_N-1];

    int unsigned ref_accepted = 0;
    int unsigned test_cycles = 0;

    int unsigned rng = 32'h12345678;

    // Reloj de simulación
    always #5 clk = ~clk;

    // -----------------------------------------
    // 4. Arquitectura directa
    // -----------------------------------------

    moving_average_direct #(
        .DATA_W(DATA_W),
        .WINDOW_N(WINDOW_N)
    ) dut_direct (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .in_valid(in_valid),
        .in_data(in_data),
        .out_valid(direct_valid),
        .out_data(direct_data)
    );

    // -----------------------------------------
    // 5. Arquitectura recursiva
    // -----------------------------------------

    moving_average_recursive #(
        .DATA_W(DATA_W),
        .WINDOW_N(WINDOW_N)
    ) dut_recursive (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .in_valid(in_valid),
        .in_data(in_data),
        .out_valid(recursive_valid),
        .out_data(recursive_data)
    );

    // -----------------------------------------
    // 6. Reinicio
    // -----------------------------------------

    task automatic reset_dut();

        @(negedge clk);

        rst_n    = 0;
        enable   = 0;
        in_valid = 0;
        in_data  = '0;

        ref_accepted = 0;

        for (int j = 0; j < WINDOW_N; j++)
            ref_history[j] = 0;

        repeat (2) @(posedge clk);

        #1;

        if (direct_valid !== 0 ||
            recursive_valid !== 0 ||
            direct_data !== '0 ||
            recursive_data !== '0)
        begin
            $fatal(1, "ERROR: reinicio incorrecto");
        end

        @(negedge clk);
        rst_n = 1;

    endtask

    // -----------------------------------------
    // 7. Aplicar muestra y comprobar resultados
    // -----------------------------------------

    task automatic step(
        input bit en,
        input bit valid,
        input logic [DATA_W-1:0] sample
    );

        int unsigned sum;
        int unsigned expected;

        bit expected_valid;

        @(negedge clk);

        enable   = en;
        in_valid = valid;
        in_data  = sample;

        @(posedge clk);

        expected_valid = 0;
        expected = 0;
        sum = 0;

        if (en && valid) begin

            // Actualizar modelo independiente
            for (int j = WINDOW_N-1; j > 0; j--)
                ref_history[j] = ref_history[j-1];

            ref_history[0] = 32'(sample);

            if (ref_accepted < WINDOW_N)
                ref_accepted++;

            if (ref_accepted == WINDOW_N) begin

                for (int j = 0; j < WINDOW_N; j++)
                    sum += ref_history[j];

                expected = sum / WINDOW_N;
                expected_valid = 1;

            end

        end

        #1;

        test_cycles++;

        // Comprobar señales de validez
        if (direct_valid !== expected_valid ||
            recursive_valid !== expected_valid)
        begin
            $fatal(1,
                "N=%0d ciclo=%0d: error de validez",
                WINDOW_N, test_cycles
            );
        end

        // Comparar resultados cuando son válidos
        if (expected_valid) begin

            if (direct_data !== DATA_W'(expected))
                $fatal(1,
                    "DIRECT ERROR: N=%0d ciclo=%0d esperado=%0d obtenido=%0d",
                    WINDOW_N, test_cycles,
                    expected, direct_data
                );

            if (recursive_data !== DATA_W'(expected))
                $fatal(1,
                    "RECURSIVE ERROR: N=%0d ciclo=%0d esperado=%0d obtenido=%0d",
                    WINDOW_N, test_cycles,
                    expected, recursive_data
                );

            if (direct_data !== recursive_data)
                $fatal(1,
                    "ERROR: arquitecturas no equivalentes"
                );

        end

    endtask

    // -----------------------------------------
    // 8. Campaña de pruebas
    // -----------------------------------------

    initial begin

        reset_dut();

        // Prueba A: valores máximos
        repeat (WINDOW_N + 2)
            step(1, 1, {DATA_W{1'b1}});

        // Prueba B: ceros
        repeat (WINDOW_N + 2)
            step(1, 1, '0);

        // Prueba C: pausas
        repeat (10) begin
            step(1, 0, DATA_W'(1000));
            step(0, 1, DATA_W'(2000));
        end

        // Prueba D: reinicio
        reset_dut();

        // Prueba E: 10 000 muestras aleatorias
        for (int i = 0; i < 10000; i++) begin

            rng ^= rng << 13;
            rng ^= rng >> 17;
            rng ^= rng << 5;

            // Pausas intercaladas
            if (rng[2:0] == 0)
                step(0, 1, DATA_W'(rng));

            if (rng[5:3] == 0)
                step(1, 0, DATA_W'(rng));

            // Muestra aceptada
            step(1, 1, DATA_W'(rng));

            // Reinicio a mitad de campaña
            if (i == 5000)
                reset_dut();

        end

        $display(
            "PASS: N=%0d, %0d ciclos verificados, 10000 muestras aleatorias aceptadas",
            WINDOW_N, test_cycles
        );

        $finish;

    end

endmodule
