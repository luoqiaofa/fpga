`timescale 1ns / 1ps
module iobuf(
    input        T,
    inout  wire  IO,
    input  wire  I,
    output wire  O
);

assign IO = T ? 1'bz : I;
assign O = IO;
endmodule
