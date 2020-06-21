`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/05/28 17:57:09
// Design Name: 
// Module Name: div_test
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module div_test(

    );
    reg clk_i;
    reg rst_n_i;
    wire div_2_o;
    wire div_4_o;
    wire div_8_o;
    wire div_3_o;

    // wire div_2hz_o;
    div_clk u1(
      .clk_i(clk_i),
      .rst_n_i(rst_n_i),
      .div_2_o(div_2_o),
      .div_4_o(div_4_o),
      .div_8_o(div_8_o)
      // .div_2hz_o(div_2hz_o)
    );

 div3_clk div3_obj(
      .I_clk(clk_i),
      .I_rst_n(rst_n_i),
      .O_clk_div3(div_3_o)
 );

initial
begin            
    $dumpfile("wave.vcd");    //生成的vcd文件名称
    $dumpvars(0, div_test);   //tb模块名称
end 

initial 
begin
     clk_i = 0;
     rst_n_i = 0;
    #15
    rst_n_i = 1;
    #1000
    $stop;
end

always #5 clk_i = ~clk_i;

endmodule
