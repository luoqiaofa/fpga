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
    reg[31:0]   freq_cnt;
    reg[31:0]   duty;
    wire        pwm_out;
    wire        pwm_top;
parameter SYS_FREQ = 100000000;
parameter BRIGHTNESS_FREQ = (SYS_FREQ >> 8) - 1;
// parameter BRIGHTNESS = 0;
localparam POLAR = 1;
localparam DUTY = 50;
localparam BRIGHTNESS = 200;
// localparam BRIGHTNESS = 255;
localparam FREQ_CNT = 16384;
localparam DUTY_CNT = (DUTY * FREQ_CNT) / 100;
// localparam DUTY_CNT = FREQ_CNT;
// parameter BRIGHTNESS = 255;
// wire div_2hz_o;
pwm_module pwm_obj (
    .I_SYS_CLK(clk_i),
    .I_RESETN(rst_n_i),
    .I_PWM_MODE(mode),
    .I_PWM_FREQ_CNT(freq_cnt),
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
    freq_cnt <= FREQ_CNT;
    duty     <= DUTY_CNT;
    mode   <= 0;
    #15
    rst_n_i = 1;
    #500
    mode   <= 1;
    #(2*FREQ_CNT*10)
    mode   <= 0;
    #(2*FREQ_CNT)
    mode   <= (1 + (2 * POLAR));
    #(2*FREQ_CNT*10)
    $stop;
end

always #5 clk_i = ~clk_i;


endmodule
