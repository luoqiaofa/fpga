`include "timescale.v"

module spi_tb;
    localparam C_DIVIDER_WIDTH = 8;
    localparam CHAR_NBITS = 8;
    localparam CHAR_LEN_MAX = 16;
    reg sysclk;            // system clock input
    reg rst_n;             // module reset
    reg enable;            // module enable
    reg go;                // start transmit
    reg CPOL;              // clock polarity
    reg CPHA;              // clock phase
    reg LOOP;              // loop mode test
    reg MSB_FIRST;
    reg [C_DIVIDER_WIDTH-1:0] divider_i; // divider;
    reg [CHAR_NBITS - 1: 0] data_in;
    reg [3:0] char_len;


wire SPI_SCK;
wire SPI_MISO;
wire SPI_MOSI;
wire [3:0] SPI_CS_B;

pullup pullup_miso (SPI_MISO);

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
    CPOL       <= 0;      // clock polarity
    CPHA       <= 0;      // clock phase
    LOOP       <= 0;
    MSB_FIRST  <= 1;
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

    #1000
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
reg [REG_WIDTH-1: 0] SPMODE1;
reg [REG_WIDTH-1: 0] SPMODE2;
reg [REG_WIDTH-1: 0] SPMODE3;

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

wire S_SPI_SCK;
wire S_SPI_MISO;
wire S_SPI_MOSI;
wire [3:0 ] S_SPI_CS_B;

reg S_BREADY;
wire S_BVALID;

`include "reg-bit-def.v"

initial
begin
    SPMODE  <= 32'h0000_100F;
    SPIE    <= 32'h0020_0000;
    SPIM    <= 32'h0000_0000;
    SPCOM   <= 32'h0000_0000;
    SPITF   <= 32'h0000_0000;
    SPIRF   <= 32'h0000_0000;
    SPIREV1 <= 32'h0000_0000;
    SPIREV2 <= 32'h0000_0000;
    SPMODE0 <= 32'h0010_0000;
    SPMODE1 <= 32'h0010_0000;
    SPMODE2 <= 32'h0010_0000;
    SPMODE3 <= 32'h0010_0000;

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
    SPIE <= 32'hFFFF_FFFF;  
    SPMODE <= 32'h8000_100F;
    SPMODE0 <= 32'h2417_1108;
    SPITF <= 32'h0300_4000;
    SPCOM <= 32'h0003_0026;
    #50;

    S_AWADDR <= ADDR_SPIE;
    S_WDATA <= SPIE;
    #10;

    S_WVALID <= 1;
    S_AWVALID <= 1;

    S_BREADY <= 1;

    S_RREADY <= 1;
    S_ARVALID <= 1;

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
    S_WDATA <= 32'h2417_1108;
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
    #10;
end
/*
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
    .S_SPI_SCK(SPI_SCK),
    .S_SPI_MISO(SPI_MISO),
    .S_SPI_MOSI(SPI_MOSI),
    .S_SPI_CS_B(SPI_CS_B)
);
*/
// /*
spi_trx_one_char #(.CHAR_NBITS(CHAR_LEN_MAX))
inst_spi_trx_ch
(
    .S_SYSCLK(sysclk),  // platform clock
    .S_RESETN(rst_n),  // reset
    .S_ENABLE(enable),  // enable
    .S_CPOL(CPOL),    // clock polary
    .S_CPHA(CPHA),    // clock phase, the first edge or second
    .S_TX_ONLY(1'b0), // transmit only
    .S_LOOP(LOOP),    // internal loopback mode
    .S_REV(MSB_FIRST),     // msb first or lsb first
    .S_CHAR_LEN(char_len),// characters in bits length
    .S_NDIVIDER(divider_i),// clock divider
    .S_SPI_SCK(SPI_SCK),
    .S_SPI_MISO(SPI_MISO),
    .S_SPI_MOSI(SPI_MOSI),
    .S_CHAR_GO(go),
    .S_CHAR_DONE(s_done),
    .S_WCHAR(data_tx),   // output character
    .S_RCHAR(data_rx)    // input character
);

always @(posedge s_done)
begin
    go <= 0;
    data_tx <= data_tx + 1;
    data_in <= data_rx[7:0];
end

// */

spi_slave_model #(.CHAR_NBITS(16))
inst_slave
(
    .S_SYSCLK(sysclk),  // platform clock
    .S_RESETN(rst_n),  // reset
    .S_ENABLE(enable),  // enable
    .S_CPOL(CPOL),    // clock polary
    .S_CPHA(CPHA),    // clock phase, the first edge or second
    .S_TX_ONLY(1'b0), // transmit only
    .S_REV(MSB_FIRST),     // msb first or lsb first
    .S_CHAR_LEN(char_len),// characters in bits length
    .S_SPI_SCK(SPI_SCK),
    .S_SPI_MISO(SPI_MISO),
    .S_SPI_MOSI(SPI_MOSI),
    .S_CHAR_GO(go),
    .S_CHAR_DONE(s_done)
);

endmodule

