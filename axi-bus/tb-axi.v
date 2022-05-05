// divn_tb.v / Verilog

`timescale 1ns/10ps
module axi_bus_tb;
reg sysclk;
reg aresetn;

localparam C_AXI_DATA_WIDTH = 32;
localparam C_AXI_ADDR_WIDTH = 8;

/* input */  wire [7 : 0] s00_axi_awaddr;
/* input */  wire [2 : 0] s00_axi_awprot;
/* input */  wire  s00_axi_awvalid;
/* output */ wire  s00_axi_awready;
/* input */  wire [C_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata;
/* input */  wire [(C_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb;
/* input */  wire  s00_axi_wvalid;
/* output */ wire  s00_axi_wready;
/* output */ wire [1 : 0] s00_axi_bresp;
/* output */ wire  s00_axi_bvalid;
/* input */  wire  s00_axi_bready;
/* input */  wire [7 : 0] s00_axi_araddr;
/* input */  wire [2 : 0] s00_axi_arprot;
/* input */  wire  s00_axi_arvalid;
/* output */ wire  s00_axi_arready;
/* output */ wire [C_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata;
/* output */ wire [1 : 0] s00_axi_rresp;
/* output */ wire  s00_axi_rvalid;
/* input */  wire  s00_axi_rready;

reg [C_AXI_DATA_WIDTH-1:0] regval;

initial begin
    $dumpfile("wave.vcd");    //生成的vcd文件名称
    $dumpvars(0);   //tb模块名称
    #1000;
    $stop;
end



// 100MHz sysclk
always #5 sysclk = ~sysclk;

aix_slave_bus # ( 
    .C_S_AXI_DATA_WIDTH(C_AXI_DATA_WIDTH),
    .C_S_AXI_ADDR_WIDTH(C_AXI_ADDR_WIDTH)
) aix_slave_bus_inst (
    .S_AXI_ACLK(sysclk),
    .S_AXI_ARESETN(aresetn),
    .S_AXI_AWADDR(s00_axi_awaddr),
    .S_AXI_AWPROT(s00_axi_awprot),
    .S_AXI_AWVALID(s00_axi_awvalid),
    .S_AXI_AWREADY(s00_axi_awready),
    .S_AXI_WDATA(s00_axi_wdata),
    .S_AXI_WSTRB(s00_axi_wstrb),
    .S_AXI_WVALID(s00_axi_wvalid),
    .S_AXI_WREADY(s00_axi_wready),
    .S_AXI_BRESP(s00_axi_bresp),
    .S_AXI_BVALID(s00_axi_bvalid),
    .S_AXI_BREADY(s00_axi_bready),
    .S_AXI_ARADDR(s00_axi_araddr),
    .S_AXI_ARPROT(s00_axi_arprot),
    .S_AXI_ARVALID(s00_axi_arvalid),
    .S_AXI_ARREADY(s00_axi_arready),
    .S_AXI_RDATA(s00_axi_rdata),
    .S_AXI_RRESP(s00_axi_rresp),
    .S_AXI_RVALID(s00_axi_rvalid),
    .S_AXI_RREADY(s00_axi_rready)
);

axi_master_model #
(
    .C_S00_AXI_DATA_WIDTH(C_AXI_DATA_WIDTH),
    .C_S00_AXI_ADDR_WIDTH(C_AXI_ADDR_WIDTH)
)
aix_master
(
    // Ports of Axi Slave Bus Interface S00_AXI
    /* input */  .s00_axi_aclk(sysclk),
    /* input */  .s00_axi_aresetn(aresetn),
    /* output */ .s00_axi_awaddr(s00_axi_awaddr),
    /* output */ .s00_axi_awprot(s00_axi_awprot),
    /* output */ .s00_axi_awvalid(s00_axi_awvalid),
    /* input */  .s00_axi_awready(s00_axi_awready),
    /* output */ .s00_axi_wdata(s00_axi_wdata),
    /* output */ .s00_axi_wstrb(s00_axi_wstrb),
    /* output */ .s00_axi_wvalid(s00_axi_wvalid),
    /* input */  .s00_axi_wready(s00_axi_wready),
    /* input */  .s00_axi_bresp(s00_axi_bresp),
    /* input */  .s00_axi_bvalid(s00_axi_bvalid),
    /* output */ .s00_axi_bready(s00_axi_bready),
    /* output */ .s00_axi_araddr(s00_axi_araddr),
    /* output */ .s00_axi_arprot(s00_axi_arprot),
    /* output */ .s00_axi_arvalid(s00_axi_arvalid),
    /* input */  .s00_axi_arready(s00_axi_arready),
    /* input */  .s00_axi_rdata(s00_axi_rdata),
    /* input */  .s00_axi_rresp(s00_axi_rresp),
    /* input */  .s00_axi_rvalid(s00_axi_rvalid),
    /* output */ .s00_axi_rready(s00_axi_rready)
);

initial begin
    sysclk  = 1'b0;
    aresetn = 1'b0;
    regval  = 0;
    #20;
    aresetn = 1'b1;/*这一步是一定要加上的，因为，如果不加的话就等于没有进行初始化，输出信息是没有的，这一点已经验证过了*/
    #25;
    aix_master.regread(0, regval, 2);
    $display("[%t] reg#0=%h", $time, regval);
    repeat(3) @(posedge sysclk);
    aix_master.regwrite(0, 32'h0000_0000, 2);
    repeat(3) @(posedge sysclk);
    aix_master.regread(0, regval, 2);
    $display("[%t] reg#0=%h", $time, regval);

    aix_master.regread(4, regval, 2);
    $display("[%t] reg#4=%h", $time, regval);
    aix_master.regread(8, regval, 2);
    $display("[%t] reg#8=%h", $time, regval);
    aix_master.regread(12, regval, 2);
    $display("[%t] reg#c=%h", $time, regval);
    aix_master.regwrite(4, 32'h1234_5678, 2);
    $display("[%t] reg#4=%h", $time, regval);
end

endmodule
