`include "timescale.v"
module spi_master_model
(
    input  S_SYSCLK,  // platform clock
    input  S_RESETN,  // reset
    output reg [7:0]   S_AWADDR,
    output reg [31: 0] S_WDATA,
    output reg [3 : 0] S_WSTRB,
    output reg S_REG_WEN,
    output reg [7 : 0]  S_ARADDR,
    input  [31 : 0] S_RDATA,
    output reg S_REG_RDEN
);
`include "./reg-bit-def.v"
always @(posedge S_SYSCLK or negedge S_RESETN)
begin
    if (1'b0 == S_RESETN) begin
        S_AWADDR   <= ADDR_SPMODE;
        S_WDATA    <= SPMODE_DEF;
        S_WSTRB    <= 4'hf;
        S_ARADDR   <= ADDR_SPIE;
        S_REG_WEN  <= 0;
        S_REG_RDEN <= 0;
    end
end

task regwrite;
    input [7:0] addr;
    input [31:0] value;
    input delay;
    integer delay;

    begin
        repeat(delay) @(posedge S_SYSCLK);
        S_AWADDR  = addr;
        S_WDATA   = value;
        @(posedge S_SYSCLK);
        S_REG_WEN = 1;
        @(posedge  S_SYSCLK);
        S_REG_WEN = 0;
        @(posedge S_SYSCLK);
    end
endtask

task regread;
    input [7:0] addr;
    output [31:0] value;
    input delay;
    integer delay;

    begin
        repeat(delay) @(posedge  S_SYSCLK);
        S_ARADDR  = addr;
        @(posedge S_SYSCLK);
        S_REG_RDEN = 1;
        @(posedge S_SYSCLK);
        S_REG_RDEN = 0;
        @(posedge S_SYSCLK);
        value = S_RDATA;
    end
endtask

endmodule

