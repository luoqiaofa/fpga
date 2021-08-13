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
module pwm_test();
    reg       s_clk_i;
    reg       s_rst_n_i;
    reg[1:0]  s_mode;
    reg[31:0] s_freq_cnt;
    reg[31:0] s_duty_cnt;
    wire      s_pwm_out;

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
        .i_sysclk(s_clk_i),
        .i_resetn(s_rst_n_i),
        .i_enable(s_mode[0]),
        .i_polar(s_mode[1]),
        .i_freq_cnt(s_freq_cnt),
        .i_duty_cnt(s_duty_cnt),
        .i_brightness(BRIGHTNESS),
        .o_pwm_out(s_pwm_out)
    );


    initial
    begin
        $dumpfile("wave.vcd");    //生成的vcd文件名称
        $dumpvars(0);   //tb模块名称
    end

    initial
    begin
        s_clk_i <= 0;
        s_rst_n_i <= 0;
        s_freq_cnt <= FREQ_CNT;
        s_duty_cnt <= DUTY_CNT;
        s_mode   <= 0;
        #15
        s_rst_n_i = 1;
        #500
        s_mode   <= 1;
        #(2*FREQ_CNT*10)
        s_mode   <= 0;
        #(2*FREQ_CNT)
        s_mode   <= (1 + (2 * POLAR));
        #(2*FREQ_CNT*10)
        $stop;
    end

    always #5 s_clk_i = ~s_clk_i;

endmodule

