`timescale 1ns / 1ps

module i2c_master(
    input       I_RSTN,
    input       I_CLK,
    inout       I_I2CSCL,
    inout       I_I2CSDA,
    input       I_TXRX_DONE,
    input  [7:0] I_I2CADR,
    input  [7:0] I_I2CFDR,
    input  [7:0] I_I2CCR,
    output [7:0] I_I2CSR,
    input  [7:0] I_I2CDR,
    input  [7:0] I_I2CDFSRR
);

`include "reg-bit-def.v"
localparam NUM_CLK_1BYTE   =  9;

reg scl;
reg sda;
reg scl_low;
reg sda_low;
reg [31:0] clk_div;
reg [31:0] clk_cnt;
reg sample_clk;
reg [7:0] clk_sample_div;
reg [7:0] clk_sample_cnt;
reg [2:0] bit_cnt;
reg [3:0] scl_cnt;
reg [7:0] r_sr;
reg ignore_first;


assign I_I2CSCL = (scl == 0? 0:1'bz);
assign I_I2CSDA = (sda == 0? 0:1'bz);
assign I_I2CSR = r_sr;

always @(negedge I_TXRX_DONE)
begin
   r_sr[BIT_I2CSR_MCF] <= 1'b0; 
end

always @(posedge scl)
begin
    if ((!I_RSTN) || (!I_I2CCR[BIT_I2CCR_MEN]))
        ;
    else if (scl_cnt == 0) 
    begin
        bit_cnt <= 7;
        scl_cnt <= NUM_CLK_1BYTE - 1;
        r_sr[BIT_I2CSR_MCF] <= 1'b1; 
    end
    else
    begin
        scl_cnt <= scl_cnt - 1;
        if (scl_cnt >= 1)
            bit_cnt <= bit_cnt - 1;
    end
end

always @(posedge sample_clk)
begin
    if ((!I_RSTN) || (!I_I2CCR[BIT_I2CCR_MEN]))
        ;
    else if (scl == 1'b0)
        sda <= I_I2CDR[bit_cnt];
    else
        sda <= sda;
end

always @(posedge I_CLK or negedge I_RSTN)
begin
    if ((!I_RSTN) || (!I_I2CCR[BIT_I2CCR_MEN]))
    begin
        bit_cnt <= 7;
        scl_cnt <= NUM_CLK_1BYTE - 1;
        ignore_first <= 1;
        r_sr <= 0;
        sda <= I_I2CDR[7];
        clk_cnt <= 0;
        scl <= 1;
        clk_div <= (freq_divid_get(I_I2CFDR) >> 1);
        clk_sample_div <= (I_I2CDFSRR >> 1);
        clk_sample_cnt <= 0;
        sample_clk <= 0;
    end
    else 
    begin
        clk_div <= (freq_divid_get(I_I2CFDR) >> 1);
        if  (clk_cnt >= clk_div) 
        begin
            if (!I_I2CSR[BIT_I2CSR_MCF]) 
            begin
                scl <= ~scl;
            end
            else 
            begin
                scl <= 1'b1;
            end
            clk_cnt <= 0;
        end
        else
            clk_cnt <= clk_cnt + 1;
        if (clk_sample_cnt >= clk_sample_div)
        begin
            sample_clk <= ~sample_clk;
            clk_sample_cnt <= 0;
        end
        else
            clk_sample_cnt <= clk_sample_cnt + 1;
    end
end

function [31:0] freq_divid_get(
    input [7:0] fdr
);
reg [31:0] freq_div;

begin

case (fdr & 8'h3f)
    8'h00 : freq_div = 384;
    8'h01 : freq_div = 416;
    8'h02 : freq_div = 480;
    8'h03 : freq_div = 576;
    8'h04 : freq_div = 640;
    8'h05 : freq_div = 704;
    8'h06 : freq_div = 832;
    8'h07 : freq_div = 1024;
    8'h08 : freq_div = 1152;
    8'h09 : freq_div = 1280;
    8'h0A : freq_div = 1536;
    8'h0B : freq_div = 1920;
    8'h0C : freq_div = 2304;
    8'h0D : freq_div = 2560;
    8'h0E : freq_div = 3072;
    8'h0F : freq_div = 3840;
    8'h10 : freq_div = 4608;
    8'h11 : freq_div = 5120;
    8'h12 : freq_div = 6144;
    8'h13 : freq_div = 7680;
    8'h14 : freq_div = 9216;
    8'h15 : freq_div = 10240;
    8'h16 : freq_div = 12288;
    8'h17 : freq_div = 15360;
    8'h18 : freq_div = 18432;
    8'h19 : freq_div = 20480;
    8'h1A : freq_div = 24576;
    8'h1B : freq_div = 30720;
    8'h1C : freq_div = 36864;
    8'h1D : freq_div = 40960;
    8'h1E : freq_div = 49152;
    8'h1F : freq_div = 61440;
    8'h20 : freq_div = 256;
    8'h21 : freq_div = 288;
    8'h22 : freq_div = 320;
    8'h23 : freq_div = 352;
    8'h24 : freq_div = 384;
    8'h25 : freq_div = 448;
    8'h26 : freq_div = 512;
    8'h27 : freq_div = 576;
    8'h28 : freq_div = 640;
    8'h29 : freq_div = 768;
    8'h2A : freq_div = 896;
    8'h2B : freq_div = 1024;
    8'h2C : freq_div = 1280;
    8'h2D : freq_div = 1536;
    8'h2E : freq_div = 1792;
    8'h2F : freq_div = 2048;
    8'h30 : freq_div = 2560;
    8'h31 : freq_div = 3072;
    8'h32 : freq_div = 3584;
    8'h33 : freq_div = 4096;
    8'h34 : freq_div = 5120;
    8'h35 : freq_div = 6144;
    8'h36 : freq_div = 7168;
    8'h37 : freq_div = 8192;
    8'h38 : freq_div = 10240;
    8'h39 : freq_div = 12288;
    8'h3A : freq_div = 14336;
    8'h3B : freq_div = 16384;
    8'h3C : freq_div = 20480;
    8'h3D : freq_div = 24576;
    8'h3E : freq_div = 28672;
    8'h3F : freq_div = 32768;
endcase
freq_divid_get = freq_div;
end

endfunction

endmodule

