`include "timescale.v"

module spi_tb;
    localparam N = 8;
    localparam CHAR_NBITS = 16;
    reg sysclk;            // system clock input
    reg rst_n;             // module reset
    reg enable;            // module enable
    reg go;                // start transmit
    reg CPOL;              // clock polarity
    reg CPHA;              // clock phase
    reg last_clk;          // last clock 
    reg [N-1:0] divider_i; // divider;
    wire clk_out;          // clock output
    wire pos_edge;         // positive edge flag
    wire neg_edge;         // negtive edge flag
    reg [4:0] bit_cnt;
    wire [1:0] spi_mode;

assign spi_mode = {CPHA, CPOL};

always @(negedge neg_edge or negedge rst_n)
begin
    if (!rst_n || !enable)
        ;
    else 
    begin
        case (spi_mode)
            2'b00:
            begin
                if (last_clk & go) 
                begin
                    go <= 0;
                    last_clk <= 0;
                end
            end
            2'b01:
            begin
                bit_cnt <= bit_cnt - 5'h1;
                if (bit_cnt == 5'h0) 
                begin
                    last_clk <= 1;
                    bit_cnt <= (CHAR_NBITS - 1);
                end
            end
            2'b10:
            begin
                if (last_clk & go) 
                begin
                    go <= 0;
                    last_clk <= 0;
                end
            end
            2'b11:
            begin
                bit_cnt <= bit_cnt - 5'h1;
                if (bit_cnt == 5'h0) 
                begin
                    last_clk <= 1;
                    bit_cnt <= (CHAR_NBITS - 1);
                end
            end
        endcase
    end
end

always @(negedge pos_edge or negedge rst_n)
begin
    if (!rst_n || !enable)
        bit_cnt <= (CHAR_NBITS - 1);
    else 
    begin
        case (spi_mode)
            2'b00:
            begin
                bit_cnt <= bit_cnt - 5'h1;
                if (bit_cnt == 5'h0) 
                begin
                    last_clk <= 1;
                    bit_cnt <= (CHAR_NBITS - 1);
                end
            end
            2'b01:
            begin
                if (last_clk & go) 
                begin
                    go <= 0;
                    last_clk <= 0;
                end
            end
            2'b10:
            begin
                bit_cnt <= bit_cnt - 5'h1;
                if (bit_cnt == 5'h0) 
                begin
                    last_clk <= 1;
                    bit_cnt <= (CHAR_NBITS - 1);
                end
            end
            2'b11:
            begin
                if (last_clk & go) 
                begin
                    go <= 0;
                    last_clk <= 0;
                end
            end
        endcase
    end
end

initial
begin            
    $dumpfile("wave.vcd");        //生成的vcd文件名称
    $dumpvars(0, spi_tb);    //tb模块名称
end

spi_clk_gen # (.N(8)) clk_gen (
    .sysclk(sysclk),       // system clock input
    .rst_n(rst_n),         // module reset
    .enable(enable),       // module enable
    .go(go),               // start transmit
    .CPOL(CPOL),           // clock polarity
    .last_clk(last_clk),   // last clock 
    .divider_i(divider_i), // divider;
    .clk_out(clk_out),     // clock output
    .pos_edge(pos_edge),   // positive edge flag
    .neg_edge(neg_edge)    // negtive edge flag
);

// 100 MHz axi clock input
always @(sysclk)
    #5 sysclk <= !sysclk;

initial
begin            
    bit_cnt    <= 5'h7;
    sysclk     <= 0;      // system clock input
    rst_n      <= 0;      // module reset
    enable     <= 0;      // module enable
    go         <= 0;      // start transmit
    CPOL       <= 0;      // clock polarity
    CPHA       <= 0;      // clock phase
    last_clk   <= 0;      // last clock 
    divider_i  <= 0;      // divider;
    #100
    rst_n    <= 1;        // module reset
    #10
    divider_i  <= 8'h04;  // divider; sys clk % 10 prescaler
    #30
    enable       <= 1;    // module enable
    #30
    go       <= 1;        // start transmit
    #(1000 * CHAR_NBITS / 8)
    go       <= 1;        // start transmit
    #(1000 * CHAR_NBITS / 8)
    // #50
    enable       <= 0;   // module enable

    #1000
    $stop;
end

endmodule

