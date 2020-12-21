`include "timescale.v"


module spi_clk_gen #
( parameter N = 8)
(
    input  sysclk,         // system clock input
    input  rst_n,           // module reset
    input  enable,              // module enable
    input  go,              // start transmit
    input  CPOL,            // clock polarity
    input  last_clk,        // last clock 
    input  [N-1:0] divider_i, // divider;
    output reg clk_out,         // clock output
    output reg pos_edge,    // positive edge flag
    output reg neg_edge     // negtive edge flag
);

wire cnt_zero;
wire cnt_one;
reg [N-1:0] cnt;
reg in_process;

assign cnt_zero = (cnt == {N{1'b0}});
assign cnt_one  = (cnt == {{N-1{1'b0}}, 1'b1});

always @(posedge sysclk or negedge rst_n)
begin
    if (!rst_n)
    begin
        cnt   <= {N{1'b1}};
    end
    else
    begin
        if (!enable || cnt_zero || !go)
            cnt   <= divider_i;
        else
            cnt <= cnt - {{N-1{1'b0}}, 1'b1};
    end
end

always @(negedge last_clk or negedge rst_n)
begin
    clk_out <= CPOL;
end


// clock out
always @(posedge sysclk or negedge rst_n)
begin
    if (!rst_n || !enable)
        clk_out <= CPOL;
    else
        if (go)
            clk_out <= (enable && cnt_zero && (!last_clk || clk_out)) ? ~clk_out : clk_out;
        else
            clk_out <= CPOL;
end

// pos neg signals
always @(posedge sysclk or negedge rst_n)
begin
    if (!rst_n || !enable)
    begin
        pos_edge <= 1'b0;
        neg_edge <= 1'b0;
    end
    else
    begin
        pos_edge <= (enable && !clk_out && cnt_one) || (!(|divider_i) && clk_out) || (!(|divider_i) && go && !enable);
        neg_edge <= (enable && clk_out && cnt_one) || (!(|divider_i) && !clk_out && enable);
    end
end

endmodule

