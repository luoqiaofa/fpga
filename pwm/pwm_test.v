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


module pwm_test;
    reg         clk_i;
    reg         rst_n_i;
    reg[31:0]   period;
    reg[31:0]   duty;
    wire        pwm_out;

    // wire div_2hz_o;
ax_pwm pwm_obj (
    .clk(clk_i),
    .rst(~rst_n_i),
    .period(period),
    .duty(duty),
    .pwm_out(pwm_out)
    );


initial
begin
    $dumpfile("wave.vcd");    //生成的vcd文件名称
    $dumpvars(0, pwm_test);   //tb模块名称
end

initial
begin
     clk_i <= 0;
     rst_n_i <= 0;
     period <= 10;
     duty   <= 5;
    #15
    rst_n_i = 1;
    #500
    duty   <= 2;
    #500
    duty   <= 7;
    #500
    duty   <= 1;
    #500
    duty   <= 0;
    #200
    period <= 0;
    #200
    duty   <= 10;
    #200
    period <= 100;
    duty <= 50;
    #10000
    duty   <= 80;
    #10000
    duty   <= 100;
    #5000
    $stop;
end

always #5 clk_i = ~clk_i;

endmodule
