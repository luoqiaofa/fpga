module spi_one_char
#(CHAR_LEN_MAX = 16)
(
    input                          sysclk,
    input                          reset_n,
    input                          enable,
    input                          CPOL,
    input                          CPHA,
    input                          LOOP,
    input                          CHAR_EN, // characters in bits length
    input  wire                    SCK,
    output wire                    MISO,
    input  wire                    MOSI,
    input                          sck_pos_edge,
    input                          sck_neg_edge,
    input                          go,
    output                         done,
    input       [CHAR_LEN_MAX-1:0] data_out,
    output reg  [CHAR_LEN_MAX-1:0] data_in,
);
`include "reg-bit-def.v"

