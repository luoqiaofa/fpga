`include "timescale.v"

module spi_tb;
`include "reg-bit-def.v"

localparam C_DIVIDER_WIDTH = 8;
localparam CHAR_NBITS = 8;
reg sysclk;            // system clock input
reg rst_n;             // module reset
integer idx;

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

wire [NBITS_CHAR_LEN_MAX-1:0] data_rx;
reg  [31: 0] data_tx[0:NWORD_TXFIFO];
integer txdata[0: NWORD_TXFIFO+1];

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

wire [31: 0] slv0_data_rx;
wire [31: 0] slv1_data_rx;
wire         slv0_char_done;
wire         slv1_char_done;
reg  [31: 0] slv_data_tx[0:NWORD_TXFIFO];

localparam SPIMODE0     = (0 << CSMODE_CPHA); /* CI = 0, CP=0 */
localparam SPIMODE1     = (1 << CSMODE_CPHA); /* CI = 0, CP=1 */
localparam SPIMODE2     = (2 << CSMODE_CPHA); /* CI = 1, CP=0 */
localparam SPIMODE3     = (3 << CSMODE_CPHA); /* CI = 1, CP=1 */

localparam DIV160       = (0 << CSMODE_DIV16);
localparam PM0          = (2 << CSMODE_PM_LO);
localparam REV0         = (1 << CSMODE_REV);
localparam LEN0         = (7 << CSMODE_LEN_LO);
localparam CS0POL       = (1 << CSMODE_POL);
localparam CS0BEF       = (3 << CSMODE_CSBEF_LO);
localparam CS0AFT       = (5 << CSMODE_CSAFT_LO);
localparam CS0CG        = (4 << CSMODE_CSCG_LO);
localparam CS0MODE_VAL  = (SPIMODE0|REV0|DIV160|PM0|LEN0|CS0BEF|CS0AFT|CS0CG|CS0POL);

localparam DIV161       = (0 << CSMODE_DIV16);
localparam PM1          = (2 << CSMODE_PM_LO);
localparam REV1         = (0 << CSMODE_REV);
localparam LEN1         = (7 << CSMODE_LEN_LO);
localparam CS1POL       = (1 << CSMODE_POL);
localparam CS1BEF       = (3 << CSMODE_CSBEF_LO);
localparam CS1AFT       = (5 << CSMODE_CSAFT_LO);
localparam CS1CG        = (4 << CSMODE_CSCG_LO);
localparam CS1MODE_VAL  = (SPIMODE1|DIV161|PM1|REV1|LEN1|CS1BEF|CS1AFT|CS1CG|CS1POL);

localparam SPMODE_VAL   = SPMODE_DEF | (1 << SPMODE_EN)/* | (1 << SPMODE_LOOP)*/;
localparam SPIE_VAL     = SPIE_DEF;
localparam SPIM_VAL     = (1 << SPIM_RNE);
localparam SPCOM_CS0    = ((0 << SPCOM_CS_LO)|(3<<SPCOM_RSKIP_LO)|(6<<SPCOM_TRANLEN_LO));
localparam SPCOM_CS1    = ((1 << SPCOM_CS_LO)|(2<<SPCOM_RSKIP_LO)|(8<<SPCOM_TRANLEN_LO));
localparam SPITF_VAL    = 32'h0403_0201;
localparam SPIRF_VAL    = SPIRF_DEF;

reg [REG_WIDTH-1: 0] SPMODE;
reg [REG_WIDTH-1: 0] SPIE;
reg [REG_WIDTH-1: 0] SPIM;
reg [REG_WIDTH-1: 0] SPCOM;
reg [REG_WIDTH-1: 0] SPITF;
reg [REG_WIDTH-1: 0] SPIRF;
reg [REG_WIDTH-1: 0] CSMODE0;
reg [REG_WIDTH-1: 0] CSMODE1;

spi_slave_trx_char #(.CHAR_NBITS(32))
spi_slv_dev0
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
    .S_CHAR_DONE(slv0_char_done),
    .S_WCHAR(32'h11223344),        // output character
    .S_RCHAR(slv0_data_rx)          // input character
);

