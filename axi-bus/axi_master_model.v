`timescale 1 ns / 1 ps

module axi_master_model #
(
    // Users to add parameters here

    // User parameters ends
    // Do not modify the parameters beyond this line


    // Parameters of Axi Slave Bus Interface S00_AXI
    parameter integer C_S00_AXI_DATA_WIDTH    = 32,
    parameter integer C_S00_AXI_ADDR_WIDTH    = 8
)
(
    // Users to add ports here

    // User ports ends
    // Do not modify the ports beyond this line

    // Ports of Axi Slave Bus Interface S00_AXI
    input       s00_axi_aclk,
    input       s00_axi_aresetn,
    output reg  [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
    output reg  [2 : 0] s00_axi_awprot,
    output reg  s00_axi_awvalid,
    input       s00_axi_awready,
    output reg  [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
    output reg  [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
    output reg  s00_axi_wvalid,
    input       s00_axi_wready,
    input       [1 : 0] s00_axi_bresp,
    input       s00_axi_bvalid,
    output reg  s00_axi_bready,
    output reg  [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
    output reg  [2 : 0] s00_axi_arprot,
    output reg  s00_axi_arvalid,
    input       s00_axi_arready,
    input       [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
    input       [1 : 0] s00_axi_rresp,
    input       s00_axi_rvalid,
    output reg  s00_axi_rready
);

// Add user logic here
initial begin

    s00_axi_awaddr  = 0;
    s00_axi_wdata   = 0;
    s00_axi_awprot  = 0;

    s00_axi_rready <= 0;
    s00_axi_bready <= 0;
    s00_axi_arprot <= 0;

    s00_axi_wvalid  = 0;
    s00_axi_awvalid = 0;

    s00_axi_araddr  = 0;
    s00_axi_arvalid = 0;

    s00_axi_wstrb   = 0;
end

// User logic ends
always @(s00_axi_aclk or negedge s00_axi_aresetn)
begin
    if (1'b0 == s00_axi_aresetn)
    begin

        s00_axi_wstrb  <= {(C_S00_AXI_DATA_WIDTH/8){1'b1}};
        s00_axi_awaddr <= 0;
        s00_axi_wdata  <= 0;
        s00_axi_awprot <= 0;

        s00_axi_rready <= 0;
        s00_axi_bready <= 0;
        s00_axi_arprot <= 0;

        s00_axi_wvalid  <= 0;
        s00_axi_awvalid <= 0;

        s00_axi_araddr  <= 0;
        s00_axi_arvalid <= 0;
    end
    else begin
        s00_axi_rready <= 1;
        s00_axi_bready <= 1;
        s00_axi_arprot <= 0;
        s00_axi_awprot <= 0;
    end
end

task regwrite;
    input [C_S00_AXI_ADDR_WIDTH-1:0] addr;
    input [C_S00_AXI_DATA_WIDTH-1:0] value;
    input delay;
    integer delay;

    begin
        repeat(delay) @(posedge  s00_axi_aclk);
        s00_axi_awaddr  = addr;
        s00_axi_wdata   = value;
        s00_axi_wvalid  = 1;
        s00_axi_awvalid = 1;

        while(~(s00_axi_wready & s00_axi_awready)) @(posedge s00_axi_aclk);
        @(posedge  s00_axi_aclk);
        // wait for acknowledge from slave
        // #1;
        s00_axi_wvalid  = 0;
        s00_axi_awvalid = 0;
    end
endtask

task regread;
    input [C_S00_AXI_ADDR_WIDTH-1:0] addr;
    output [C_S00_AXI_DATA_WIDTH-1:0] value;
    input delay;
    integer delay;

    begin
        repeat(delay) @(posedge s00_axi_aclk);
        // #1;
        s00_axi_araddr  = addr;
        s00_axi_arvalid  = 1;

        // wait for acknowledge from slave
        while(~s00_axi_rvalid) @(posedge  s00_axi_aclk);
        // #1;
        value = s00_axi_rdata;
        s00_axi_arvalid  = 0;
    end
endtask

endmodule

