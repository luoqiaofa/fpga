module spi_slave_trx_char
#(parameter integer CHAR_NBITS = 32)
(
    input  wire        S_SYSCLK,  // platform clock
    input  wire        S_RESETN,  // reset
    input  wire        S_ENABLE,  // enable
    input  wire        S_CPOL,    // clock polary
    input  wire        S_CPHA,    // clock phase, the first edge or second
    input  wire        S_CSPOL,   // cs polary
    input  wire        S_REV,     // msb first or lsb first
    input  wire [3:0]  S_CHAR_LEN,// characters in bits length
    output wire        S_CHAR_DONE,
    input  wire [31:0] S_WCHAR,   // output character, output to SPI_MISO
    output wire [31:0] S_RCHAR,   // output character, read from SPI_MOSI
    input  wire        S_SPI_CS,  // chip select, low active
    input  wire        S_SPI_SCK,
    output wire        S_SPI_MISO,
    input  wire        S_SPI_MOSI
);
`include "reg-bit-def.v"
localparam MAX_BITNO_OF_CHAR = 4'hf;

reg done;
wire slave_active;
reg [31: 0] data_in;
reg [3:0] bit_cnt;
reg [1:0] char_idx;
reg [NBITS_CHAR_LEN_MAX-1 : 0] shift_tx;
reg [NBITS_CHAR_LEN_MAX-1 : 0] shift_rx;
wire [1:0] spi_mode;
wire pos_edge; // positive edge flag
wire neg_edge; // negtive edge flag

assign pos_edge    = S_SPI_SCK;
assign neg_edge    = S_SPI_SCK;
assign S_RCHAR     = data_in;
assign S_CHAR_DONE = slave_active ? done : 1'bz;
assign spi_mode = {S_CPOL, S_CPHA};
assign S_SPI_MISO   = slave_active ? shift_tx[bit_cnt] : 1'bz;
assign slave_active = S_CSPOL ? (S_ENABLE && ~S_SPI_CS) : (S_ENABLE && S_SPI_CS);

always @(posedge S_SYSCLK or negedge S_RESETN)
begin
    if (!S_RESETN)
    begin
        done     <= 0;
        char_idx <= 0;
        data_in  <= {CHAR_NBITS{1'b1}};
        bit_cnt  <= 0;
        shift_rx <= {CHAR_NBITS{1'b1}};
        shift_tx <= {CHAR_NBITS{1'b1}};
    end
    else begin
        done <= 0;
        if (S_CHAR_LEN > 7) begin
        case (char_idx)
            0 : shift_tx <= S_WCHAR[15:0];
            1 : shift_tx <= S_WCHAR[31:16];
        endcase
        end
        else begin
            case (char_idx)
                0 :shift_tx[7:0] <= S_WCHAR[7:0];
                1 :shift_tx[7:0] <= S_WCHAR[15:8];
                2 :shift_tx[7:0] <= S_WCHAR[23:16];
                3 :shift_tx[7:0] <= S_WCHAR[31:24];
            endcase
        end
        if (slave_active) begin
            data_in  <= data_in;
            shift_rx <= shift_rx;
        end
        else begin
            shift_rx <= {1'b1, {CHAR_NBITS{1'b1}}};
            if (S_REV) begin
                bit_cnt  <= (S_CPHA ? S_CHAR_LEN + 1 : S_CHAR_LEN);
            end
            else begin
                bit_cnt  <= (S_CPHA ? MAX_BITNO_OF_CHAR : 0);
            end
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
                bit_cnt <= (S_REV ? bit_cnt - 1 : bit_cnt + 1);
                if (S_REV) begin
                    if (0 == bit_cnt) begin
                        done <= 1;
                    end
                end
                else begin
                    if (S_CHAR_LEN == bit_cnt) begin
                        done <= 1;
                    end
                end
            end
            2'h3: begin // CI=1 CP=1
                shift_rx[bit_cnt] <= S_SPI_MOSI;
                if (S_REV) begin
                    if (0 == bit_cnt) begin
                        done <= 1;
                    end
                end
                else begin
                    if (S_CHAR_LEN == bit_cnt) begin
                        done <= 1;
                    end
                end
            end
        endcase
    end
end

always @(posedge done)
begin
    if (S_CHAR_LEN > 7) begin
        case (char_idx[0])
            0 : data_in[15:0]  <= shift_rx;
            1 : data_in[31:16] <= shift_rx;
        endcase
    end
    else begin
        case (char_idx[0])
            0 : data_in[7:0]   <= shift_rx;
            1 : data_in[15:8]  <= shift_rx;
            2 : data_in[23:16] <= shift_rx;
            3 : data_in[31:24] <= shift_rx;
        endcase
    end
end

always @(negedge done)
begin
    if (slave_active) begin
        if (S_REV) begin
            bit_cnt  <= (S_CPHA ? S_CHAR_LEN + 1 : S_CHAR_LEN);
        end
        else begin
            bit_cnt  <= (S_CPHA ? MAX_BITNO_OF_CHAR : 0);
        end
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
                    end
                end
                else begin
                    if (S_CHAR_LEN == bit_cnt) begin
                        done <= 1;
                    end
                end
            end
            2'h1: begin // CI=0 CP=1
                shift_rx[bit_cnt] <= S_SPI_MOSI;
                if (S_REV) begin
                    if (0 == bit_cnt) begin
                        done <= 1;
                    end
                end
                else begin
                    if (S_CHAR_LEN == bit_cnt) begin
                        done <= 1;
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

always @(posedge done)
begin
    char_idx <= char_idx + 1;
    if (S_CHAR_LEN > 7) begin
        if (1 == char_idx) begin
            char_idx <= 0;
        end
    end
end

endmodule

