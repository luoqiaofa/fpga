module spi_master_trx_char
#(parameter integer CHAR_NBITS = 32)
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
    input  wire [9:0]  S_NDIVIDER,// clock divider
    input  wire        S_CHAR_GO,
    output wire        S_CHAR_DONE,
    input  wire [CHAR_NBITS-1:0] S_WCHAR,   // output character
    output wire [CHAR_NBITS-1:0] S_RCHAR,   // input character
    output wire        S_SPI_SCK,
    input  wire        S_SPI_MISO,
    output wire        S_SPI_MOSI
);
`include "reg-bit-def.v"

reg go;        // start transmit, in transmit progress
reg done;
reg last_clk;  // last clock 
reg dout;
reg [CHAR_NBITS - 1: 0] data_in;
wire [5:0] bits_per_char;
wire [5:0] bits_per_char_dec;
reg  [5:0] bit_cnt;
reg  [5:0] cnt_min;
reg  [5:0] cnt_max;
reg [CHAR_NBITS:0] shift_tx;
reg [CHAR_NBITS:0] shift_rx;
wire [1:0] spi_mode;
wire pos_edge; // positive edge flag
wire neg_edge; // negtive edge flag

assign S_SPI_MOSI = dout;
assign S_RCHAR    = data_in;
assign S_CHAR_DONE = done;
assign spi_mode = {S_CPOL, S_CPHA};
assign bits_per_char     = (0 == S_CHAR_LEN) ? 32 : S_CHAR_LEN + 1 ;
assign bits_per_char_dec = (0 == S_CHAR_LEN) ? 31 : S_CHAR_LEN ;

spi_clk_gen # (.C_DIVIDER_WIDTH(10)) clk_gen_char (
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

always @(posedge S_CHAR_GO)
begin
    if (!go & S_RESETN & S_ENABLE) begin
        go <= 1;
        if (!S_REV) begin
            bit_cnt <= 0;
            if (S_CPHA) begin
                cnt_max <= bits_per_char;
                dout <= 1'b1;
                shift_tx <= {S_WCHAR, 1'b1};
            end
            else begin
                cnt_max <= bits_per_char_dec;
                shift_tx <= {1'b1, S_WCHAR};
                dout <= S_WCHAR[0];
            end
        end
        else begin
            if (S_CPHA) begin
                shift_tx <= {1'b1, S_WCHAR};
                bit_cnt <= bits_per_char;
                cnt_min <= 1;
                dout <= 1'b1;
            end
            else begin
                bit_cnt <= bits_per_char_dec;
                shift_tx <= {1'b1, S_WCHAR};
                cnt_min <= 0;
                dout <= S_WCHAR[bits_per_char_dec];
            end
        end
    end
end

always @(posedge S_SYSCLK or negedge S_RESETN)
begin
    if (!S_RESETN)
    begin
        go   <= 0;
        done <= 0;
        last_clk <= 0;
        dout <= 1'b1;
        data_in  <= {CHAR_NBITS{1'b1}};
        cnt_max <= CHAR_NBITS - 1;
        bit_cnt <= CHAR_NBITS - 1;
        cnt_min <= 0;
        shift_rx <= {1'b1, {CHAR_NBITS{1'b1}}};
        shift_tx <= {1'b0, S_WCHAR};
    end
    else
    begin
        done <= 0;
        last_clk <= 0;
        data_in  <= data_in;
        if (S_ENABLE & go)
        begin
            bit_cnt <= bit_cnt;
            dout <= shift_tx[bit_cnt];
            shift_rx <= shift_rx;
        end // end of if (S_ENABLE)
    end
end

always @(negedge neg_edge)
begin
    case (spi_mode)
        2'h0 : begin // CI=0 CP=0
            if (S_REV) begin
                bit_cnt <= bit_cnt - 6'h1;
                if (cnt_min == bit_cnt) begin
                    done <= 1;
                    go <= 0;
                    last_clk <= 1;
                    bit_cnt <= bits_per_char_dec;
                    data_in <= shift_rx[31:0];
                end
            end
            else begin
                bit_cnt <= bit_cnt + 6'h1;
                if (cnt_max == bit_cnt) begin
                    go <= 0;
                    done <= 1;
                    last_clk <= 1;
                    bit_cnt <= 6'd0;
                    data_in <= shift_rx[31:0];
                end
            end
        end
        2'h1: begin // CI=0 CP=1
            if (S_REV) begin
                if (0 == bit_cnt) begin
                    go <= 0;
                    done <= 1;
                    last_clk <= 1;
                    if (S_LOOP) begin
                        data_in <= {shift_rx[31:1], S_SPI_MOSI};
                    end
                    else begin
                        data_in <= {shift_rx[31:1], S_SPI_MISO};
                    end
                end
                if (S_LOOP) begin
                    shift_rx[bit_cnt] <= S_SPI_MOSI;
                end
                else begin
                    shift_rx[bit_cnt] <= S_SPI_MISO;
                end
            end
            else begin
                if (cnt_max == bit_cnt) begin
                    go <= 0;
                    done <= 1;
                    last_clk <= 1;
                    if (S_LOOP) begin
                        case (bits_per_char)
                            6'd8 : data_in[7:0] <= {S_SPI_MOSI, shift_rx[7:1]};
                            6'd16: data_in[15:0] <= {S_SPI_MOSI, shift_rx[15:1]};
                            6'd32: data_in[31:0] <= {S_SPI_MOSI, shift_rx[31:1]};
                        endcase
                    end
                    else begin
                        case (bits_per_char)
                            6'd8 : data_in[7:0] <= {S_SPI_MISO, shift_rx[7:1]};
                            6'd16: data_in[15:0] <= {S_SPI_MISO, shift_rx[15:1]};
                            6'd32: data_in[31:0] <= {S_SPI_MISO, shift_rx[31:1]};
                        endcase
                    end
                end
                if (S_LOOP) begin
                    shift_rx[bit_cnt] <= S_SPI_MOSI;
                end
                else begin
                    shift_rx[bit_cnt] <= S_SPI_MISO;
                end
            end
        end
        2'h2: begin // CI=1 CP=0
            if (S_LOOP) begin
                shift_rx[bit_cnt] <= S_SPI_MOSI;
            end
            else begin
                shift_rx[bit_cnt] <= S_SPI_MISO;
            end
        end
        2'h3: begin // CI=1 CP=1
            if (S_REV) begin
                bit_cnt <= bit_cnt - 6'h1;
                if (0 == bit_cnt) begin
                    // go <= 0;
                    last_clk <= 1;
                end
            end
            else begin
                bit_cnt <= bit_cnt + 6'h1;
                if (cnt_max == bit_cnt) begin
                    // go <= 0;
                    last_clk <= 1;
                end
            end
        end
    endcase
end

always @(negedge pos_edge)
begin
    if (S_ENABLE & go) begin
        case (spi_mode)
            2'h0: begin // CI=0 CP=0
                if (S_LOOP) begin
                    shift_rx[bit_cnt] <= S_SPI_MOSI;
                end
                else begin
                    shift_rx[bit_cnt] <= S_SPI_MISO;
                end
            end
            2'h1: begin // CI=0 CP=1
                if (S_REV) begin
                    bit_cnt <= bit_cnt - 6'h1;
                    if (0 == bit_cnt) begin
                        // go <= 0;
                        last_clk <= 1;
                        bit_cnt <= bits_per_char;
                    end
                end
                else begin
                    bit_cnt <= bit_cnt + 6'h1;
                    if (cnt_max == bit_cnt) begin
                        go <= 0;
                        done <= 1;
                        last_clk <= 1;
                        bit_cnt <= 6'd0;
                    end
                end
            end
            2'h2: begin // CI=1 CP=0
                if (S_REV) begin
                    bit_cnt <= bit_cnt - 6'h1;
                    if (0 == bit_cnt) begin
                        go <= 0;
                        done <= 1;
                        last_clk <= 1;
                        bit_cnt <= bits_per_char_dec;
                        data_in <= shift_rx[31:0];
                    end
                end
                else begin
                    bit_cnt <= bit_cnt + 6'h1;
                    if (cnt_max == bit_cnt) begin
                        go <= 0;
                        done <= 1;
                        last_clk <= 1;
                        bit_cnt <= 6'd0;
                        data_in <= shift_rx[31:0];
                    end
                end
            end
            2'h3: begin // CI=1 CP=1
                if (S_LOOP) begin
                    shift_rx[bit_cnt] <= S_SPI_MOSI;
                end
                else begin
                    shift_rx[bit_cnt] <= S_SPI_MISO;
                end
                if (S_REV) begin
                    if (0 == bit_cnt) begin
                        go <= 0;
                        done <= 1;
                        last_clk <= 1;
                        if (S_LOOP) begin
                            data_in <= {shift_rx[31:1], S_SPI_MOSI};
                        end
                        else begin
                            data_in <= {shift_rx[31:1], S_SPI_MISO};
                        end
                    end
                end
                else begin
                    if (cnt_max == bit_cnt) begin
                        go <= 0;
                        done <= 1;
                        last_clk <= 1;
                        if (S_LOOP) begin
                            case (bits_per_char)
                                6'd8 : data_in[7:0] <= {S_SPI_MOSI, shift_rx[7:1]};
                                6'd16: data_in[15:0] <= {S_SPI_MOSI, shift_rx[15:1]};
                                6'd32: data_in[31:0] <= {S_SPI_MOSI, shift_rx[31:1]};
                            endcase
                        end
                        else begin
                            case (bits_per_char)
                                6'd8 : data_in[7:0] <= {S_SPI_MISO, shift_rx[7:1]};
                                6'd16: data_in[15:0] <= {S_SPI_MISO, shift_rx[15:1]};
                                6'd32: data_in[31:0] <= {S_SPI_MISO, shift_rx[31:1]};
                            endcase
                        end
                    end
                end
            end
        endcase
    end
end

endmodule

