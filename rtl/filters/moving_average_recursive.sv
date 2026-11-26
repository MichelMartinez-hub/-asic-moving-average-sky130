module moving_average_recursive #(
    parameter int DATA_W   = 12,
    parameter int WINDOW_N = 4
)(
    input  logic              clk,
    input  logic              rst_n,
    input  logic              enable,
    input  logic              in_valid,
    input  logic [DATA_W-1:0] in_data,

    output logic              out_valid,
    output logic [DATA_W-1:0] out_data
);

    // --------------------------------------------------
    // 1. Parametros internos
    // --------------------------------------------------

    localparam int LEVELS  = $clog2(WINDOW_N);
    localparam int ACC_W   = DATA_W + LEVELS;
    localparam int COUNT_W = $clog2(WINDOW_N + 1);

    // --------------------------------------------------
    // 2. Historial de muestras
    // --------------------------------------------------

    logic [DATA_W-1:0] history [0:WINDOW_N-1];

    logic [COUNT_W-1:0] accepted_count;

    // --------------------------------------------------
    // 3. Acumulador recursivo
    // --------------------------------------------------

    logic [ACC_W-1:0] running_sum;
    logic [ACC_W-1:0] outgoing_sample;
    logic [ACC_W-1:0] next_sum;

    // Muestra que abandona la ventana

    assign outgoing_sample =
        (accepted_count == COUNT_W'(WINDOW_N))
        ? ACC_W'(history[WINDOW_N-1])
        : '0;

    // Actualizacion de la suma

    assign next_sum =
        (running_sum - outgoing_sample)
        + ACC_W'(in_data);

    // --------------------------------------------------
    // 4. Logica secuencial
    // --------------------------------------------------

    always_ff @(posedge clk) begin

        if (!rst_n) begin

            accepted_count <= '0;
            running_sum    <= '0;

            out_valid <= 1'b0;
            out_data  <= '0;

            for (int i = 0; i < WINDOW_N-1; i++) begin
                history[i] <= '0;
            end

        end
        else begin

            out_valid <= 1'b0;

            if (enable && in_valid) begin

                // Actualizar historial
                for (int i = WINDOW_N-1; i > 0; i--) begin
                    history[i] <= history[i-1];
                end

                history[0] <= in_data;

                // Actualizar acumulador
                running_sum <= next_sum;

                // Contador de muestras
                if (accepted_count < COUNT_W'(WINDOW_N)) begin
                    accepted_count <= accepted_count + 1'b1;
                end

                // Generar salida cuando la ventana este llena
                if (accepted_count >= COUNT_W'(WINDOW_N-1)) begin

                    out_data <= next_sum[ACC_W-1:LEVELS];

                    out_valid <= 1'b1;

                end

            end

        end

    end

endmodule
