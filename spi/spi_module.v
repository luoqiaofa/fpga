`timescale 1ns/1ps
/*
 * ***************************************************************************
 * I_SPI_MODE
 * 31   RST
 * 30:8 reserved
 * 7
 * 6
 * 5
 * 4
 * 3 tx_start one risine puls to triger start
 * 2 : 1  chip seledt 0 1 2 3 for 4 cs
 * 0  EN
 * ***************************************************************************
 */

module spi_module #
( 
    parameter N = 7,
    parameter N_CS = 3
)
   (
    input                I_CLK,
    input                I_RST_N,
    input                I_MISO,
    output               O_MOSI,
    output               O_SCK,
    output     [N_CS:0]  O_CS,
    input      [N:0]     I_TX_DATA,
    output reg [N:0]     O_RX_DATA,
    input      [N:0]     I_SPI_MODE,
    input      [N:0]     I_SPI_SCK_DIV,
    output               O_SPI_TX_DONE
);

reg r_sck;
reg [N:0] sck_hlf_cnt;
reg [N:0] r_hlf_div;
reg [N:0] r_miso_rxdata;
reg [N:0] r_miso_fifo;
reg [2:0] r_bit_cnt;
reg r_en;
reg r_mosi;
reg r_miso;
reg r_tx_done;
reg [N_CS:0] r_cs;

assign O_MOSI = r_mosi;
assign O_SCK = r_sck;
assign O_SPI_TX_DONE = r_tx_done;
assign O_CS[3:0] = r_cs[3:0];


always @(posedge I_SPI_MODE[3])
begin
    if (I_SPI_MODE[3])
        r_tx_done <= 0;
end

always @(negedge r_en or negedge r_sck)
begin
    if (!r_en) begin
        sck_hlf_cnt <= 0;
        r_bit_cnt <= N;
        r_mosi <= I_TX_DATA[N];
    end
    else
    begin 
        r_bit_cnt <= r_bit_cnt - 1;
        case (r_bit_cnt)
            0: 
            begin 
            r_tx_done <= 1;
            O_RX_DATA <= r_miso_fifo;
            end
            default : r_tx_done <= 0;
        endcase
        r_miso_fifo[r_bit_cnt] <= r_miso;
    end
end

always @(negedge r_en or posedge r_sck)
begin
    if (!r_en) begin
        r_miso_fifo[r_bit_cnt] <= 1'b1;
    end
    else
        r_miso_fifo[r_bit_cnt] <= r_miso;
end

always @(posedge I_CLK or negedge I_RST_N)
begin
    if (!I_RST_N) begin
        O_RX_DATA <= 8'hff;
        r_miso_rxdata <= 8'haa;
        r_miso_fifo <= 8'hff;
        r_miso <= I_MISO;
        r_en <= 0;
        r_sck <= 0;
        r_cs <= 4'hf;
        sck_hlf_cnt <= 0;
        r_hlf_div <= 0;
        r_bit_cnt <= N;
        r_mosi <= I_TX_DATA[N];
        r_tx_done <= 0;
    end
    else
    begin
        r_hlf_div  <= (I_SPI_SCK_DIV >> 1);
        r_en <= I_SPI_MODE[0];

        if (sck_hlf_cnt == (r_hlf_div - 1)) begin
            sck_hlf_cnt <= 0;
            if (!r_tx_done) 
                if (I_SPI_MODE[0])
                    r_sck <= ~r_sck;
                else
                    r_sck <= 1;
        end
        else begin
            sck_hlf_cnt <= sck_hlf_cnt + 1;
        end

        r_mosi <= I_TX_DATA[r_bit_cnt];
        r_miso <= I_MISO;
        
        if (I_SPI_MODE[0])
            case (I_SPI_MODE[2:1])
                2'h0 : r_cs[3:0] <= 4'he;
                2'h1 : r_cs[3:0] <= 4'hd;
                2'h2 : r_cs[3:0] <= 4'hb;
                2'h3 : r_cs[3:0] <= 4'h7;
            endcase
        else
            r_cs[3:0] <= 4'hf;
    end
end
endmodule

