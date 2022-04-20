module spi_slave_trx_char
#(parameter integer CHAR_NBITS = 32)
(
    input  wire        S_SYSCLK,  // platform clock
    input  wire        S_RESETN,  // reset
    input  wire        S_ENABLE,  // enable
    input  wire        S_CPOL,    // clock polary
    input  wire        S_CPHA,    // clock phase, the first edge or second
    input  wire        S_LOOP,    // internal loopback mode
    input  wire        S_REV,     // msb first or lsb first
    input  wire [3:0]  S_CHAR_LEN,// characters in bits length
    output wire        S_CHAR_DONE,
    input  wire [CHAR_NBITS-1:0] S_WCHAR,   // output character, output to SPI_MISO
    output wire [CHAR_NBITS-1:0] S_RCHAR,   // output character, read from SPI_MOSI
    input  wire        S_SPI_SEL,  // chip select, low active
    input  wire        S_SPI_SCK,
    output wire        S_SPI_MISO,
    input  wire        S_SPI_MOSI
);
`include "reg-bit-def.v"

reg done;
reg dout;
wire slave_active;
reg [CHAR_NBITS - 1: 0] data_in;
wire [5:0] bits_per_char;
wire [5:0] bits_per_char_dec;
reg  [5:0] bit_cnt;
wire [5:0] cnt_max;
reg [CHAR_NBITS : 0] shift_tx;
reg [CHAR_NBITS : 0] shift_rx;
wire [1:0] spi_mode;
wire pos_edge; // positive edge flag
wire neg_edge; // negtive edge flag

assign pos_edge    = S_SPI_SCK;
assign neg_edge    = S_SPI_SCK;
assign S_RCHAR     = data_in;
assign S_CHAR_DONE = done;
assign spi_mode = {S_CPOL, S_CPHA};
assign bits_per_char     = (0 == S_CHAR_LEN) ? 32 : S_CHAR_LEN + 1;
assign bits_per_char_dec = (0 == S_CHAR_LEN) ? 31 : S_CHAR_LEN;
assign cnt_max           = S_CPHA ? bits_per_char : bits_per_char_dec;
assign S_SPI_MISO        = dout;
assign slave_active = (S_ENABLE && !S_SPI_SEL);

always @(posedge S_SYSCLK or negedge S_RESETN)
begin
    if (!S_RESETN)
    begin
        dout     <= 1;
        done     <= 0;
        data_in  <= {CHAR_NBITS{1'b1}};
        bit_cnt  <= 0;
        shift_rx <= {1'b1, {CHAR_NBITS{1'b1}}};
        shift_tx <= {1'b1, {CHAR_NBITS{1'b1}}};
    end
    else begin
        done <= 0;
        if (S_REV) begin
            shift_tx <= {1'b1, S_WCHAR};
        end
        else begin
            shift_tx <= (S_CPHA ? {S_WCHAR , 1'b1} : {1'b1, S_WCHAR});
        end
        if (slave_active) begin
            dout <= shift_tx[bit_cnt];
            data_in  <= data_in;
            // bit_cnt <= bit_cnt;
            shift_rx <= shift_rx;
        end
        else begin
            bit_cnt <= (S_REV ? cnt_max : 0);
            dout <= 1'b1;
            shift_rx <= {1'b1, {CHAR_NBITS{1'b1}}};
        end
    end
end

always @(posedge pos_edge)
begin
    if (slave_active) begin
        case (spi_mode)
            2'h0 : begin // CI=0 CP=0
                shift_rx[bit_cnt] <= S_SPI_MOSI;
            end
            2'h1: begin // CI=0 CP=1
                bit_cnt <= (S_REV ? bit_cnt - 1 : bit_cnt + 1);
            end
            2'h2: begin // CI=1 CP=0
                bit_cnt <= (S_REV ? bit_cnt - 6'h1 : bit_cnt + 6'h1);
                if (S_REV) begin
                    if (0 == bit_cnt) begin
                        done <= 1;
                        bit_cnt <= cnt_max;
                        data_in <= shift_rx;
                    end
                end
                else begin
                    if (cnt_max == bit_cnt) begin
                        done <= 1;
                        bit_cnt <= 0;
                        data_in <= shift_rx;
                    end
                end
            end
            2'h3: begin // CI=1 CP=1
                shift_rx[bit_cnt] <= S_SPI_MOSI;
                if (S_REV) begin
                    if (0 == bit_cnt) begin
                        done <= 1;
                        bit_cnt <= cnt_max;
                        data_in <= {shift_rx[32:1], S_SPI_MOSI};
                    end
                end
                else begin
                    if (cnt_max == bit_cnt) begin
                        done <= 1;
                        bit_cnt <= 0;
                        case (bits_per_char)
                            8 : data_in <= {S_SPI_MOSI, shift_rx[7:1]};
                            16: data_in <= {S_SPI_MOSI, shift_rx[15:1]};
                            32: data_in <= {S_SPI_MOSI, shift_rx[31:1]};
                        endcase
                    end
                end
            end
        endcase
    end
end

always @(negedge neg_edge)
begin
    if (slave_active) begin
        case (spi_mode)
            2'h0: begin // CI=0 CP=0
                bit_cnt <= (S_REV ? bit_cnt - 1 : bit_cnt + 1);
                if (S_REV) begin
                    if (0 == bit_cnt) begin
                        done <= 1;
                        bit_cnt <= cnt_max;
                        data_in <= shift_rx;
                    end
                end
                else begin
                    if (cnt_max == bit_cnt) begin
                        done <= 1;
                        bit_cnt <= 0;
                        data_in <= shift_rx;
                    end
                end
            end
            2'h1: begin // CI=0 CP=1
                shift_rx[bit_cnt] <= S_SPI_MOSI;
                if (S_REV) begin
                    if (0 == bit_cnt) begin
                        done <= 1;
                        bit_cnt <= cnt_max;
                        data_in <= {shift_rx[32:1], S_SPI_MOSI};
                    end
                end
                else begin
                    if (cnt_max == bit_cnt) begin
                        done <= 1;
                        bit_cnt <= 0;
                        case (bits_per_char)
                            8 : data_in <= {S_SPI_MOSI, shift_rx[7:1]};
                            16: data_in <= {S_SPI_MOSI, shift_rx[15:1]};
                            32: data_in <= {S_SPI_MOSI, shift_rx[31:1]};
                        endcase

                    end
                end
            end
            2'h2: begin // CI=1 CP=0
                shift_rx[bit_cnt] <= S_SPI_MOSI;
            end
            2'h3: begin // CI=1 CP=1
                bit_cnt <= (S_REV ? bit_cnt - 1 : bit_cnt + 1);
            end
        endcase
    end
end

always @(posedge S_REV)
begin
    if (slave_active) begin
        if (S_REV) begin
            bit_cnt  <= (S_CPHA ? bits_per_char : bits_per_char_dec);
        end
        else begin
            bit_cnt  <= 0;
        end
    end
end

always @(negedge S_REV)
begin
    if (slave_active) begin
        if (S_REV) begin
            bit_cnt  <= (S_CPHA ? bits_per_char : bits_per_char_dec);
        end
        else begin
            bit_cnt  <= 0;
        end
    end
end

endmodule

