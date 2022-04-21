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
    input  [C_DIVIDER_WIDTH-1:0] divider_i, // divider;
    output reg clk_out,     // clock output
    output reg pos_edge,    // positive edge flag
    output reg neg_edge     // negtive edge flag
);

wire cnt_zero;
wire cnt_one;
reg [C_DIVIDER_WIDTH-1:0] cnt;
reg  in_process;
wire is_active;
assign is_active = in_process;

assign cnt_zero = (cnt == {C_DIVIDER_WIDTH{1'b0}});
assign cnt_one  = (cnt == {{C_DIVIDER_WIDTH-1{1'b0}}, 1'b1});

always @(posedge go or negedge rst_n)
begin
    if (enable) begin
        in_process <= 1;
        cnt <= divider_i;
    end
end

always @(posedge sysclk or negedge rst_n)
begin
    if (!rst_n) begin
        in_process <= 0;
        cnt   <= {C_DIVIDER_WIDTH{1'b1}};
    end
    else begin
        if (!enable || cnt_zero || !is_active) begin
            cnt   <= divider_i;
        end
        else begin
            cnt <= cnt - {{C_DIVIDER_WIDTH-1{1'b0}}, 1'b1};
        end
    end
end

always @(negedge last_clk or negedge rst_n)
begin
    clk_out <= CPOL;
end

always @(posedge last_clk)
begin
    in_process <= 0;
end

// clock out
always @(posedge sysclk or negedge rst_n)
begin
    if (!rst_n) begin
        clk_out <= 0;
    end
    else begin
        if (!enable) begin
            clk_out <= CPOL;
        end
        else begin
            if (go) begin
                clk_out <= (enable && cnt_zero && (!last_clk || clk_out)) ? ~clk_out : clk_out;
            end
            else begin
                clk_out <= CPOL;
            end
        end
    end
end

// pos neg signals
always @(posedge sysclk or negedge rst_n)
begin
    if (!rst_n || !enable || !go) begin
        pos_edge <= 1'b0;
        neg_edge <= 1'b0;
    end
    else begin
        pos_edge <= (enable && !clk_out && cnt_one) || (!(|divider_i) && clk_out) || (!(|divider_i) && is_active && !enable);
        neg_edge <= (enable && clk_out && cnt_one) || (!(|divider_i) && !clk_out && enable);
    end
end

endmodule

