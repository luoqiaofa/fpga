`include "timescale.v"
module spi_master_model
(
    input  S_SYSCLK,  // platform clock
    input  S_RESETN,  // reset
    output reg [7:0]   S_AWADDR,
    output reg [31: 0] S_WDATA,
    output reg [3 : 0] S_WSTRB,
    output reg S_WVALID,
    output reg S_AWVALID,
    input  S_WREADY,
    input  S_AWREADY,
    output reg S_ARVALID,
    input  S_ARREADY,
    output reg [7 : 0]  S_ARADDR,
    input  [31 : 0] S_RDATA,
    input  S_RVALID,
    output reg S_RREADY,
    output reg S_BREADY,
    input  S_BVALID,
    input  [1 : 0] S_BRESP,
    input  [1 : 0] S_RRESP
);
`include "./reg-bit-def.v"
always @(posedge S_SYSCLK or negedge S_RESETN)
begin
    if (1'b0 == S_RESETN) begin
        S_AWADDR = ADDR_SPMODE;
        S_WDATA  = SPMODE_DEF;
        S_WSTRB  = 4'hf;
        S_ARADDR = ADDR_SPIE;
        S_RREADY = 1;
        S_BREADY = 1;
        S_WVALID  = 0;
        S_AWVALID = 0;
        S_ARVALID = 0;
    end
end

task regwrite;
    input [7:0] addr;
    input [31:0] value;
    input delay;
    integer delay;

    begin
        repeat(delay) @(posedge  S_SYSCLK);
        #1;
        S_AWADDR  = addr;
        S_WDATA   = value;
        S_WVALID  = 1;
        S_AWVALID = 1;

        @(posedge  S_SYSCLK);
        // wait for acknowledge from slave
        while(~(S_WREADY & S_WREADY)) @(posedge  S_SYSCLK);
        #1;
        S_WVALID  = 0;
        S_AWVALID = 0;
    end
endtask

endmodule

