`include "timescale.v"

module spi_tb;
    localparam N = 8;
    reg I_SYS_CLK;         // system clock input
    reg I_RST_N;           // module reset
    reg I_EN;              // module enable
    reg I_GO;              // start transmit
    reg I_CPOL;            // clock polarity
    reg I_CPHA;            // clock phase
    reg I_LAST_CLK;        // last clock 
    reg [N-1:0] I_DIVIDER; // divider;
    wire O_CLK;         // clock output
    wire O_POS_EGDE;    // positive edge flag
    wire O_NEG_EGDE;     // negtive edge flag
    reg [4:0] bit_cnt;

always @(negedge O_NEG_EGDE or negedge I_RST_N)
begin
    if (!I_RST_N || !I_EN)
        ;
    else if (I_LAST_CLK & I_GO & (!I_CPOL)) begin
        I_GO <= 0;
        I_LAST_CLK <= 0;
    end
end

always @(posedge O_CLK or negedge I_RST_N)
begin
    if (!I_RST_N || !I_EN)
        bit_cnt <= 5'h7;
    else if (bit_cnt == 5'h0) begin
        bit_cnt <= 5'h7;
    end
    else
        bit_cnt <= bit_cnt - 5'h1;
        if (bit_cnt == 5'h0)
            I_LAST_CLK <= 1;
end
initial
begin            
    $dumpfile("wave.vcd");        //生成的vcd文件名称
    $dumpvars(0, spi_tb);    //tb模块名称
end

spi_clk_gen # (.N(8)) clk_gen (
    .I_SYS_CLK(I_SYS_CLK),         // system clock input
    .I_RST_N(I_RST_N),           // module reset
    .I_EN(I_EN),              // module enable
    .I_GO(I_GO),              // start transmit
    .I_CPOL(I_CPOL),            // clock polarity
    .I_LAST_CLK(I_LAST_CLK),        // last clock 
    .I_DIVIDER(I_DIVIDER), // divider;
    .O_CLK(O_CLK),         // clock output
    .O_POS_EGDE(O_POS_EGDE),    // positive edge flag
    .O_NEG_EGDE(O_NEG_EGDE)     // negtive edge flag
);

// 100 MHz axi clock input
always @(I_SYS_CLK)
    #5 I_SYS_CLK <= !I_SYS_CLK;

initial
begin            
    bit_cnt    <= 5'h7;
    I_SYS_CLK  <= 0;      // system clock input
    I_RST_N    <= 0;      // module reset
    I_EN       <= 0;      // module enable
    I_GO       <= 0;      // start transmit
    I_CPOL     <= 0;      // clock polarity
    I_CPHA     <= 0;      // clock phase
    I_LAST_CLK <= 0;      // last clock 
    I_DIVIDER  <= 0;      // divider;
    #100
    I_RST_N    <= 1;      // module reset
    #10
    I_DIVIDER  <= 8'h04;  // divider; sys clk % 10 prescaler
    #30
    I_EN       <= 1;      // module enable
    #30
    I_GO       <= 1;      // start transmit
    #1630
    #50
    I_EN       <= 0;      // module enable
    // O_CLK,         // clock output
    // O_POS_EGDE,    // positive edge flag
    // O_NEG_EGDE     // negtive edge flag

    #1000
    $stop;
end


/*
    reg I_sysclk;
    reg I_rst_n;
    wire O_mosi;
    wire O_sck;
    reg I_miso;
    wire [3:0] O_cs;
    reg [7:0] r_txdata;
    wire [7:0] r_rxdata;
    reg [7:0] r_spi_mode;
    reg [7:0] r_sck_div;

    reg [7:0] r_test_rx_data;
    reg [2:0] r_sck_cnt;
    reg [7:0] r_trans_bytes_cnt;
    wire [7:0] r_spi_stat;

spi_module # (
    .N(8),
    .N_CS(4)
)
u_spi
(
    .I_CLK(I_sysclk),
    .I_RST_N(I_rst_n),
    .I_MISO(I_miso),
    .O_MOSI(O_mosi),
    .O_SCK(O_sck),
    .O_CS(O_cs),
    .I_TX_DATA(r_txdata),
    .O_RX_DATA(r_rxdata),
    .I_SPI_MODE(r_spi_mode),
    .I_SPI_SCK_DIV(r_sck_div),
    .O_SPI_STATUS(r_spi_stat)
);




initial
begin            
    r_sck_cnt <= 7;
    I_sysclk = 0;
    I_rst_n <= 0;
    r_txdata <= 8'haa;
    r_sck_div <= 8'd8;
    r_spi_mode <= 8'h03;
    I_miso <= 1;
    r_test_rx_data <= 8'haa;
    r_trans_bytes_cnt <= 8;
    #16
    I_rst_n <= 1;
    #2500
    // r_spi_mode <= 8'h00;
    $stop;
end


always @(I_sysclk)
    #2 I_sysclk <= !I_sysclk;

always @(posedge r_spi_stat[0])
begin
    r_txdata <= r_txdata + 1;
    r_test_rx_data <= r_test_rx_data - 1;
    #2
    r_spi_mode <= r_spi_mode | 8'h08;
    #2
    r_spi_mode <= r_spi_mode & 8'hf7;
    if (r_trans_bytes_cnt > 0)
        r_trans_bytes_cnt <= r_trans_bytes_cnt - 1;
    else
        r_spi_mode <= 8'h00;
end

always @(negedge I_rst_n or negedge O_sck)
begin
    if (!I_rst_n) begin
        r_sck_cnt <= 7;
        I_miso <= r_test_rx_data[7];
    end
    else 
        I_miso <= r_test_rx_data[r_sck_cnt];
end

always @(posedge O_sck)
begin
    r_sck_cnt <= r_sck_cnt - 1;
end
*/

endmodule

