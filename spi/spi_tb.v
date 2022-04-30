`include "timescale.v"

module spi_tb;
`include "reg-bit-def.v"

localparam C_DIVIDER_WIDTH = 8;
localparam CHAR_NBITS = 8;
reg sysclk;            // system clock input
reg rst_n;             // module reset
reg enable;            // module enable
reg go;                // start transmit
reg [CHAR_NBITS - 1: 0] data_in;
reg [3:0] char_len;


wire SPI_SCK;
wire SPI_MISO;
wire SPI_MOSI;
wire  [3:0] SPI_CS_B;
wire irq;

// pullup pullup_spi_cs0 (SPI_CS[0]);
// pullup pullup_spi_cs1 (SPI_CS[1]);
// pullup pullup_spi_cs2 (SPI_CS[2]);
// pullup pullup_spi_cs3 (SPI_CS[3]);

/* pullup pullup_miso (SPI_MISO); */

wire  [NBITS_CHAR_LEN_MAX-1:0] data_rx;
reg   [NBITS_CHAR_LEN_MAX-1:0] data_tx;

// 100 MHz axi clock input
always @(sysclk)
    #5 sysclk <= !sysclk;

wire S_WVALID;
wire S_AWVALID;
wire S_ARVALID;
wire S_RREADY;
wire [3:0] S_WSTRB;
wire [7:0] S_ARADDR;
wire [7:0] S_AWADDR;
wire [31:0] S_WDATA;

wire S_ARREADY;
wire [31 : 0] S_RDATA;
wire S_RVALID;
wire [1 : 0] S_RRESP;
wire S_WREADY;
wire S_AWREADY;

wire [3:0 ] S_SPI_CS_B;

wire S_BREADY;
wire S_BVALID;

spi_master_model master
(
    .S_SYSCLK(sysclk),  // platform clock
    .S_RESETN(rst_n),  // reset
    .S_AWADDR(S_AWADDR),
    .S_WDATA(S_WDATA),
    .S_WSTRB(S_WSTRB),
    .S_WVALID(S_WVALID),
    .S_AWVALID(S_AWVALID),
    .S_WREADY(S_WREADY),
    .S_AWREADY(S_AWREADY),
    .S_ARVALID(S_ARVALID),
    .S_ARREADY(S_ARREADY),
    .S_ARADDR(S_ARADDR),
    .S_RDATA(S_RDATA),
    .S_RVALID(S_RVALID),
    .S_RREADY(S_RREADY),
    .S_BREADY(S_BREADY),
    .S_BVALID(S_BVALID),
    .S_RRESP(S_RRESP)
);

// /*
spi_intface # (.NCS(4))
spi_master
(
    .S_SYSCLK(sysclk),  // platform clock
    .S_RESETN(rst_n),  // reset
    .S_AWADDR(S_AWADDR),
    .S_WDATA(S_WDATA),
    .S_WSTRB(S_WSTRB),
    .S_WVALID(S_WVALID),
    .S_AWVALID(S_AWVALID),
    .S_WREADY(S_WREADY),
    .S_AWREADY(S_AWREADY),
    .S_ARVALID(S_ARVALID),
    .S_ARREADY(S_ARREADY),
    .S_ARADDR(S_ARADDR),
    .S_RDATA(S_RDATA),
    .S_RVALID(S_RVALID),
    .S_RREADY(S_RREADY),
    .S_BREADY(S_BREADY),
    .S_BVALID(S_BVALID),
    .S_RRESP(S_RRESP),
    .S_INTERRUPT(irq),
    .S_SPI_SCK(SPI_SCK),
    .S_SPI_MISO(SPI_MISO),
    .S_SPI_MOSI(SPI_MOSI),
    .S_SPI_SEL(SPI_CS_B)
);

wire [31: 0] slv_data_rx;
wire slv_done;

localparam DIV16        = (0 << CSMODE_DIV16);
localparam PM           = (2 << CSMODE_PM_LO);
localparam CPOL         = (0 << CSMODE_CPOL);
localparam CPHA         = (1 << CSMODE_CPHA);
localparam REV          = (1 << CSMODE_REV);
localparam LEN          = (7 << CSMODE_LEN_LO);
localparam CSPOL        = (1 << CSMODE_POL);
localparam CSBEF        = (3 << CSMODE_CSBEF_LO);
localparam CSAFT        = (5 << CSMODE_CSAFT_LO);
localparam CSCG         = (4 << CSMODE_CSCG_LO);
localparam CSMODE_VAL   = (DIV16 | PM | CPOL | CPHA | REV | LEN | CSBEF | CSAFT | CSCG | CSPOL);

