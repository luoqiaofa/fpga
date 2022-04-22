`include "timescale.v"

module spi_tb;
`include "reg-bit-def.v"

localparam C_DIVIDER_WIDTH = 8;
localparam CHAR_NBITS = 8;
reg sysclk;            // system clock input
reg rst_n;             // module reset
reg enable;            // module enable
reg go;                // start transmit
reg [C_DIVIDER_WIDTH-1:0] divider_i; // divider;
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

wire s_done;
wire  [CHAR_LEN_MAX -1:0] data_rx;
reg   [CHAR_LEN_MAX -1:0] data_tx;

// 100 MHz axi clock input
always @(sysclk)
    #5 sysclk <= !sysclk;

initial
begin
    $dumpfile("wave.vcd");        //生成的vcd文件名称
    $dumpvars(0, spi_tb);    //tb模块名称
end

initial
begin
    char_len   <= 4'h7;
    data_tx    <= 16'h55aa;
    data_in    <= 8'hff;
    sysclk     <= 0;      // system clock input
    rst_n      <= 0;      // module reset
    enable     <= 0;      // module enable
    go         <= 0;      // start transmit
    divider_i  <= 0;      // divider;
    #50
    rst_n    <= 1;        // module reset
    #10
    divider_i  <= 8'h04;  // divider; sys clk % 10 prescaler
    #30
    enable       <= 1;    // module enable
    #30
    go       <= 1;        // start transmit
    #(1000 * CHAR_NBITS / 8)
    go       <= 1;        // start transmit
    #(1000 * CHAR_NBITS / 8)
    // #50
    go       <= 1;        // start transmit
    #(1000 * CHAR_NBITS / 8)
    // #50
    enable       <= 0;   // module enable
    #10000;
    rst_n       <= 0;

    #2000
    $stop;
end

reg [REG_WIDTH-1: 0] SPMODE;
reg [REG_WIDTH-1: 0] SPIE;
reg [REG_WIDTH-1: 0] SPIM;
reg [REG_WIDTH-1: 0] SPCOM;
reg [REG_WIDTH-1: 0] SPITF;
reg [REG_WIDTH-1: 0] SPIRF;
reg [REG_WIDTH-1: 0] SPIREV1;
reg [REG_WIDTH-1: 0] SPIREV2;
reg [REG_WIDTH-1: 0] SPMODE0;

reg S_WVALID;
reg S_AWVALID;
reg S_ARVALID;
reg S_RREADY;
reg [3:0] S_WSTRB;
reg [7:0] S_ARADDR;
reg [7:0] S_AWADDR;
reg [31:0] S_WDATA;

wire S_ARREADY;
wire [31 : 0] S_RDATA;
wire S_RVALID;
wire [1 : 0] S_RRESP;
wire S_WREADY;
wire S_AWREADY;

wire [3:0 ] S_SPI_CS_B;

reg S_BREADY;
wire S_BVALID;


