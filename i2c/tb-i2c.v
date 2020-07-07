`include "timescale.v"

module tb_i2c;
`include "i2c-def.v"
`include "i2c-reg-def.v"

reg           sysclk_i;  // system clock input
reg           reset_n_i; // module reset input
reg           wr_ena_i;  // write enable
wire [4:0]    wr_addr_i; // write address
wire [7:0]    wr_data_i; // write date input
reg           rd_ena_i;  // read enable input
wire [4:0]    rd_addr_i; // read address input
wire [7:0]    rd_data_o; // read date output
wire          scl_pin;   // scl pad pin
wire          sda_pin;    // sda pad pin

reg  [4:0]    wr_addr;
reg  [7:0]    wr_data;
reg  [4:0]    rd_addr;
reg  [7:0]    rd_data;

assign wr_addr_i = wr_addr;
assign wr_data_i = wr_data;
assign rd_addr_i = rd_addr;
assign rd_data_i = rd_data;

i2c_top_module i2c_master_u1(
    .sysclk_i(sysclk_i),   // system clock input
    .reset_n_i(reset_n_i), // module reset input
    .wr_ena_i(wr_ena_i),   // write enable
    .wr_addr_i(wr_addr_i), // write address
    .wr_data_i(wr_data_i), // write date input
    .rd_ena_i(rd_ena_i),   // read enable input
    .rd_addr_i(rd_addr_i), // read address input
    .rd_data_o(rd_data_o), // read date output
    .scl_pin(scl_pin),     // scl pad pin
    .sda_pin(sda_pin)      // sda pad pin
);

initial
begin            
$dumpfile("wave.vcd");    //生成的vcd文件名称
$dumpvars(0);   //tb模块名称
end 

initial
begin
    sysclk_i <= 0;
    reset_n_i <= 0;
    wr_ena_i <= 0;
    rd_ena_i <= 0;

    wr_addr <= 0;
    wr_data <= 0;
    rd_addr <= 0;
    rd_data <= 0;

    #50
    reset_n_i <= 1;
    #10
    wr_addr <= (1 << 2);
    wr_ena_i  <= 1;
    wr_data   <= 8'h07;
    #20;
    wr_ena_i  <= 0;
    #100
    wr_data   <= 8'hb0;
    wr_addr <= (ADDR_CR << 2);
    wr_ena_i  <= 1;
    #20;
    wr_ena_i  <= 0;
    // [BIT_MIEN] & I2CCR[BIT_MSTA]
    #100000
    $stop;
    $finish;
end

always #2 sysclk_i = ~sysclk_i;

endmodule
