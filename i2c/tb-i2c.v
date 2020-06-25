`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/05/28 17:57:09
// Design Name: 
// Module Name: div_test
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps


module tb_i2c;
    inout iic_sda;
    inout iic_scl;
    reg clk_i;
    reg rst_n_i;
    reg scl;
    reg sda;
    reg is_sda_lo;
    reg is_scl_lo;
    reg [7:0] tx_data;
    reg [2:0] bit_cnt;

    reg       I_rstn;
    reg       I_clk;
    wire      I_i2cscl;
    wire      I_i2csda;
    reg [7:0] I_i2cadr;
    reg [7:0] I_i2cfdr;
    reg [7:0] I_i2ccr;
    wire [7:0] I_i2csr;
    reg [7:0] I_i2cdr;
    reg [7:0] I_i2cdfsrr;
    reg I_wr_done ;
    reg [3:0] bytes_cnt;

    localparam NUM_BYTES_TX = 3;

`include "reg-bit-def.v"

i2c_master u1_i2c_master(
    .I_RSTN(I_rstn),
    .I_CLK(I_clk),
    .I_TXRX_DONE(I_wr_done),
    .I_I2CSCL(I_i2cscl),
    .I_I2CSDA(I_i2csda),
    .I_I2CADR(I_i2cadr),
    .I_I2CFDR(I_i2cfdr),
    .I_I2CCR(I_i2ccr),
    .I_I2CSR(I_i2csr),
    .I_I2CDR(I_i2cdr),
    .I_I2CDFSRR(I_i2cdfsrr)
);

always @(posedge I_i2csr[BIT_I2CSR_MCF] )
begin
    case (bytes_cnt)
        0: I_i2cdr <= 8'haa;
        1: I_i2cdr <= 8'h12;
        2: I_i2cdr <= 8'h34;
        3: I_i2cdr <= 8'h00;
        default : I_i2cdr <= 8'hff;
    endcase
    if (bytes_cnt <= 3)
        I_wr_done <= 1'b1;
    else
        I_wr_done <= 1'b0;
    bytes_cnt <= bytes_cnt + 1;
end

always @(posedge I_clk)
begin
    I_wr_done <= 1'b0;
end

initial
begin
    bytes_cnt <= 0;
    I_rstn <= 0;
    I_clk <= 1;
    // I_i2cscl <= 1;
    // I_i2csda <= 1;
    I_i2cadr <= 7'h50;
    I_i2cfdr <= 8'h00;
    I_i2ccr <= 8'h00;
    // I_i2csr <= 8'h81;
    I_i2cdr <= 8'h55;
    I_i2cdfsrr <= 8'h10;
    I_wr_done <= 0;
    # 8
    I_rstn <= 1;
    // # 10000
    // I_i2cfdr <= 8'h1f;
end
always #2 I_clk = ~I_clk;

initial
begin            
    $dumpfile("wave.vcd");    //生成的vcd文件名称
    $dumpvars(0, tb_i2c);   //tb模块名称
end 

initial 
begin
    clk_i = 0;
    rst_n_i = 0;
    scl <= 1;
    sda <= 1;
    is_sda_lo <= 0;
    is_scl_lo <= 0;
    tx_data <= 8'haa;
    bit_cnt <= 3'h7;
    #15
    rst_n_i = 1;
    #(175-15)
    tx_data <= 8'h55;
    #100000
    $stop;
end

always #5 clk_i = ~clk_i;
assign iic_scl = is_scl_lo? 0: 1'bz;
assign iic_sda = is_sda_lo? 0: 1'bz;

always @(negedge clk_i or negedge rst_n_i)
begin
    if (!rst_n_i) begin
        scl <= 1;
        is_scl_lo <= 0;
    end
    else 
    begin
        scl <= ~scl;
    end
end

always @(negedge scl) 
begin
    is_scl_lo <= 1;
    bit_cnt <= bit_cnt - 1;
    sda <= tx_data[bit_cnt];
    if (tx_data[bit_cnt])
        is_sda_lo <= 0;
    else
        is_sda_lo <= 1;
end

always @(posedge scl) 
begin
    is_scl_lo <= 0;
end

endmodule
