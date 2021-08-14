//////////////////////////////////////////////////////////////////////////////////
//                                                                              //
//  Author: luoqiaofa                                                           //
//          luoqiaofa@163.com                                                   //
//      origin from : http://www.alinx.cn/ heijin                               //
//          ALINX(shanghai) Technology Co.,Ltd                                  //
//                                                                              //
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
//   Description: pwm model
//   i_sysclk     platform clock input
//   i_resetn     normally is reset
//   i_enable     pwm mode, BIT0: enable or disable
//                          BIT1: 1 for negtive, 0 for positive
//   i_polar      enectric level polar, 0: hi active, 1: low active
//   i_freq_cnt frequency(i_sysclk) frequency divider
//   i_duty_cnt     duty circle ratio, 1~50 integer
//   o_pwm_out frequency = frequency(i_sysclk) / i_freq_cnt;
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
	parameter C_DATA_WIDTH = 32 //pwm bit width
)
(
    input                       i_sysclk,
    input                       i_resetn,
    input                       i_enable,
    input                       i_polar,
    input  [C_DATA_WIDTH - 1:0] i_freq_cnt,
    input  [C_DATA_WIDTH - 1:0] i_duty_cnt,
    input  [7:0]                i_brightness,
    output                      o_pwm_out
    );

localparam BRIGHTNESS_MAX = 256;

reg s_pwm;
reg s_brightness;
reg [C_DATA_WIDTH - 1:0] s_period_cnt;
reg [C_DATA_WIDTH - 1:0] s_brightness_cnt;

// assign o_pwm_out = s_pwm;
assign o_pwm_out = i_polar ? ~(s_pwm & s_brightness) : (s_pwm & s_brightness);

always@(posedge i_sysclk or negedge i_resetn)
begin
    if(!i_resetn) begin
        s_period_cnt <= { C_DATA_WIDTH {1'b0} };
        s_brightness_cnt <= 0;
    end 
    else begin
        if (i_enable) begin
            if (i_freq_cnt == 0) begin
                s_period_cnt <= 0;
            end
            else if (s_period_cnt >= (i_freq_cnt - 1)) begin
                s_period_cnt <= 0;
            end
            else begin
                s_period_cnt <= s_period_cnt + 1;
            end
            if (s_brightness_cnt < (BRIGHTNESS_MAX - 1)) begin
                s_brightness_cnt <= s_brightness_cnt + 1;
            end
            else begin
                s_brightness_cnt <= 0;
            end
        end
        else begin
            s_period_cnt <= 0;
            s_brightness_cnt <= 0;
        end
    end
end

always@(posedge i_sysclk or negedge i_resetn)
begin
    if(!i_resetn) begin
        s_pwm <= 0;
        s_brightness <= 1'b0;
    end
    else begin
        if (i_enable) begin
            if ((0 == i_duty_cnt) || (0 == i_freq_cnt)) begin
                s_pwm <= 1'b0;
                s_brightness <= 1'b0;
            end
            else if ((s_period_cnt < i_duty_cnt) || (i_duty_cnt >= i_freq_cnt)) begin
                s_pwm <= 1'b1;
                if (i_brightness < (BRIGHTNESS_MAX - 1)) begin
                    if (0 == i_brightness) begin
                        s_brightness <= 1'b0;
                    end
                    else if (s_brightness_cnt < (i_brightness)) begin
                        s_brightness <= 1'b1;
                    end
                    else begin
                        s_brightness <= 1'b0;
                    end
                end
                else begin
                    s_brightness <= 1'b1;
                end
            end
            else begin
                s_pwm <= 1'b0;
                s_brightness <= 1'b0;
            end

        end // if (i_enable) end
        else begin
            s_pwm <= 1'b0;
            s_brightness <= 1'b0;
        end
    end // if(i_resetn) end
end

endmodule

