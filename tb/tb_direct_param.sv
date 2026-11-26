module tb_direct_param #(
    parameter int DATA_W   = 12,
    parameter int WINDOW_N = 4
);

    logic clk = 0;
    logic rst_n = 0;
    logic enable = 0;
    logic in_valid = 0;

    logic [DATA_W-1:0] in_data = 0;
    logic [DATA_W-1:0] out_data;
    logic out_valid;

    // Modelo de referencia
    int unsigned ref_history [0:WINDOW_N-1];
    int unsigned accepted = 0;
    int unsigned tests = 0;
    int unsigned rng = 32'h12345678;

    always #5 clk = ~clk;

    // Circuito bajo prueba
    moving_average_direct #(
        .DATA_W(DATA_W),
        .WINDOW_N(WINDOW_N)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .in_valid(in_valid),
        .in_data(in_data),
        .out_valid(out_valid),
        .out_data(out_data)
    );

    // Aplicar una muestra y verificar resultado
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
        sum = 0;
        expected = 0;

        if (en && valid) begin

            // Actualizar historial de referencia
            for (int j = WINDOW_N-1; j > 0; j--)
                ref_history[j] = ref_history[j-1];

            ref_history[0] =32'(sample);

            accepted++;

            if (accepted >= WINDOW_N) begin

                for (int j = 0; j < WINDOW_N; j++)
                    sum += ref_history[j];

                expected = sum / WINDOW_N;
                expected_valid = 1;

            end

        end

        #1;

        tests++;

        if (out_valid !== expected_valid)
            $fatal(1,
                "N=%0d Test=%0d: out_valid incorrecto",
                WINDOW_N, tests
            );

        if (expected_valid && out_data !== DATA_W'(expected))
            $fatal(1,
                "N=%0d Test=%0d: esperado=%0d obtenido=%0d",
                WINDOW_N, tests, expected, out_data
            );

    endtask

    initial begin

        // Reiniciar DUT y referencia
        for (int j = 0; j < WINDOW_N; j++)
            ref_history[j] = 0;

        repeat (2) @(negedge clk);
        rst_n = 1;

        // Prueba 1: llenar ventana con valor maximo
        repeat (WINDOW_N)
            step(1, 1, {DATA_W{1'b1}});

        // Prueba 2: entradas en cero
        repeat (WINDOW_N)
            step(1, 1, '0);

        // Prueba 3: pausas de adquisicion
        repeat (10) begin
            step(1, 0, 12'd1000);
            step(0, 1, 12'd2000);
        end

        // Prueba 4: secuencia pseudoaleatoria
        for (int i = 0; i < 2000; i++) begin

            rng ^= rng << 13;
            rng ^= rng >> 17;
            rng ^= rng << 5;

            step(
                rng[6:4] != 3'b000,
                rng[8:7] != 2'b00,
                DATA_W'(rng)
            );

        end

        $display(
            "PASS: N=%0d, %0d ciclos verificados",
            WINDOW_N, tests
        );

        $finish;

    end

endmodule
