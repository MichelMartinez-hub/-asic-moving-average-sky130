module moving_average_direct #(
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

    logic [DATA_W-1:0] history [0:WINDOW_N-2];

    logic [COUNT_W-1:0] accepted_count;

    // --------------------------------------------------
    // 3. Arbol combinacional de sumadores
    // --------------------------------------------------

     // Nodos de entrada del arbol
for (genvar i = 0; i < WINDOW_N; i++) begin : g_leaf

    wire [ACC_W-1:0] value;

    if (i == 0) begin
        assign value = ACC_W'(in_data);
    end
    else begin
        assign value = ACC_W'(history[i-1]);
    end

end

// Niveles del arbol
for (genvar level = 0; level < LEVELS; level++)
begin : g_level

    for (genvar j = 0;
         j < (WINDOW_N >> (level + 1));
         j++)
    begin : g_node

        wire [ACC_W-1:0] sum;

        if (level == 0) begin

            assign sum =
                g_leaf[2*j].value +
                g_leaf[2*j+1].value;

        end
        else begin

            assign sum =
                g_level[level-1].g_node[2*j].sum +
                g_level[level-1].g_node[2*j+1].sum;

        end

    end

end

    // --------------------------------------------------
    // 4. Logica secuencial
    // --------------------------------------------------

    always_ff @(posedge clk) begin

        if (!rst_n) begin

            accepted_count <= '0;
            out_valid      <= 1'b0;
            out_data       <= '0;

            for (int i = 0; i < WINDOW_N-1; i++) begin
                history[i] <= '0;
            end

        end
        else begin

            out_valid <= 1'b0;

            if (enable && in_valid) begin

                // Desplazar historial
                for (int i = WINDOW_N-2; i > 0; i--) begin
                    history[i] <= history[i-1];
                end

                history[0] <= in_data;

                // Contar muestras aceptadas
                if (accepted_count < COUNT_W'(WINDOW_N)) begin
                    accepted_count <= accepted_count + 1'b1;
                end

                // Generar salida cuando la ventana este llena
                if (accepted_count >= COUNT_W'(WINDOW_N-1)) begin

                    out_data <=
                          g_level[LEVELS-1].g_node[0].sum[ACC_W-1:LEVELS];

                    out_valid <= 1'b1;

                end

            end

        end

    end

endmodule
