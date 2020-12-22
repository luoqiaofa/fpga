module spi_trx_one_char
#(parameter integer CHAR_LEN_MAX = 16)
(
    input  wire        S_SYSCLK,  // platform clock
    input  wire        S_RESETN,  // reset
    input  wire        S_ENABLE,  // enable
    input  wire        S_CPOL,    // clock polary
    input  wire        S_CPHA,    // clock phase, the first edge or second
    input  wire        S_LOOP,    // internal loopback mode
    input  wire        S_REV,     // msb first or lsb first
    input  wire [3:0]  S_CHAR_LEN,// characters in bits length
    input  wire        S_SPI_SCK,
    output wire        S_SPI_MISO,
    input  wire        S_SPI_MOSI,
    input  wire        S_CHAR_GO,
    output wire        S_CHAR_DONE,
    input  wire [15:0] S_WCHAR,   // output character
    output wire [15:0] S_RCHAR    // input character
);
`include "reg-bit-def.v"

reg sck_pos_edge;
reg sck_neg_edge;

spi_clk_gen # (.N(8)) clk_gen (
    .sysclk(sysclk),       // system clock input
    .rst_n(rst_n),         // module reset
    .enable(enable),       // module enable
    .go(go),               // start transmit
    .CPOL(CPOL),           // clock polarity
    .last_clk(last_clk),   // last clock 
    .divider_i(divider_i), // divider;
    .clk_out(clk_out),     // clock output
    .pos_edge(pos_edge),   // positive edge flag
    .neg_edge(neg_edge)    // negtive edge flag
);

