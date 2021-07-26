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
    reg[31:0]   mode;
    reg[31:0]   freq_div;
    reg[31:0]   duty;
    wire        pwm_out;
    wire        pwm_top;
parameter SYS_FREQ = 100000000;
parameter BRIGHTNESS_FREQ = (SYS_FREQ >> 8) - 1;
// parameter BRIGHTNESS = 0;
parameter BRIGHTNESS = 128;
// parameter BRIGHTNESS = 255;
// wire div_2hz_o;
pwm_module pwm_obj (
    .I_SYS_CLK(clk_i),
    .I_ASSERT(~rst_n_i),
    .I_PWM_MODE(mode),
    .I_PWM_FREQ_DIV(freq_div),
    .I_PWM_DUTY(duty),
    .I_BRIGHTNESS(BRIGHTNESS),
    .O_PWM_OUT(pwm_out)
    );

assign  pwm_top = pwm_out;

initial
begin
    $dumpfile("wave.vcd");    //生成的vcd文件名称
    $dumpvars(0);   //tb模块名称
end

initial
begin
    clk_i <= 0;
    rst_n_i <= 0;
    freq_div <= 65536;
    duty     <= 32768;
    // duty     <= 524288;
    // duty     <= 0;
    mode   <= 0;
    #15
    rst_n_i = 1;
    #500
    mode   <= 1;
    #1000
    #(4*BRIGHTNESS_FREQ)
    $stop;
end

always #5 clk_i = ~clk_i;


endmodule
