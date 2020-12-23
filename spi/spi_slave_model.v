`include "timescale.v"

module spi_slave_model
#(parameter integer CHAR_NBITS = 16)
(
    input  wire        S_SYSCLK,  // platform clock
    input  wire        S_RESETN,  // reset
    input  wire        S_ENABLE,  // enable
    input  wire        S_CHAR_GO,
    input  wire        S_CPOL,    // clock polary
    input  wire        S_CPHA,    // clock phase, the first edge or second
    input  wire        S_TX_ONLY, // transmit only
    input  wire        S_REV,     // msb first or lsb first
    input  wire [3:0]  S_CHAR_LEN,// characters in bits length
    input  wire        S_SPI_SCK,
    output wire        S_SPI_MISO,
    input  wire        S_SPI_MOSI,
    output wire        S_CHAR_DONE
);

reg [4:0] shift_cnt;
reg [CHAR_NBITS:0] data_miso;    // input character
reg [CHAR_NBITS:0] data_mosi;    // input character
reg [4:0] cnt_max;

reg miso;
wire sck_neg_edge;
wire [1:0] spi_mode = {S_CPHA, S_CPOL};

assign S_SPI_MISO = miso;
assign sck_neg_edge = S_SPI_SCK;

always @(posedge S_SYSCLK or negedge S_RESETN)
begin
    if (!S_RESETN) begin
        miso <= 1'b1;
        data_mosi <= 16'hffff;
        data_miso <= 16'haa50;
        shift_cnt <= CHAR_NBITS - 1;
        cnt_max <= CHAR_NBITS - 1;
    end
    else begin
        shift_cnt <= shift_cnt;
        miso <= data_miso[shift_cnt];
        data_mosi <= data_mosi;
    end
end

always @(posedge S_CHAR_GO)
begin
    data_miso <= data_miso + 1;
    if (S_REV) begin
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
        endcase
    end
    else begin
        case (spi_mode)
            2'b00:
            begin
                shift_cnt <= 0;
                cnt_max = {1'b0, S_CHAR_LEN};
            end
            2'b01:
            begin
                cnt_max = {1'b0, S_CHAR_LEN};
                shift_cnt <= 0;
                cnt_max = {1'b0, S_CHAR_LEN};
            end
            2'b10:
            begin
                cnt_max = {1'b0, S_CHAR_LEN} + 1;
                shift_cnt <= {1'b0, S_CHAR_LEN} + 1;
            end
            2'b11:
            begin
                cnt_max = {1'b0, S_CHAR_LEN} + 1;
                shift_cnt <= {1'b0, S_CHAR_LEN} + 1;
            end
        endcase
    end
end

always @(posedge S_SPI_SCK)
begin
    case (spi_mode)
        2'b00:
        begin
            data_mosi[shift_cnt] <= S_SPI_MOSI;
        end
        2'b01:
        begin
            cnt_max <= cnt_max;
            if (S_REV) begin
                shift_cnt <= shift_cnt - 1;
                if (0 == shift_cnt) begin
                    shift_cnt <= {1'b0, S_CHAR_LEN};
                end
            end
            else begin
                shift_cnt <= shift_cnt + 1;
                if (cnt_max == shift_cnt) begin
                    shift_cnt <= 0;
                end
            end
        end
        2'b10:
        begin
            if (S_REV) begin
                shift_cnt <= shift_cnt - 1;
                if (0 == shift_cnt) begin
                    shift_cnt <= {1'b0, S_CHAR_LEN} + 1;
                end
            end
            else begin
                if (cnt_max == shift_cnt) begin
                    shift_cnt <= 0;
                end
                else begin
                    shift_cnt <= shift_cnt + 1;
                end
            end
        end
        2'b11:
        begin
            data_mosi[shift_cnt] <= S_SPI_MOSI;
        end
    endcase // case (spi_mode)
end

always @(negedge sck_neg_edge)
begin
    case (spi_mode)
        2'b00:
        begin
            if (S_REV) begin
                shift_cnt <= shift_cnt - 1;
                if (0 == shift_cnt) begin
                    shift_cnt <= {1'b0, S_CHAR_LEN};
                end
            end
            else begin
                shift_cnt <= shift_cnt + 1;
                if (cnt_max == shift_cnt) begin
                    shift_cnt <= 0;
                end
            end
        end
        2'b01:
        begin
            data_mosi[shift_cnt] <= S_SPI_MOSI;
        end
        2'b10:
        begin
            data_mosi[shift_cnt] <= S_SPI_MOSI;
        end
        2'b11:
        begin
            if (S_REV) begin
                shift_cnt <= shift_cnt - 1;
                if (0 == shift_cnt) begin
                    shift_cnt <= {1'b0, S_CHAR_LEN} + 1;
                end
            end
            else begin
                if (cnt_max == shift_cnt) begin
                    shift_cnt <= 0;
                end 
                else begin
                    shift_cnt <= shift_cnt + 1;
                end
            end
        end
    endcase // case (spi_mode)
end
endmodule

