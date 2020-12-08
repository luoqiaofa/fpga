`include "timescale.v"


module spi_clk_gen #
( parameter N = 8)
(
    input  I_SYS_CLK,         // system clock input
    input  I_RST_N,           // module reset
    input  I_EN,              // module enable
    input  I_GO,              // start transmit
    input  I_CPOL,            // clock polarity
    input  I_LAST_CLK,        // last clock 
    input  [N-1:0] I_DIVIDER, // divider;
    output reg O_CLK,         // clock output
    output reg O_POS_EGDE,    // positive edge flag
    output reg O_NEG_EGDE     // negtive edge flag
);

wire cnt_zero;
wire cnt_one;
reg [N-1:0] cnt;
reg in_process;

assign cnt_zero = (cnt == {N{1'b0}});
assign cnt_one  = (cnt == {{N-1{1'b0}}, 1'b1});

always @(posedge I_SYS_CLK or negedge I_RST_N)
begin
    if (!I_RST_N)
    begin
        cnt   <= {N{1'b1}};
    end
    else
    begin
        if (!I_EN || cnt_zero || !I_GO)
            cnt   <= I_DIVIDER;
        else
            cnt <= cnt - {{N-1{1'b0}}, 1'b1};
    end
end

// clock out
always @(posedge I_SYS_CLK or negedge I_RST_N)
begin
    if (!I_RST_N || !I_EN)
        O_CLK <= I_CPOL;
    else
        if (I_GO)
            O_CLK <= (I_EN && cnt_zero && (!I_LAST_CLK || O_CLK)) ? ~O_CLK : O_CLK;
        else
            O_CLK <= I_CPOL;
end

// pos neg signals
always @(posedge I_SYS_CLK or negedge I_RST_N)
begin
    if (!I_RST_N || !I_EN)
    begin
        O_POS_EGDE <= 1'b0;
        O_NEG_EGDE <= 1'b0;
    end
    else
    begin
        O_POS_EGDE <= (I_EN && !O_CLK && cnt_one) || (!(|I_DIVIDER) && O_CLK) || (!(|I_DIVIDER) && I_GO && !I_EN);
        O_NEG_EGDE <= (I_EN && O_CLK && cnt_one) || (!(|I_DIVIDER) && !O_CLK && I_EN);
    end
end

endmodule

