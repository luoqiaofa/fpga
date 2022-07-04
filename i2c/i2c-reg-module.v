`include "timescale.v"

module i2c_reg_module(
    input              i_sysclk,  // system clock input
    input              i_reset_n, // module reset input
    output reg         o_wr_ena,  // write enable
    output reg [5:0]   o_wr_addr, // write address
    output reg [7:0]   o_wr_data, // write date input
    output reg         o_rd_ena,  // read enable input
    output reg [5:0]   o_rd_addr, // read address input
    input      [7:0]   i_rd_data  // read date output
);

always @(posedge i_sysclk)
begin
    if (1'b0 == i_reset_n) begin
        o_wr_ena <= 0;
        o_wr_addr <= 0;
        o_wr_data <= 0;
        o_rd_ena <= 0;
        o_rd_addr <= 0;
    end
end

task regread;
    input [5:0] addr;
    output [31:0] value;
    input delay;
    integer delay;
    
    begin
        repeat(delay) @(posedge i_sysclk);
        o_rd_addr = addr;
        @(posedge i_sysclk);
        o_rd_ena = 1;
        @(posedge i_sysclk);
        o_rd_ena = 0;
        @(posedge i_sysclk);
        value = i_rd_data;
    end
endtask

task regwrite;
    input [5:0] addr;
    input [31:0] value;
    input delay;
    integer delay;

    begin
        repeat(delay) @(posedge i_sysclk);
        o_wr_addr = addr;
        o_wr_data = value;
        @(posedge i_sysclk);
        o_wr_ena = 1;
        @(posedge  i_sysclk);
        o_wr_ena = 0;
        @(posedge i_sysclk);
    end
endtask

endmodule