spi_slave_trx_char #(.CHAR_NBITS(32))
spi_slv_dev1
(
    .S_SYSCLK(sysclk),           // platform clock
    .S_RESETN(rst_n),           // reset
    .S_ENABLE(SPMODE[SPMODE_EN]),  // enable
    .S_CPOL(CSMODE1[CSMODE_CPOL]),  // clock polary
    .S_CPHA(CSMODE1[CSMODE_CPHA]),  // clock phase, the first edge or second
    .S_CSPOL(CSMODE1[CSMODE_POL]),  // clock phase, the first edge or second
    .S_REV(CSMODE1[CSMODE_REV]),    // msb first or lsb first
    .S_CHAR_LEN(CSMODE1[CSMODE_LEN_HI:CSMODE_LEN_LO]),             // characters in bits length
    .S_SPI_CS(SPI_CS_B[1]),
    .S_SPI_SCK(SPI_SCK),
    .S_SPI_MISO(SPI_MISO),
    .S_SPI_MOSI(SPI_MOSI),
    .S_CHAR_DONE(slv1_char_done),
    .S_WCHAR(32'h78563412),        // output character
    .S_RCHAR(slv1_data_rx)          // input character
);

initial
begin
    txdata[0] = SPITF_VAL;
    txdata[1] = 32'h12345678;
    txdata[2] = 32'h78563412;
    txdata[3] = 32'h00000000;
    txdata[4] = 32'h11223344;
    txdata[5] = 32'h55aa55aa;
    txdata[6] = 32'hffffffff;
    txdata[7] = 32'h01020304;
    txdata[8] = 32'h01050a0f;
    txdata[9] = 32'h102030f0;
    #50000;
    $stop;
end

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
    CSMODE1 <= CSMODE_DEF;


    #100;
    rst_n      <= 1;      // module reset
    #100;
    SPMODE  <= SPMODE_VAL;
    SPIE    <= SPIE_VAL;
    SPIM    <= SPIM_VAL;
    SPCOM   <= SPCOM_CS0;
    SPITF   <= SPITF_VAL;
    SPIRF   <= SPIRF_VAL;
    CSMODE0 <= CS0MODE_VAL;
    CSMODE1 <= CS1MODE_VAL;

    $display("[%t] case #1 test the tx fifo is full or not", $time);
    // clear SPIE flags
    master.regwrite(ADDR_SPIE, 32'hFFFF_FFFF, 2);

    master.regwrite(ADDR_SPMODE, SPMODE_VAL, 2);
    for (idx = 0; idx < NWORD_TXFIFO+1; idx = idx + 1) begin
        master.regread(ADDR_SPIE, SPIE, 2);
        master.regwrite(ADDR_SPITF, txdata[idx], 2);
        $display("[%t] idx=%02d,SPIE: %h,TXCNT=%d,TNF=%d,TXE=%d,TXT=%d,RXCNT=%d,RXF=%d,RNE=%d,RXT=%d",$time,idx,SPIE,SPIE[SPIE_TXCNT_HI:SPIE_TXCNT_LO],SPIE[SPIE_TNF],SPIE[SPIE_TXE],SPIE[SPIE_TXT],SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO],SPIE[SPIE_RXF],SPIE[SPIE_RNE],SPIE[SPIE_RXT]);
    end
    master.regread(ADDR_SPIE, SPIE, 2);
    $display("[%t] idx=%02d,SPIE: %h,TXCNT=%d,TNF=%d,TXE=%d,TXT=%d,RXCNT=%d,RXF=%d,RNE=%d,RXT=%d",$time,idx,SPIE,SPIE[SPIE_TXCNT_HI:SPIE_TXCNT_LO],SPIE[SPIE_TNF],SPIE[SPIE_TXE],SPIE[SPIE_TXT],SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO],SPIE[SPIE_RXF],SPIE[SPIE_RNE],SPIE[SPIE_RXT]);
    if (SPIE[SPIE_TNF] == 1'b0) begin
        $display("[%t] case #1 test ok", $time);
    end
    else begin
        $display("[%t] case #1 test failed!", $time);
    end

    $display("[%t] case #2 select cs#0 and write 3byte than read 4 bytes", $time);

    // diable SPI to reset the txfifo
    master.regwrite(ADDR_SPMODE, SPMODE_DEF, 2);
    // clear SPIE flags
    master.regwrite(ADDR_SPIE, 32'hFFFF_FFFF, 2);
    // renable SPI
    master.regwrite(ADDR_SPMODE, SPMODE_VAL, 2);

    master.regwrite(ADDR_CSMODE0, CS0MODE_VAL, 2);

    master.regwrite(ADDR_SPIM, SPIM_VAL, 2);

    master.regwrite(ADDR_SPCOM, SPCOM_CS0, 2);

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
    master.regread(ADDR_SPIE, SPIE, 2);
    $display("[%t] SPIE: %h,TXCNT=%d,TNF=%d,TXE=%d,TXT=%d,RXCNT=%d,RXF=%d,RNE=%d,RXT=%d",$time,SPIE,SPIE[SPIE_TXCNT_HI:SPIE_TXCNT_LO],SPIE[SPIE_TNF],SPIE[SPIE_TXE],SPIE[SPIE_TXT],SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO],SPIE[SPIE_RXF],SPIE[SPIE_RNE],SPIE[SPIE_RXT]);
    master.regread(ADDR_SPIRF, SPIRF, 2);
    $display("[%t] SPIRF: %h", $time, SPIRF);
    master.regread(ADDR_SPIE, SPIE, 2);
    while (1'b0 == SPIE[SPIE_DON]) begin
        master.regread(ADDR_SPIE, SPIE, 2);
        #100;
    end
    $display("[%t] frame done,SPIE: %h,DON=%d,RXCNT=%d",$time,SPIE,SPIE[SPIE_DON],SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO]);
    if (SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO] == 0) begin
        $display("[%t] case #2 test ok", $time);
    end
    else begin
        $display("[%t] case #2 test failed!", $time);
    end

    $display("[%t] case #3 select cs#1 and write 2byte than read 7 bytes", $time);
    // wait pre frame done
    master.regread(ADDR_SPIE, SPIE, 2);
    while (~SPIE[SPIE_TXE]) begin
        master.regread(ADDR_SPIE, SPIE, 2);
    end
    #500;
    // clear SPIE flags
    // master.regwrite(ADDR_SPMODE, SPMODE_DEF, 2);
    // clear SPIE flags
    master.regwrite(ADDR_SPIE, 32'hFFFF_FFFF, 2);
    // renable SPI
    // master.regwrite(ADDR_SPMODE, SPMODE_VAL, 2);

    master.regwrite(ADDR_CSMODE1, CS1MODE_VAL, 2);

    master.regwrite(ADDR_SPITF, 32'h78563412, 2);

    master.regwrite(ADDR_SPCOM, SPCOM_CS1, 2);

    master.regwrite(ADDR_SPITF, 32'h11223344, 2);
    master.regwrite(ADDR_SPITF, 32'h12345678, 2);

    master.regread(ADDR_SPIE, SPIE, 2);
    while (SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO] < 6'h04) begin
        master.regread(ADDR_SPIE, SPIE, 2);
    end
    master.regread(ADDR_SPIE, SPIE, 2);
    $display("[%t] SPIE: %h,TXCNT=%d,TNF=%d,TXE=%d,TXT=%d,RXCNT=%d,RXF=%d,RNE=%d,RXT=%d",$time,SPIE,SPIE[SPIE_TXCNT_HI:SPIE_TXCNT_LO],SPIE[SPIE_TNF],SPIE[SPIE_TXE],SPIE[SPIE_TXT],SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO],SPIE[SPIE_RXF],SPIE[SPIE_RNE],SPIE[SPIE_RXT]);
    master.regread(ADDR_SPIRF, SPIRF, 2);
    $display("[%t] SPIRF: %h", $time, SPIRF);
    master.regread(ADDR_SPIE, SPIE, 2);
    $display("[%t] SPIE: %h,TXCNT=%d,TNF=%d,TXE=%d,TXT=%d,RXCNT=%d,RXF=%d,RNE=%d,RXT=%d",$time,SPIE,SPIE[SPIE_TXCNT_HI:SPIE_TXCNT_LO],SPIE[SPIE_TNF],SPIE[SPIE_TXE],SPIE[SPIE_TXT],SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO],SPIE[SPIE_RXF],SPIE[SPIE_RNE],SPIE[SPIE_RXT]);

    master.regread(ADDR_SPIE, SPIE, 2);
    while (SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO] < 6'h03) begin
        master.regread(ADDR_SPIE, SPIE, 2);
    end
    master.regread(ADDR_SPIE, SPIE, 2);
    $display("[%t] SPIE: %h,TXCNT=%d,TNF=%d,TXE=%d,TXT=%d,RXCNT=%d,RXF=%d,RNE=%d,RXT=%d",$time,SPIE,SPIE[SPIE_TXCNT_HI:SPIE_TXCNT_LO],SPIE[SPIE_TNF],SPIE[SPIE_TXE],SPIE[SPIE_TXT],SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO],SPIE[SPIE_RXF],SPIE[SPIE_RNE],SPIE[SPIE_RXT]);
    master.regread(ADDR_SPIRF, SPIRF, 2);
    $display("[%t] SPIRF: %h", $time, SPIRF);
    master.regread(ADDR_SPIE, SPIE, 2);
    $display("[%t] SPIE: %h,TXCNT=%d,TNF=%d,TXE=%d,TXT=%d,RXCNT=%d,RXF=%d,RNE=%d,RXT=%d",$time,SPIE,SPIE[SPIE_TXCNT_HI:SPIE_TXCNT_LO],SPIE[SPIE_TNF],SPIE[SPIE_TXE],SPIE[SPIE_TXT],SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO],SPIE[SPIE_RXF],SPIE[SPIE_RNE],SPIE[SPIE_RXT]);

    // clear SPIE flags
    // new spi frame start
    //SPIE[SPIE_DON]
    master.regread(ADDR_SPIE, SPIE, 2);
    $display("[%t] SPIE: %h, DON=%d", $time, SPIE, SPIE[SPIE_DON]);
    while (1'b0 == SPIE[SPIE_DON]) begin
        master.regread(ADDR_SPIE, SPIE, 2);
        #100;
    end
    $display("[%t] SPIE: %h,DON=%d,RXCNT=%d",$time,SPIE,SPIE[SPIE_DON],SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO]);
    if (SPIE[SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO]] == 0) begin
        $display("[%t] case #3 test ok", $time);
    end
    else begin
        $display("[%t] case #3 test failed!", $time);
    end

    $display("[%t] case #4 select cs#1, test the rx fifo is full", $time);
    master.regwrite(ADDR_SPIE, 32'hFFFF_FFFF, 2);
    master.regread(ADDR_SPIE, SPIE, 2);
    $display("[%t] SPIE: %h,TXCNT=%d,TNF=%d,TXE=%d,TXT=%d,RXCNT=%d,RXF=%d,RNE=%d,RXT=%d",$time,SPIE,SPIE[SPIE_TXCNT_HI:SPIE_TXCNT_LO],SPIE[SPIE_TNF],SPIE[SPIE_TXE],SPIE[SPIE_TXT],SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO],SPIE[SPIE_RXF],SPIE[SPIE_RNE],SPIE[SPIE_RXT]);

    #1000;
    master.regwrite(ADDR_SPCOM, ((1 << SPCOM_CS_LO)|(2<<SPCOM_RSKIP_LO)|((NBYTES_RXFIFO+3)<<SPCOM_TRANLEN_LO)), 2);

    for (idx = 0; idx < NWORD_TXFIFO+1; idx = idx + 1) begin
        master.regread(ADDR_SPIE, SPIE, 2);
        while (~SPIE[SPIE_TNF]) begin
            master.regread(ADDR_SPIE, SPIE, 2);
            #1000;
        end
        master.regwrite(ADDR_SPITF, txdata[idx], 2);
    end
    $display("[%t] wait rx fifo full", $time);
    master.regread(ADDR_SPIE, SPIE, 2);
    while (SPIE[SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO]] < NBYTES_RXFIFO) begin
        master.regread(ADDR_SPIE, SPIE, 2);
    end
    $display("[%t] SPIE: %h,TXCNT=%d,TNF=%d,TXE=%d,TXT=%d,RXCNT=%d,RXF=%d,RNE=%d,RXT=%d",$time,SPIE,SPIE[SPIE_TXCNT_HI:SPIE_TXCNT_LO],SPIE[SPIE_TNF],SPIE[SPIE_TXE],SPIE[SPIE_TXT],SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO],SPIE[SPIE_RXF],SPIE[SPIE_RNE],SPIE[SPIE_RXT]);
    if (SPIE[SPIE_RXF] == 1'b1) begin
        $display("[%t] case #4 test ok", $time);
    end
    else begin
        $display("[%t] case #4 test failed", $time);
    end

    $display("[%t] case #4 read out all received data", $time);
    idx = 0;
    master.regread(ADDR_SPIE, SPIE, 2);
    while (SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO] > 4) begin
        master.regread(ADDR_SPIRF,SPIRF, 2);
        master.regread(ADDR_SPIE, SPIE, 2);
        idx = idx + 1;
        $display("[%t] idx=%02d,SPIRF: %h,RXCNT=%d",$time,idx,SPIRF,SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO]);
    end

    // wait this frame to be done
    master.regread(ADDR_SPIE, SPIE, 2);
    while (1'b0 == SPIE[SPIE_DON]) begin
        master.regread(ADDR_SPIE, SPIE, 2);
        #100;
    end
    $display("[%t] SPIE: %h,DON=%d,RXCNT=%d",$time,SPIE,SPIE[SPIE_DON],SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO]);
    if (SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO] > 0) begin
        master.regread(ADDR_SPIRF,SPIRF, 2);
        $display("[%t] SPIRF: %h", $time, SPIRF);
    end

    master.regread(ADDR_SPIE, SPIE, 2);
    $display("[%t] SPIE: %h,TXCNT=%d,TNF=%d,TXE=%d,TXT=%d,RXCNT=%d,RXF=%d,RNE=%d,RXT=%d",$time,SPIE,SPIE[SPIE_TXCNT_HI:SPIE_TXCNT_LO],SPIE[SPIE_TNF],SPIE[SPIE_TXE],SPIE[SPIE_TXT],SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO],SPIE[SPIE_RXF],SPIE[SPIE_RNE],SPIE[SPIE_RXT]);

    // at last disable spi
    #500;
    // diable SPI to reset the txfifo
    master.regwrite(ADDR_SPMODE, SPMODE_DEF, 2);
    #500;

end

endmodule

