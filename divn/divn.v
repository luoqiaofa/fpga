//copy from https://www.cnblogs.com/shengansong/archive/2012/04/25/2469795.html
//clk_divn.v / Verilog

module clk_divn
#(parameter CLK_DIVN_WIDTH = 8)
(
    input i_clk,
    input i_resetn,
    input [CLK_DIVN_WIDTH-1:0] i_divn,
    output o_clk
);

// parameter N     = 3;

reg [CLK_DIVN_WIDTH-1:0] s_cnt_p;// 上升沿计数单位
reg [CLK_DIVN_WIDTH-1:0] s_cnt_n;// 下降沿计数单位
reg             s_clk_p;// 上升沿时钟
reg             s_clk_n;// 下降沿时钟

//其中N==1是判断不分频，N[0]是判断是奇数还是偶数，若为1则是奇数分频，若是偶数则是偶数分频。
assign o_clk = (i_divn == 1) ? i_clk : (i_divn[0]) ? (s_clk_p | s_clk_n) : (s_clk_p);

always @(posedge i_clk) begin
    if (!i_resetn) begin
        s_cnt_p <= 0;
    end
    else if (s_cnt_p == (i_divn-1)) begin
        s_cnt_p <= 0;
    end
    else begin
        s_cnt_p <= s_cnt_p + 1;
    end
end

always @(posedge i_clk)
begin
    if (!i_resetn) begin
        //此处设置为0也是可以的，这个没有硬性的要求，不管是取0还是取1结果都是正确的。
        s_clk_p <= 0;
   end
   /*N整体向右移动一位，最高位补零，其实就是N/2，不过在计算奇数的时候有很明显的优越性*/
   else if (s_cnt_p < (i_divn>>1)) begin
       s_clk_p <= 1;
   end
   else begin
       s_clk_p <= 0;
   end
end

always @(negedge i_clk)
begin
    if (!i_resetn) begin
        s_cnt_n <= 0;
    end
    else if (s_cnt_n == (i_divn-1)) begin
        s_cnt_n <= 0;
    end
    else begin
        s_cnt_n <= s_cnt_n + 1;
    end
end

always @(negedge i_clk) begin
    if (!i_resetn) begin
        s_clk_n <= 0;
    end
    else if (s_cnt_n < (i_divn>>1)) begin
        s_clk_n <= 1;
    end
    else begin
        s_clk_n <= 0;
    end
end

endmodule

