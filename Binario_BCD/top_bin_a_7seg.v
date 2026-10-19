/*
 * Visualizador de número binario de 4 bits en 7 segmentos
 *
 *   Entrada 0..9   -> muestra el dígito en el display de la derecha: "  7"
 *   Entrada 10..15 -> muestra el mensaje de error en los 3 displays: "Err"
 *
 *      [ izquierdo ][ centro ][ derecho ]
 *      digito_sel[2]   [1]       [0]
 *
 * FPGA: Cyclone IV EP4CE10E22C8 (reloj de 50 MHz), displays de ánodo común.
 */

// ==========================================
// 1. MÓDULO TOP
// ==========================================
module top_bin_a_7seg #(
    parameter CLK_HZ                = 50_000_000, // Reloj de la placa
    parameter CAMBIO_HZ             = 3_000,      // Cambios de display por segundo (1 kHz por display)
    parameter ENTRADAS_ACTIVAS_BAJO = 1,          // 1: switch en "bajo" = 0 lógico (entradas con pull-up)
    parameter SEG_ACTIVOS_BAJO      = 1,          // 1: ánodo común (segmento enciende con 0)
    parameter DIG_ACTIVOS_BAJO      = 1           // 1: selección de display activa en 0
)(
    input  wire       clk,
    input  wire       X0, input wire X1, input wire X2, input wire X3, // X0 = bit menos significativo
    output reg  [6:0] siete_seg,       // {g,f,e,d,c,b,a}
    output reg  [2:0] digito_sel,      // [0] = derecho, [1] = centro, [2] = izquierdo
    output reg        ERR              // LED de error (1 = número mayor a 9)
);

    // ------------------------------------------
    // Acondicionamiento de entradas: polaridad + sincronizador de 2 flip-flops
    // ------------------------------------------
    wire [3:0] entrada_pin = {X3, X2, X1, X0};
    wire [3:0] entrada_log = ENTRADAS_ACTIVAS_BAJO ? ~entrada_pin : entrada_pin;

    reg  [3:0] sinc_1 = 4'd0, sinc_2 = 4'd0;
    always @(posedge clk) begin
        sinc_1 <= entrada_log;
        sinc_2 <= sinc_1;
    end

    wire [3:0] numero = sinc_2;
    wire       error  = (numero > 4'd9);

    // ------------------------------------------
    // Selección de símbolos para cada display
    // ------------------------------------------
    localparam [3:0] LETRA_E = 4'hB, LETRA_R = 4'hC, APAGADO = 4'hF;

    wire [3:0] sim_der    = error ? LETRA_R : numero;
    wire [3:0] sim_centro = error ? LETRA_R : APAGADO;
    wire [3:0] sim_izq    = error ? LETRA_E : APAGADO;

    wire [6:0] seg_der, seg_centro, seg_izq;

    decodificador_7seg u_dec_der    (.simbolo(sim_der),    .seg(seg_der));
    decodificador_7seg u_dec_centro (.simbolo(sim_centro), .seg(seg_centro));
    decodificador_7seg u_dec_izq    (.simbolo(sim_izq),    .seg(seg_izq));

    // ------------------------------------------
    // Base de tiempo para el multiplexado
    // ------------------------------------------
    localparam integer DIV   = CLK_HZ / CAMBIO_HZ;          // ~16 667 ciclos a 50 MHz
    localparam integer ANCHO = (DIV > 1) ? $clog2(DIV) : 1;

    reg [ANCHO-1:0] contador = 0;
    reg [1:0]       sel      = 2'd0;   // 0 = derecho, 1 = centro, 2 = izquierdo

    always @(posedge clk) begin
        if (contador == DIV - 1) begin
            contador <= 0;
            sel      <= (sel == 2'd2) ? 2'd0 : sel + 1'b1;
        end else begin
            contador <= contador + 1'b1;
        end
    end

    // ------------------------------------------
    // Multiplexor con salidas registradas (sin glitches)
    // ------------------------------------------
    reg [6:0] seg_act;
    reg [2:0] dig_act;

    always @(*) begin
        case (sel)
            2'd0:    begin seg_act = seg_der;    dig_act = 3'b001; end
            2'd1:    begin seg_act = seg_centro; dig_act = 3'b010; end
            default: begin seg_act = seg_izq;    dig_act = 3'b100; end
        endcase
    end

    always @(posedge clk) begin
        siete_seg  <= SEG_ACTIVOS_BAJO ? ~seg_act : seg_act;
        digito_sel <= DIG_ACTIVOS_BAJO ? ~dig_act : dig_act;
        ERR        <= error;
    end

endmodule


// ==========================================
// 2. DECODIFICADOR 7 SEGMENTOS (activo en alto)
// ==========================================
// Salida {g,f,e,d,c,b,a}. Símbolos extra: B = 'E', C = 'r', F = apagado.
//
//      a
//    f   b
//      g
//    e   c
//      d
module decodificador_7seg (
    input  wire [3:0] simbolo,
    output reg  [6:0] seg
);
    always @(*) begin
        case (simbolo)               //  gfedcba
            4'd0:    seg = 7'b0111111;
            4'd1:    seg = 7'b0000110;
            4'd2:    seg = 7'b1011011;
            4'd3:    seg = 7'b1001111;
            4'd4:    seg = 7'b1100110;
            4'd5:    seg = 7'b1101101;
            4'd6:    seg = 7'b1111101;
            4'd7:    seg = 7'b0000111;
            4'd8:    seg = 7'b1111111;
            4'd9:    seg = 7'b1101111;
            4'hB:    seg = 7'b1111001;   // E  (a, d, e, f, g)
            4'hC:    seg = 7'b1010000;   // r  (e, g)
            default: seg = 7'b0000000;   // apagado
        endcase
    end
endmodule
