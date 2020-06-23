`timescale 1ns/1ps

module spi_tb;
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
    $dumpfile("wave.vcd");        //生成的vcd文件名称
    $dumpvars(0, spi_tb);    //tb模块名称
end


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

endmodule

