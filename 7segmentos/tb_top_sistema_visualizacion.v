/*
 * Banco de pruebas exhaustivo para top_sistema_visualizacion
 * Prueba las 1024 combinaciones (A: 0..15, B: 0..15, 4 modos de signo)
 * leyendo los 3 displays tal como lo haría el ojo sobre la placa.
 *
 * Uso (Icarus Verilog):
 *   iverilog -g2012 -o sim tb_top_sistema_visualizacion.v top_sistema_visualizacion.v
 *   vvp sim
 *   # Modo con cero a la izquierda apagado:
 *   iverilog -g2012 -Ptb.Z=1 -o sim tb_top_sistema_visualizacion.v top_sistema_visualizacion.v
 */
`timescale 1ns/1ps
module tb;
    parameter Z = 0;                      // Valor de APAGAR_CERO_IZQ a probar

    reg clk = 0;
    always #10 clk = ~clk;

    reg  [3:0] A, B;
    reg        nA, nB;
    wire [6:0] seg;
    wire [2:0] dig;
    wire       SG;

    // Reloj reducido para que la simulación sea rápida.
    // Las entradas se aplican invertidas, igual que en la placa (pull-up).
    top_sistema_visualizacion #(
        .CLK_HZ(1500), .CAMBIO_HZ(150), .APAGAR_CERO_IZQ(Z)
    ) dut (
        .clk(clk),
        .A0(~A[0]), .A1(~A[1]), .A2(~A[2]), .A3(~A[3]),
        .B0(~B[0]), .B1(~B[1]), .B2(~B[2]), .B3(~B[3]),
        .nA(~nA), .nB(~nB),
        .siete_seg(seg), .digito_sel(dig), .SG(SG)
    );

    // Traduce el patrón físico (ánodo común) a un carácter
    function [7:0] ch(input [6:0] p);
        case (~p)
            7'h3F: ch = "0"; 7'h06: ch = "1"; 7'h5B: ch = "2"; 7'h4F: ch = "3";
            7'h66: ch = "4"; 7'h6D: ch = "5"; 7'h7D: ch = "6"; 7'h07: ch = "7";
            7'h7F: ch = "8"; 7'h6F: ch = "9"; 7'h40: ch = "-"; 7'h00: ch = " ";
            default: ch = "?";
        endcase
    endfunction

    reg [23:0] obtenido, esperado;
    reg [7:0]  s, d, u;
    integer i, j, k, errores, r, m;

    initial begin
        errores = 0;
        for (k = 0; k < 4; k = k + 1)
        for (i = 0; i < 16; i = i + 1)
        for (j = 0; j < 16; j = j + 1) begin
            A = i; B = j; nA = k[0]; nB = k[1];
            repeat (25) @(posedge clk);                      // espera sincronizadores

            @(posedge clk); while (dig !== 3'b110) @(posedge clk); #1 u = ch(seg);
            @(posedge clk); while (dig !== 3'b101) @(posedge clk); #1 d = ch(seg);
            @(posedge clk); while (dig !== 3'b011) @(posedge clk); #1 s = ch(seg);
            obtenido = {s, d, u};

            r = (nA ? -i : i) + (nB ? -j : j);
            m = (r < 0) ? -r : r;
            if (Z && m < 10) esperado = {" ", (r < 0) ? "-" : " ", 8'(48 + m)};
            else             esperado = {(r < 0) ? "-" : " ", 8'(48 + m/10), 8'(48 + m%10)};

            if (obtenido !== esperado || SG !== (r < 0)) begin
                if (errores < 10)
                    $display("FALLA %s%0d %s%0d = %0d: muestra '%s', esperado '%s'",
                             nA ? "-" : "+", i, nB ? "-" : "+", j, r, obtenido, esperado);
                errores = errores + 1;
            end
        end
        $display("APAGAR_CERO_IZQ=%0d -> %0d fallas de 1024 casos", Z, errores);
        $finish;
    end
endmodule
