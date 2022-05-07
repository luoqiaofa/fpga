// divn_tb.v / Verilog

`timescale 1ns/10ps
module axi_bus_tb;

`include "version.v"
`include "reg_ranges_def.v"
`include "../spi/reg-bit-def.v"
`include "../i2c/i2c-reg-def.v"

reg sysclk;
reg aresetn;

localparam C_AXI_DATA_WIDTH = 32;
localparam C_AXI_ADDR_WIDTH = 12;

/* input */  wire [C_AXI_ADDR_WIDTH-1: 0] s_axi_awaddr;
/* input */  wire [2 : 0] s_axi_awprot;
/* input */  wire  s_axi_awvalid;
/* output */ wire  s_axi_awready;
/* input */  wire [C_AXI_DATA_WIDTH-1 : 0] s_axi_wdata;
/* input */  wire [(C_AXI_DATA_WIDTH/8)-1 : 0] s_axi_wstrb;
/* input */  wire  s_axi_wvalid;
/* output */ wire  s_axi_wready;
/* output */ wire [1 : 0] s_axi_bresp;
/* output */ wire  s_axi_bvalid;
/* input */  wire  s_axi_bready;
/* input */  wire [C_AXI_ADDR_WIDTH-1    : 0] s_axi_araddr;
/* input */  wire [2 : 0] s_axi_arprot;
/* input */  wire  s_axi_arvalid;
/* output */ wire  s_axi_arready;
/* output */ wire [C_AXI_DATA_WIDTH-1 : 0] s_axi_rdata;
/* output */ wire [1 : 0] s_axi_rresp;
/* output */ wire  s_axi_rvalid;
/* input */  wire  s_axi_rready;

reg [C_AXI_DATA_WIDTH-1:0] regval;

initial begin
    $dumpfile("wave.vcd");    //生成的vcd文件名称
    $dumpvars(0);   //tb模块名称
    #10000;
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
    .S_AXI_AWADDR(s_axi_awaddr),
    .S_AXI_AWPROT(s_axi_awprot),
    .S_AXI_AWVALID(s_axi_awvalid),
    .S_AXI_AWREADY(s_axi_awready),
    .S_AXI_WDATA(s_axi_wdata),
    .S_AXI_WSTRB(s_axi_wstrb),
    .S_AXI_WVALID(s_axi_wvalid),
    .S_AXI_WREADY(s_axi_wready),
    .S_AXI_BRESP(s_axi_bresp),
    .S_AXI_BVALID(s_axi_bvalid),
    .S_AXI_BREADY(s_axi_bready),
    .S_AXI_ARADDR(s_axi_araddr),
    .S_AXI_ARPROT(s_axi_arprot),
    .S_AXI_ARVALID(s_axi_arvalid),
    .S_AXI_ARREADY(s_axi_arready),
    .S_AXI_RDATA(s_axi_rdata),
    .S_AXI_RRESP(s_axi_rresp),
    .S_AXI_RVALID(s_axi_rvalid),
    .S_AXI_RREADY(s_axi_rready)
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
    /* output */ .s00_axi_awaddr(s_axi_awaddr),
    /* output */ .s00_axi_awprot(s_axi_awprot),
    /* output */ .s00_axi_awvalid(s_axi_awvalid),
    /* input */  .s00_axi_awready(s_axi_awready),
    /* output */ .s00_axi_wdata(s_axi_wdata),
    /* output */ .s00_axi_wstrb(s_axi_wstrb),
    /* output */ .s00_axi_wvalid(s_axi_wvalid),
    /* input */  .s00_axi_wready(s_axi_wready),
    /* input */  .s00_axi_bresp(s_axi_bresp),
    /* input */  .s00_axi_bvalid(s_axi_bvalid),
    /* output */ .s00_axi_bready(s_axi_bready),
    /* output */ .s00_axi_araddr(s_axi_araddr),
    /* output */ .s00_axi_arprot(s_axi_arprot),
    /* output */ .s00_axi_arvalid(s_axi_arvalid),
    /* input */  .s00_axi_arready(s_axi_arready),
    /* input */  .s00_axi_rdata(s_axi_rdata),
    /* input */  .s00_axi_rresp(s_axi_rresp),
    /* input */  .s00_axi_rvalid(s_axi_rvalid),
    /* output */ .s00_axi_rready(s_axi_rready)
);

initial begin
    sysclk  = 1'b0;
    aresetn = 1'b0;
    regval  = 0;
    #20;
    aresetn = 1'b1;/*这一步是一定要加上的，因为，如果不加的话就等于没有进行初始化，输出信息是没有的，这一点已经验证过了*/
    #10;
    aix_master.regread(0, regval, 0);
    $display("[%t] reg#0=%h", $time, regval);

    aix_master.regread(4, regval, 0);
    $display("[%t] reg#4=%h", $time, regval);

    aix_master.regread(8, regval, 0);
    $display("[%t] reg#8=%h", $time, regval);
    aix_master.regread(12, regval, 0);
    $display("[%t] reg#c=%h", $time, regval);
    $display("[%t] write reg#8=%h", $time, 32'h1234_5678);
    aix_master.regwrite(8, 32'h1234_5678, 0);
    aix_master.regread(8, regval, 0);
    $display("[%t] reg#8=%h", $time, regval);
    $display("[%t] write reg#c=%h", $time, 32'haa55_aa55);
    aix_master.regwrite(12, 32'haa55_aa55, 0);
    aix_master.regread(12, regval, 0);
    $display("[%t] reg#c=%h", $time, regval);

    aix_master.regread(ADDR_SPMODE | (C_SPI_BASE << 8), regval, 0);
    $display("[%t] SPMODE=%h", $time, regval);
    aix_master.regread(ADDR_SPIE | (C_SPI_BASE << 8), regval, 0);
    $display("[%t] SPIE=%h", $time, regval);
    aix_master.regwrite(ADDR_SPMODE | (C_SPI_BASE << 8), SPMODE_DEF | (1 << SPMODE_EN), 0);
    aix_master.regread(ADDR_SPMODE | (C_SPI_BASE << 8), regval, 0);
    $display("[%t] SPMODE=%h", $time, regval);
    aix_master.regwrite(ADDR_SPCOM | (C_SPI_BASE << 8), 32'h00030006, 0);
    aix_master.regread(ADDR_SPCOM | (C_SPI_BASE << 8), regval, 0);
    $display("[%t] SPCOM=%h", $time, regval);

    aix_master.regread(0 | (C_PWM_BASE << 8), regval, 0);
    $display("[%t] PWM_MODE=%h", $time, regval);
    aix_master.regwrite(0 | (C_PWM_BASE << 8), 1, 0);
    aix_master.regread(0 | (C_PWM_BASE << 8), regval, 0);
    $display("[%t] PWM_MODE=%h", $time, regval);
    aix_master.regread(4 | (C_PWM_BASE << 8), regval, 0);
    $display("[%t] PWM_DIVIDER=%h", $time, regval);
    aix_master.regread(8 | (C_PWM_BASE << 8), regval, 0);
    $display("[%t] PWM_DUTY=%h", $time, regval);
    aix_master.regread(12 | (C_PWM_BASE << 8), regval, 0);
    $display("[%t] PWM_BRIGHTNESS=%h", $time, regval);

    aix_master.regread((ADDR_ADR << 2)| (C_I2C_BASE << 8), regval, 0);
    $display("[%t] I2CADR=%h", $time, regval);
    aix_master.regread((ADDR_FDR << 2) | (C_I2C_BASE << 8), regval, 0);
    $display("[%t] I2CFDR=%h", $time, regval);
    aix_master.regread((ADDR_CR << 2) | (C_I2C_BASE << 8), regval, 0);
    $display("[%t] I2CCR=%h", $time, regval);
    aix_master.regread((ADDR_SR << 2)| (C_I2C_BASE << 8), regval, 0);
    $display("[%t] I2CSR=%h", $time, regval);
    aix_master.regread((ADDR_DR << 2) | (C_I2C_BASE << 8), regval, 0);
    $display("[%t] I2CDR=%h", $time, regval);
    aix_master.regread((ADDR_DFSRR<<2) | (C_I2C_BASE << 8), regval, 0);
    $display("[%t] I2CDFSRR=%h", $time, regval);
end

endmodule
