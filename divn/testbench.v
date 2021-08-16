// divn_tb.v / Verilog

`timescale 1ns/10ps
module divn_tb;
reg i_clk;
reg i_resetn;
wire o_clk_div2;
wire o_clk_div3;
wire o_clk_div4;
wire o_clk_div5;

clk_divn clk_divn_u0 (
    .i_clk(i_clk),
    .i_resetn(i_resetn),
    .i_divn(8'h02),
    .o_clk(o_clk_div2)
);

clk_divn clk_divn_u1 (
    .i_clk(i_clk),
    .i_resetn(i_resetn),
    .i_divn(8'h03),
    .o_clk(o_clk_div3)
);
clk_divn clk_divn_u2 (
    .i_clk(i_clk),
    .i_resetn(i_resetn),
    .i_divn(8'h04),
    .o_clk(o_clk_div4)
);
clk_divn clk_divn_u3 (
    .i_clk(i_clk),
    .i_resetn(i_resetn),
    .i_divn(8'h05),
    .o_clk(o_clk_div5)
);


initial begin
    $dumpfile("wave.vcd");    //生成的vcd文件名称
    $dumpvars(0);   //tb模块名称
    i_clk   = 1'b0;
    i_resetn = 1'b0;
    #40
    i_resetn = 1'b1;/*这一步是一定要加上的，因为，如果不加的话就等于没有进行初始化，输出信息是没有的，这一点已经验证过了*/
    #100000
    $stop;
end

// 50MHz i_clk
always #5 i_clk = ~i_clk;

endmodule
