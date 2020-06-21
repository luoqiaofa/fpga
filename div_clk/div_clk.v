`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/05/28 17:52:23
// Design Name: 
// Module Name: div_clk
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


module div_clk(
    input clk_i,
    input rst_n_i,
    output div_2_o,
    output div_4_o,
    output div_8_o,
    output div_3_o
    // output div_2hz_o
    );
    
    //div_2 module
    reg div_2;
    always @(posedge clk_i or negedge rst_n_i)
    begin
        if (! rst_n_i)begin
            div_2 <= 1'b0;
        end
        else 
            div_2 <= ~ div_2;
    end
    assign div_2_o = div_2;
    
    //count module for div_4 div_8
    reg [1:0]div_cnt;
    always @(posedge clk_i or negedge rst_n_i)
    begin
        if (! rst_n_i)begin
            div_cnt <= 2'b00;
        end
        else if (div_cnt == 2'b11)begin
            div_cnt <= 2'b00;
        end
        else
            div_cnt <= div_cnt + 1'b1;
    end
    
    reg div_4,div_8;
    
    //div_4 mudule, 四分频可以二分频的基础上继续取反，类似二分频的方法得到
    always @(posedge clk_i or negedge rst_n_i)
    begin
        if (! rst_n_i)begin 
            div_4 <= 1'b0;
        end
        else if (div_cnt == 2'b00 || div_cnt == 2'b10)begin   
            div_4 <= ~ div_4;
        end
        else 
            div_4 <= div_4;
    end
    assign div_4_o = div_4;
    
    //div_8 mudule
    always @(posedge clk_i or negedge rst_n_i)
    begin
        if (! rst_n_i)begin
            div_8 <= 1'b0;
        end
        else if ((~div_cnt[1]) && (~ div_cnt[0]))begin  //此处等价于 else if (div_cnt == 2'b00) begin
            div_8 <= ~ div_8;
        end
        else 
            div_8 <= div_8;
    end
    assign div_8_o = div_8;
    
    /*
    //2hz module
    //
    reg [25:0] div_2hz_cnt;
    reg div_2hz;
    always @(posedge clk_i or negedge rst_n_i)
    begin
        if (! rst_n_i)begin
            div_2hz_cnt <= 26'b0;
            div_2hz <= 1'b0;
        end
        else if (div_2hz_cnt == 26'd24_999999) begin
            div_2hz_cnt <= 26'b0;
            div_2hz <= ~ div_2hz;
        end
        else
        begin
            div_2hz_cnt <= div_2hz_cnt + 1'b1;
            div_2hz <= div_2hz;
        end
    end
    assign div_2hz_o = div_2hz;
    */

endmodule

/* copying from https://www.cnblogs.com/lifan3a/articles/4692874.html */
module div3_clk(
    input I_clk,
    input I_rst_n,
    output O_clk_div3
);
reg clk1;
reg[1:0]cnt1;
always@(posedge I_clk or negedge I_rst_n) begin
    if(!I_rst_n)begin   //复位
        cnt1<=0;
        clk1<=0;
    end
    else if(cnt1==1) begin
        clk1<=~clk1;   //时钟翻转
        cnt1<=cnt1+1;    //继续计数
    end
    else if(cnt1==2) begin
        clk1<=~clk1;   //时钟翻转
        cnt1<=0;    //计数清零
    end
    else
        cnt1<=cnt1+1;
end

reg clk2;
reg[1:0]cnt2;
always@(negedge I_clk or negedge I_rst_n) begin
    if(!I_rst_n)begin   //复位
        cnt2<=0;
        clk2<=0;
    end
    else if(cnt2==1) begin
        clk2<=~clk2;   //时钟翻转
        cnt2<=cnt2+1;    //继续计数
    end
    else if(cnt2==2) begin
        clk2<=~clk2;   //时钟翻转
        cnt2<=0;    //计数清零
    end
    else
        cnt2<=cnt2+1;
end

assign O_clk_div3 = clk1 | clk2;  //或运算
endmodule

