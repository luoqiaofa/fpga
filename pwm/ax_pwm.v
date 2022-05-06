//////////////////////////////////////////////////////////////////////////////////
//                                                                              //
//  Author: luoqiaofa                                                           //
//          luoqiaofa@163.com                                                   //
//      origin from : http://www.alinx.cn/ msq@qq.com                           //
//          ALINX(shanghai) Technology Co.,Ltd                                  //
//          heijin                                                              //
//////////////////////////////////////////////////////////////////////////////////
//                                                                              //
//                                                                              //
//                    All rights reserved                                       //
//                                                                              //
// This source file may be used and distributed without restriction provided    //
// that this copyright statement is not removed from the file and that any      //
// derivative work contains the original copyright notice and the associated    //
// disclaimer.                                                                  //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////

//================================================================================
//   Description:  pwm model
//   I_SYS_CLK      platform clock input
//   I_ASSERT       normally is reset
//   I_PWM_MODE     pwm mode, BIT0: enable or disable
//                            BIT1: 1 for negtive, 0 for positive
//   I_PWM_FREQ_DIV frequency(I_SYS_CLK) frequency divider
//   I_PWM_DUTY     duty circle ratio, 1~50 integer
//   O_PWM_OUT frequency = frequency(I_SYS_CLK) / I_PWM_FREQ_DIV;
//
//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2020/06/28    luoqiaofa          1.0         Original
//********************************************************************************/
`timescale 1ns / 1ps
module pwm_module
#(
	parameter N = 32 //pwm bit width
)
(
    input            I_SYS_CLK,
    input            I_ASSERT,
    input  [N - 1:0] I_PWM_MODE,
    input  [N - 1:0] I_PWM_FREQ_DIV,
    input  [N - 1:0] I_PWM_DUTY,
    input  [N - 1:0] I_BRIGHTNESS,
    output           O_PWM_OUT
    );

localparam PWM_EN  = 0;
localparam PWM_NEG = 1;
localparam BRIGHTNESS_MAX = 256;

reg[N - 1:0] period_r;
reg[N - 1:0] duty_r;
reg[N - 1:0] period_cnt;
reg pwm_r;
reg [N-1:0] brightness_cnt;
reg brightness;

// assign O_PWM_OUT = pwm_r;
assign O_PWM_OUT = I_PWM_MODE[PWM_NEG] ? ~(pwm_r & brightness) : (pwm_r & brightness);
/* Data buffer for I_PWM_FREQ_DIV and I_PWM_DUTY  */
always@(posedge I_SYS_CLK or posedge I_ASSERT)
begin
    if(I_ASSERT)
    begin
        period_r <= { N {1'b0} };
        duty_r <= { N {1'b0} };
    end
    else
    begin
        period_r <= I_PWM_FREQ_DIV;
        duty_r   <= I_PWM_DUTY;
    end
end

always@(posedge I_SYS_CLK or posedge I_ASSERT)
begin
    if(I_ASSERT) begin
        period_cnt <= { N {1'b0} };
        brightness_cnt <= 0;
    end
    else
        if (I_PWM_MODE[PWM_EN])
        begin
            if (period_r == 0) begin
                period_cnt <= 0;
            end
            else if (period_cnt >= (period_r - 1)) begin
                period_cnt <= 0;
            end
            else begin
                period_cnt <= period_cnt + 1;
            end
            if (brightness_cnt < (BRIGHTNESS_MAX - 1)) begin
                brightness_cnt <= brightness_cnt + 1;
            end
            else begin
                brightness_cnt <= 0;
            end
        end
        else begin
            period_cnt <= 0;
            brightness_cnt <= 0;
        end
end

always@(posedge I_SYS_CLK or posedge I_ASSERT)
begin
    if(I_ASSERT)
    begin
        pwm_r <= 0;
        brightness <= 0;
    end
    else
    begin
        if (I_PWM_MODE[PWM_EN])
        begin
            if (duty_r == 0) begin
                pwm_r <= 1'b0;
                brightness <= 0;
            end
            else if(period_cnt <= duty_r) begin
                pwm_r <= 1'b1;
                if (I_BRIGHTNESS < (BRIGHTNESS_MAX - 1)) begin
                    if (0 == I_BRIGHTNESS) begin
                        brightness <= 0;
                    end
                    else if (brightness_cnt < (I_BRIGHTNESS)) begin
                        brightness <= 1;
                    end
                    else begin
                        brightness <= 0;
                    end
                end
                else begin
                    brightness <= 1;
                end
            end
            else begin
                pwm_r <= 1'b0;
                brightness <= 0;
            end

        end
        else begin
            pwm_r <= 1'b0;
            brightness <= 0;
        end
    end
end

endmodule

