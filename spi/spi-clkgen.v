`include "timescale.v"


module spi_clk_gen #
(parameter integer C_DIVIDER_WIDTH = 8)
(
    input  sysclk,          // system clock input
    input  rst_n,           // module reset
    input  enable,          // module enable
    input  go,              // start transmit
    input  CPOL,            // clock polarity
    input  last_clk,        // last clock 
    input  [C_DIVIDER_WIDTH-1:0] divider_i, // divider_i;
    output reg clk_out,     // clock output
    output reg pos_edge,    // positive edge flag
    output reg neg_edge     // negtive edge flag
);

wire cnt_zero;
wire cnt_one;
reg [C_DIVIDER_WIDTH-1:0] cnt;

assign cnt_zero = (cnt == {C_DIVIDER_WIDTH{1'b0}});
assign cnt_one  = (cnt == {{C_DIVIDER_WIDTH-1{1'b0}}, 1'b1});


// Counter counts half period
always @(posedge sysclk/* or negedge rst_n*/)
begin
    if(rst_n == 1'b0)
        cnt <= {C_DIVIDER_WIDTH{1'b1}};
    else
    begin
        if(!enable || cnt_zero)
            cnt <= divider_i;
        else
            cnt <= cnt - {{C_DIVIDER_WIDTH-1{1'b0}}, 1'b1};
    end
end

// clk_out is asserted every other half period
always @(posedge sysclk/* or negedge rst_n */)
begin
    if(rst_n == 1'b0)
        clk_out <= CPOL;
    else
        if (enable) begin
            clk_out <= (enable && cnt_zero && (!last_clk || clk_out)) ? ~clk_out : clk_out;
        end
        else begin
            clk_out <= CPOL;
        end
end

// Pos and neg edge signals
always @(posedge sysclk /* or negedge rst_n */)
begin
    if(rst_n == 1'b0)
    begin
        pos_edge  <= 1'b0;
        neg_edge  <= 1'b0;
    end
    else
    begin
        pos_edge  <= (enable && !clk_out && cnt_one) || (!(|divider_i) && clk_out) || (!(|divider_i) && go && !enable);
        neg_edge  <= (enable && clk_out && cnt_one) || (!(|divider_i) && !clk_out && enable);
    end
end

endmodule

