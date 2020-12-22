module spi_trx_one_char
#(parameter integer CHAR_NBITS = 16)
(
    input  wire        S_SYSCLK,  // platform clock
    input  wire        S_RESETN,  // reset
    input  wire        S_ENABLE,  // enable
    input  wire        S_CPOL,    // clock polary
    input  wire        S_CPHA,    // clock phase, the first edge or second
    input  wire        S_TX_ONLY, // transmit only
    input  wire        S_LOOP,    // internal loopback mode
    input  wire        S_REV,     // msb first or lsb first
    input  wire [3:0]  S_CHAR_LEN,// characters in bits length
    input  wire [7:0]  S_NDIVIDER,// clock divider
    output wire        S_SPI_SCK,
    input  wire        S_SPI_MISO,
    output wire        S_SPI_MOSI,
    input  wire        S_CHAR_GO,
    output wire        S_CHAR_DONE,
    input  wire [CHAR_NBITS-1:0] S_WCHAR,   // output character
    output wire [CHAR_NBITS-1:0] S_RCHAR    // input character
);
`include "reg-bit-def.v"

reg go;        // start transmit
reg done;
reg last_clk;  // last clock 
reg dout;
reg [CHAR_NBITS - 1: 0] data_in;
reg [4:0] bit_cnt;
reg [4:0] shift_cnt;
reg [CHAR_NBITS:0] shift_tx;
reg [CHAR_NBITS:0] shift_rx;
wire [1:0] spi_mode;
wire pos_edge; // positive edge flag
wire neg_edge; // negtive edge flag
wire pos_edge_rx;         // positive edge flag
wire neg_edge_rx;         // positive edge flag

assign S_SPI_MOSI = dout;
assign S_RCHAR    = data_in;
assign S_CHAR_DONE = done;
assign spi_mode = {S_CPHA, S_CPOL};
assign pos_edge_rx = S_SPI_SCK;
assign neg_edge_rx = S_SPI_SCK;

spi_clk_gen # (.C_DIVIDER_WIDTH(8)) clk_gen_char (
    .sysclk(S_SYSCLK),       // system clock input
    .rst_n(S_RESETN),         // module reset
    .enable(S_ENABLE),       // module enable
    .go(go),               // start transmit
    .CPOL(S_CPOL),           // clock polarity
    .last_clk(last_clk),   // last clock 
    .divider_i(S_NDIVIDER), // divider;
    .clk_out(S_SPI_SCK),     // clock output
    .pos_edge(pos_edge),   // positive edge flag
    .neg_edge(neg_edge)    // negtive edge flag
);

always @(posedge go)
begin
    shift_tx <= {1'b0, {CHAR_NBITS{S_WCHAR}}};
end

always @(posedge S_SYSCLK or negedge S_RESETN)
begin
    if (!S_RESETN)
    begin
        go   <= 0;
        done <= 0;
        last_clk <= 0;
        dout <= 1'b0;
        data_in  <= {CHAR_NBITS{1'b1}};
        bit_cnt   <= CHAR_NBITS - 1;
        shift_cnt <= CHAR_NBITS - 1;
        shift_rx <= {1'b1, {CHAR_NBITS{1'b1}}};
        shift_tx <= {1'b0, {CHAR_NBITS{S_WCHAR}}};
    end
    else
    begin
        done <= 0;
        data_in  <= data_in;
        if (S_ENABLE)
        begin
            // last_clk <= last_clk;
            go <= S_CHAR_GO;
            dout <= shift_tx[shift_cnt];
            shift_rx <= shift_rx;
            shift_cnt <= shift_cnt;
            if (!go)
            begin
                bit_cnt   <= {1'b0, S_CHAR_LEN};
                case (spi_mode)
                    2'b00:
                    begin
                        shift_cnt <= {1'b0, S_CHAR_LEN};
                    end
                    2'b01:
                    begin
                        shift_cnt <= {1'b0, S_CHAR_LEN};
                    end
                    2'b10:
                    begin
                        shift_cnt <= {1'b0, S_CHAR_LEN} + 1;
                    end
                    2'b11:
                    begin
                        shift_cnt <= {1'b0, S_CHAR_LEN} + 1;
                    end
                endcase // case (spi_mode)
            end // end of (0 == S_ENABLE)
        end // end of if (S_ENABLE)
    end
end

always @(negedge neg_edge)
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
                bit_cnt <= {1'b0, S_CHAR_LEN};
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
                bit_cnt <= {1'b0, S_CHAR_LEN};
            end
        end
    endcase
end

always @(negedge pos_edge)
begin
    case (spi_mode)
        2'b00:
        begin
            bit_cnt <= bit_cnt - 5'h1;
            if (bit_cnt == 5'h0) 
            begin
                last_clk <= 1;
                bit_cnt <= {1'b0, S_CHAR_LEN};
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
                bit_cnt <= {1'b0, S_CHAR_LEN};
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

always @(posedge pos_edge_rx)
begin
    if (S_ENABLE)
    begin
        case (spi_mode)
            2'b00:
            begin
                if (S_LOOP) begin
                    shift_rx[shift_cnt] <= dout;
                end
                else begin
                    shift_rx[shift_cnt] <= S_SPI_MISO;
                end
                if (0 == shift_cnt)
                begin
                    if (S_LOOP) begin
                        data_in  <= {shift_rx[CHAR_NBITS-1:1], dout};
                    end
                    else begin
                        data_in  <= {shift_rx[CHAR_NBITS-1:1], S_SPI_MISO};
                    end
                end
            end
            2'b01:
            begin
                shift_cnt <= shift_cnt - 1;
                if (0 == shift_cnt)
                begin
                    done <= 1;
                    shift_cnt <= {1'b0, S_CHAR_LEN};
                end
            end
            2'b10:
            begin
                shift_cnt <= shift_cnt - 1;
                if (0 == shift_cnt)
                begin
                    shift_cnt <= {1'b0, S_CHAR_LEN} + 1;
                end
            end
            2'b11:
            begin
                if (S_LOOP) begin
                    shift_rx[shift_cnt] <= dout;
                end
                else begin
                    shift_rx[shift_cnt] <= S_SPI_MISO;
                end
                if (0 == shift_cnt)
                begin
                    done <= 1;
                    if (S_LOOP) begin
                    data_in  <= {shift_rx[CHAR_NBITS-1:1], dout};
                    end
                    else begin
                        data_in  <= {shift_rx[CHAR_NBITS-1:1], S_SPI_MISO};
                    end
                end
            end
        endcase
    end
end

always @(negedge neg_edge_rx)
begin
    if (S_ENABLE)
    begin
        case (spi_mode)
            2'b00:
            begin
                shift_cnt <= shift_cnt - 1;
                if (0 == shift_cnt)
                begin
                    done <= 1;
                    shift_cnt <= {1'b0, S_CHAR_LEN};
                end
            end
            2'b01:
            begin
                if (S_LOOP) begin
                    shift_rx[shift_cnt] <= dout;
                end
                else begin
                    shift_rx[shift_cnt] <= S_SPI_MISO;
                end
                if (0 == shift_cnt)
                begin
                    if (S_LOOP) begin
                        data_in  <= {shift_rx[CHAR_NBITS-1:1], dout};
                    end
                    else begin
                        data_in  <= {shift_rx[CHAR_NBITS-1:1], S_SPI_MISO};
                    end
                end
            end
            2'b10:
            begin
                if (S_LOOP) begin
                    shift_rx[shift_cnt] <= dout;
                end
                else begin
                    shift_rx[shift_cnt] <= S_SPI_MISO;
                end
                if (0 == shift_cnt)
                begin
                    done <= 1;
                    if (S_LOOP) begin
                        data_in  <= {shift_rx[CHAR_NBITS-1:1], dout};
                    end
                    else begin
                        data_in  <= {shift_rx[CHAR_NBITS-1:1], S_SPI_MISO};
                    end
                end
            end
            2'b11:
            begin
                shift_cnt <= shift_cnt - 1;
                if (0 == shift_cnt)
                begin
                    shift_cnt <= {1'b0, S_CHAR_LEN} + 1;
                end
                if (S_LOOP) begin
                    shift_rx[shift_cnt] <= dout;
                end
                else begin
                    shift_rx[shift_cnt] <= S_SPI_MISO;
                end
            end
        endcase
    end
end

endmodule

