`include "timescale.v"

module spi_tb;

reg clk_i     ; 
reg rst_n_i   ; 
wire dat_i    ; 
wire pos_edge ; 
wire neg_edge ; 
wire data_edge;
reg  data_r;

Edge_Detect u1(
    .clk_i    (clk_i), 
    .rst_n_i  (rst_n_i), 
    .dat_i    (dat_i), 
    .pos_edge (pos_edge), 
    .neg_edge (neg_edge), 
    .data_edge(data_edge)
);

// 100 MHz axi clock input
always @(clk_i)
    #5 clk_i <= ~clk_i;

initial
begin            
$dumpfile("wave.vcd");        //生成的vcd文件名称
$dumpvars(0, spi_tb);    //tb模块名称
data_r <= 0;
clk_i <= 0;
rst_n_i <= 0;
#20;
rst_n_i <= 1;
#20;
data_r <= 1;
#50;
data_r <= 0;
#45
data_r <= 1;
#50;
data_r <= 0;
#50
rst_n_i <= 0;
#20
data_r <= 1;
#50
rst_n_i <= 1;
#50
data_r <= 0;
#50
$stop;
end
assign dat_i = data_r;
endmodule
