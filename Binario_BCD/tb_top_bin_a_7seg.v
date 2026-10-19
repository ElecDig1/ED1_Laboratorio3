/*
 * Banco de pruebas para top_bin_a_7seg: recorre las 16 entradas posibles.
 *   iverilog -g2012 -o sim tb_top_bin_a_7seg.v top_bin_a_7seg.v && vvp sim
 */
`timescale 1ns/1ps
module tb;
    reg clk = 0;
    always #10 clk = ~clk;

    reg  [3:0] X;
    wire [6:0] seg;
    wire [2:0] dig;
    wire       ERR;

    // Entradas invertidas como en la placa (pull-up)
    top_bin_a_7seg #(.CLK_HZ(1500), .CAMBIO_HZ(150)) dut (
        .clk(clk), .X0(~X[0]), .X1(~X[1]), .X2(~X[2]), .X3(~X[3]),
        .siete_seg(seg), .digito_sel(dig), .ERR(ERR)
    );

    function [7:0] ch(input [6:0] p);
        case (~p)
            7'h3F: ch = "0"; 7'h06: ch = "1"; 7'h5B: ch = "2"; 7'h4F: ch = "3";
            7'h66: ch = "4"; 7'h6D: ch = "5"; 7'h7D: ch = "6"; 7'h07: ch = "7";
            7'h7F: ch = "8"; 7'h6F: ch = "9"; 7'h79: ch = "E"; 7'h50: ch = "r";
            7'h00: ch = " "; default: ch = "?";
        endcase
    endfunction

    reg [23:0] obtenido, esperado;
    reg [7:0]  i0, i1, i2;
    integer n, errores;

    initial begin
        errores = 0;
        for (n = 0; n < 16; n = n + 1) begin
            X = n;
            repeat (25) @(posedge clk);
            @(posedge clk); while (dig !== 3'b110) @(posedge clk); #1 i0 = ch(seg);
            @(posedge clk); while (dig !== 3'b101) @(posedge clk); #1 i1 = ch(seg);
            @(posedge clk); while (dig !== 3'b011) @(posedge clk); #1 i2 = ch(seg);
            obtenido = {i2, i1, i0};
            esperado = (n > 9) ? "Err" : {"  ", 8'(48 + n)};
            $display("X = %b (%2d) -> [%s]  ERR=%b", X, n, obtenido, ERR);
            if (obtenido !== esperado || ERR !== (n > 9)) errores = errores + 1;
        end
        $display("%0d fallas de 16 casos", errores);
        $finish;
    end
endmodule