initial
begin
    SPMODE  <= SPMODE_DEF;
    SPIE    <= SPIE_DEF;
    SPIM    <= SPIM_DEF;
    SPCOM   <= SPCOM_DEF;
    SPITF   <= SPITF_DEF;
    SPIRF   <= SPIRF_DEF;
    SPMODE0 <= CSMODE_DEF;

    S_ARADDR <= 0;
    S_AWADDR <= 0;
    S_WVALID <= 0;
    S_AWVALID <= 0;
    S_ARVALID <= 0;
    S_RREADY <= 0;
    S_WSTRB <= 4'hf;
    S_WDATA <= 0;
    S_BREADY <= 0;
    #50;
    SPMODE[SPMODE_EN] <= 1;
    SPIE    <= 32'hFFFF_FFFF;
    SPMODE0[CSMODE_DIV16] <= 1'b1;
    SPMODE0[CSMODE_CPOL]  <= 1'b0;
    SPMODE0[CSMODE_CPHA]  <= 1'b0;
    SPMODE0[CSMODE_REV]   <= 1'b1;
    SPMODE0[CSMODE_LEN_HI: CSMODE_LEN_LO] <= 4'h0;
    SPITF   <= 32'h0403_0201;
    SPCOM   <= 32'h0003_0006;
    #10;
    // SPMODE0[CSMODE_CSCG_HI : CSMODE_CSCG_LO] <= 3;

    S_AWADDR <= ADDR_SPIE;
    S_WDATA <= SPIE;
    #10;

    S_WVALID <= 1;
    S_AWVALID <= 1;

    S_BREADY <= 1;

    #50;
    S_WVALID <= 0;
    S_AWVALID <= 0;

    SPIM[SPIM_RNE] = 1;
    // SPIM[SPIM_TNF] = 1;
    #10;

    S_AWADDR <= ADDR_SPIM;
    S_WDATA <= SPIM;
    #10;

    S_WVALID <= 1;
    S_AWVALID <= 1;

    S_BREADY <= 1;

    #50;

    S_WVALID <= 0;
    S_AWVALID <= 0;
    #50;
    S_WVALID <= 0;
    S_AWVALID <= 0;
    #10;
    S_AWADDR <= ADDR_SPMODE;
    S_WDATA <= SPMODE;
    #10;
    S_WVALID <= 1;
    S_AWVALID <= 1;
    #50;
    S_WVALID <= 0;
    S_AWVALID <= 0;
    #10;
    S_AWADDR <= ADDR_SPMODE0;
    S_WDATA <= SPMODE0;
    #10;
    S_WVALID <= 1;
    S_AWVALID <= 1;
    #50;
    S_WVALID <= 0;
    S_AWVALID <= 0;
    #10;

    S_AWADDR <= ADDR_SPITF;
    S_WDATA <= SPITF;
    #10;
    S_WVALID <= 1;
    S_AWVALID <= 1;
    #50;
    S_WVALID <= 0;
    S_AWVALID <= 0;
    #10;
    S_AWADDR <= ADDR_SPCOM;
    S_WDATA <= SPCOM;
    #10;
    S_WVALID <= 1;
    S_AWVALID <= 1;
    #50;
    S_WVALID <= 0;
    S_AWVALID <= 0;
    SPITF   <= 32'h1122_3344;
    #10;

    #13500;
    SPMODE[SPMODE_EN] <= 0;
    #10;
    S_WVALID <= 0;
    S_AWVALID <= 0;
    #10;
    S_AWADDR <= ADDR_SPMODE;
    S_WDATA <= SPMODE;
    #10;
    S_WVALID <= 1;
    S_AWVALID <= 1;
    #500;

end
initial begin
    #4500;
    S_AWADDR <= ADDR_SPITF;
    S_WDATA <= SPITF;
    #10;
    S_WVALID <= 1;
    S_AWVALID <= 1;
    #50;
    S_WVALID <= 0;
    S_AWVALID <= 0;
    #10;
end
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

wire [CHAR_LEN_MAX-1:0] slv_data_rx;
wire slv_done;

spi_slave_trx_char #(.CHAR_NBITS(CHAR_LEN_MAX))
inst_spi_slv_trx
(
    .S_SYSCLK(sysclk),           // platform clock
    .S_RESETN(rst_n),           // reset
    .S_ENABLE(SPMODE[SPMODE_EN]),  // enable
    .S_CPOL(SPMODE0[CSMODE_CPOL]),  // clock polary
    .S_CPHA(SPMODE0[CSMODE_CPHA]),  // clock phase, the first edge or second
    .S_REV(SPMODE0[CSMODE_REV]),    // msb first or lsb first
    .S_CHAR_LEN(SPMODE0[CSMODE_LEN_HI:CSMODE_LEN_LO]),             // characters in bits length
    .S_SPI_CS(SPI_CS_B[0]),
    .S_SPI_SCK(SPI_SCK),
    .S_SPI_MISO(SPI_MISO),
    .S_SPI_MOSI(SPI_MOSI),
    .S_CHAR_DONE(slv_done),
    .S_WCHAR(32'h1faa5510),        // output character
    .S_RCHAR(slv_data_rx)          // input character
);

endmodule