localparam SPMODE_VAL   = SPMODE_DEF | (1 << SPMODE_EN);
localparam SPIE_VAL     = SPIE_DEF;
localparam SPIM_VAL     = (1 << SPIM_RNE);
localparam SPCOM_VAL    = 32'h0003_0006;
localparam SPITF_VAL    = 32'h0403_0201;
localparam SPIRF_VAL    = SPIRF_DEF;

reg [REG_WIDTH-1: 0] SPMODE;
reg [REG_WIDTH-1: 0] SPIE;
reg [REG_WIDTH-1: 0] SPIM;
reg [REG_WIDTH-1: 0] SPCOM;
reg [REG_WIDTH-1: 0] SPITF;
reg [REG_WIDTH-1: 0] SPIRF;
reg [REG_WIDTH-1: 0] CSMODE0;


spi_slave_trx_char #(.CHAR_NBITS(32))
inst_spi_slv_trx
(
    .S_SYSCLK(sysclk),           // platform clock
    .S_RESETN(rst_n),           // reset
    .S_ENABLE(SPMODE[SPMODE_EN]),  // enable
    .S_CPOL(CSMODE0[CSMODE_CPOL]),  // clock polary
    .S_CPHA(CSMODE0[CSMODE_CPHA]),  // clock phase, the first edge or second
    .S_CSPOL(CSMODE0[CSMODE_POL]),  // clock phase, the first edge or second
    .S_REV(CSMODE0[CSMODE_REV]),    // msb first or lsb first
    .S_CHAR_LEN(CSMODE0[CSMODE_LEN_HI:CSMODE_LEN_LO]),             // characters in bits length
    .S_SPI_CS(SPI_CS_B[0]),
    .S_SPI_SCK(SPI_SCK),
    .S_SPI_MISO(SPI_MISO),
    .S_SPI_MOSI(SPI_MOSI),
    .S_CHAR_DONE(slv_done),
    .S_WCHAR(32'h1faa1234),        // output character
    .S_RCHAR(slv_data_rx)          // input character
);


initial
begin
    $dumpfile("wave.vcd"); //生成的vcd文件名称
    $dumpvars(0, spi_tb);  //tb模块名称
    sysclk     <= 0;       // system clock input
    rst_n      <= 0;       // module reset
    SPMODE  <= SPMODE_DEF;
    SPIE    <= SPIE_DEF;
    SPIM    <= SPIM_DEF;
    SPCOM   <= SPCOM_DEF;
    SPITF   <= SPITF_DEF;
    SPIRF   <= SPIRF_DEF;
    CSMODE0 <= CSMODE_DEF;

    #100;
    rst_n      <= 1;      // module reset
    #100;
    SPMODE  <= SPMODE_VAL;
    SPIE    <= SPIE_VAL;
    SPIM    <= SPIM_VAL;
    SPCOM   <= SPCOM_VAL;
    SPITF   <= SPITF_VAL;
    SPIRF   <= SPIRF_VAL;
    CSMODE0 <= CSMODE_VAL;

    master.regwrite(ADDR_SPIE, 32'hFFFF_FFFF, 2);

    master.regwrite(ADDR_SPMODE, SPMODE_VAL, 2);

    master.regwrite(ADDR_SPMODE0, CSMODE_VAL, 2);

    master.regwrite(ADDR_SPIM, SPIM_VAL, 2);

    master.regwrite(ADDR_SPCOM, SPCOM_VAL, 2);

    master.regwrite(ADDR_SPITF, SPITF_VAL, 2);
    
    master.regread(ADDR_SPIE, SPIE, 2);
    while (~SPIE[SPIE_TXE]) begin
        master.regread(ADDR_SPIE, SPIE, 2);
    end
    #500;

    master.regwrite(ADDR_SPITF, 32'h12345678, 2);

    master.regread(ADDR_SPIE, SPIE, 2);
    while (SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO] < 6'h04) begin
        master.regread(ADDR_SPIE, SPIE, 2);
    end
    master.regread(ADDR_SPIRF, SPIRF, 2);

end

initial
begin
    #100000;
    $stop;
end

endmodule

