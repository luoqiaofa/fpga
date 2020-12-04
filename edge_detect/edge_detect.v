// from https://blog.csdn.net/qq_26652069/article/details/100555881
`include "timescale.v"
module Edge_Detect(
    clk_i    , 
    rst_n_i  , 
    dat_i    , 
    pos_edge , 
    neg_edge , 
    data_edge
);

input       clk_i    ;
input       rst_n_i  ;
input       dat_i    ;
output wire pos_edge ;
output wire neg_edge ;
output wire data_edge;
reg  [1:0]  data_r;

//相当于对dat_i 打两拍data_r[0] data_r[1]
always @(posedge clk_i or negedge rst_n_i)
begin
    if(rst_n_i == 1'b0)
    begin
        data_r <= 2'b00;
    end
    else
    begin
        data_r <= {data_r[0], dat_i};
    end
end

assign pos_edge = ~data_r[1] & data_r[0];
// 上 升 沿 
assign neg_edge = data_r[1] & ~data_r[0];
// 下 降 沿
assign data_edge = pos_edge | neg_edge;
// 数 据 沿

endmodule

