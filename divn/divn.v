//copy from https://www.cnblogs.com/shengansong/archive/2012/04/25/2469795.html
//divn.v / Verilog

module divn    (
    input clk,
    input rst_n,
    input [7:0] div,
    output o_clk
);

parameter WIDTH = 8;
// parameter N     = 3;

reg [WIDTH-1:0] cnt_p;// 上升沿计数单位
reg [WIDTH-1:0] cnt_n;// 下降沿计数单位
reg             clk_p;// 上升沿时钟
reg             clk_n;// 下降沿时钟

assign o_clk = (div == 1) ? clk : (div[0]) ? (clk_p | clk_n) : (clk_p);//其中div==1是判断不分频，div[0]是判断是奇数还是偶数，若为1则是奇数分频，若是偶数则是偶数分频。

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cnt_p <= 0;
        cnt_n <= 0;
    end
    else if (cnt_p == (div-1))
        cnt_p <= 0;
    else
        cnt_p <= cnt_p + 1;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) 
        clk_p <= 1;//此处设置为0也是可以的，这个没有硬性的要求，不管是取0还是取1结果都是正确的。
    else if (cnt_p < (div>>1))/*div整体向右移动一位，最高位补零，其实就是div/2，不过在计算奇数的时候有很明显的优越性*/
        clk_p <= 1;
    else
        clk_p <= 0;    
end

always @(negedge clk or negedge rst_n) begin
    if (!rst_n)
        cnt_n <= 0;
    else if (cnt_n == (div-1))
        cnt_n <= 0;
    else
        cnt_n <= cnt_n + 1;
end

always @(negedge clk or negedge rst_n) begin
    if (!rst_n)
        clk_n <= 1;
    else if (cnt_n < (div>>1))
        clk_n <= 1;
    else
        clk_n <= 0;
end

endmodule

