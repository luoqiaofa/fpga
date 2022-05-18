`include "timescale.v"

module spi_slave_model
#(parameter integer CHAR_NBITS = 16)
(
    input  wire        S_SYSCLK,  // platform clock
    input  wire        S_RESETN,  // reset
    input  wire        S_ENABLE,  // enable
    input  wire        S_CPOL,    // clock polary
    input  wire        S_CPHA,    // clock phase, the first edge or second
    input  wire        S_CSPOL,   // cs polary
    input  wire        S_REV,     // msb first or lsb first
    input  wire [3:0]  S_CHAR_LEN,// characters in bits length
    input  wire [31:0] S_WCHAR,   // output character, output to SPI_MISO
    output wire [31:0] S_RCHAR,   // output character, read from SPI_MOSI
    input  wire        S_SPI_CS,  // chip select, low active
    input  wire        S_SPI_SCK,
    output wire        S_SPI_MISO,
    input  wire        S_SPI_MOSI
);

wire [31:0] wdata;
reg [31:0] txdata[0:7];
wire [31:0] slv_data_rx;
assign wdata = txdata[tx_data_idx];

reg [15:0] tx_char_cnt;
wire [2:0] tx_data_idx;
wire slv_char_done;
wire slave_active;

assign slave_active = S_CSPOL ? (S_ENABLE & (~S_SPI_CS)) : (S_ENABLE & S_SPI_CS);

always @(posedge S_SYSCLK/* or negedge S_RESETN */)
begin
    if (1'b0 == S_RESETN || (1'b0 == slave_active))
    begin
        tx_char_cnt <= 0;
    end
    if (slv_char_done) begin
        tx_char_cnt <= tx_char_cnt + 1;
    end
end

spi_slave_trx_char #(.CHAR_NBITS(32))
spi_slv_dev
(
    .S_SYSCLK(S_SYSCLK),           // platform clock
    .S_RESETN(S_RESETN),           // reset
    .S_ENABLE(S_ENABLE),  // enable
    .S_CPOL(S_CPOL),  // clock polary
    .S_CPHA(S_CPHA),  // clock phase, the first edge or second
    .S_CSPOL(S_CSPOL),  // clock phase, the first edge or second
    .S_REV(S_REV),    // msb first or lsb first
    .S_CHAR_LEN(S_CHAR_LEN),             // characters in bits length
    .S_SPI_CS(S_SPI_CS),
    .S_SPI_SCK(S_SPI_SCK),
    .S_SPI_MISO(S_SPI_MISO),
    .S_SPI_MOSI(S_SPI_MOSI),
    .S_CHAR_DONE(slv_char_done),
    .S_WCHAR(wdata),        // output character
    .S_RCHAR(slv_data_rx)          // input character
);

assign tx_data_idx = S_CHAR_LEN > 7 ? tx_char_cnt[3:1] : tx_char_cnt[4:2];

initial
begin
    txdata[0]=32'h44332211;
    txdata[1]=32'h88776655;
    txdata[2]=32'hccbbaa99;
    txdata[3]=32'h00ffeedd;
    txdata[4]=32'h04030201;
    txdata[5]=32'h08070605;
    txdata[6]=32'h0c0b0a09;
    txdata[7]=32'h100f0e0d;
end

endmodule

