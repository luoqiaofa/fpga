`timescale 1ns / 1ps
/*
 * this spi module will compatible to Fresscale powerpc ESPI
 * ESPI normal operation, exclude RapidS
 * ESPI_SPMODE
 * ESPI_SPIE
 * ESPI_SPIM
 * ESPI_SPCOM
 * ESPI_SPITF
 * ESPI_SPIRF
 * ESPI_SPMODE0
 * ESPI_SPMODE1
 * ESPI_SPMODE2
 * ESPI_SPMODE3
 */
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
    parameter N = 8,
    parameter N_CS = 4
)
   (
    input                   I_CLK,
    input                   I_RST_N,
    input                   I_MISO,
    output                  O_MOSI,
    output                  O_SCK,
    output     [N_CS -1 :0] O_CS,
    input      [N - 1:0]    I_TX_DATA,
    output reg [N - 1:0]    O_RX_DATA,
    input      [N - 1:0]    I_SPI_MODE,
    input      [N - 1:0]    I_SPI_SCK_DIV,
    output reg [N - 1:0]    O_SPI_STATUS
);
// I_SPI_MODE
localparam BITNO_EN          = 0;
localparam BITNO_CS_LO       = 1;
localparam BITNO_CS_HI       = 2;
localparam BITNO_TRANS_START = 3;

// O_SPI_STATUS
localparam CHAR_TRANS_DONE   = 0;

localparam CS_HI       = N_CS - 1;

//value of the ceiling of the log base 2.
function integer clogb2 (input integer x);
    integer i;
    begin
        clogb2 = 1;
        for (i = 0; 2**i < x; i = i + 1)
        begin
            clogb2 = i + 1;
        end
    end
endfunction

localparam N_BITS_CNT = clogb2(N);
localparam N_CS_CNT   = clogb2(N_CS);
// localparam N_BITS_CNT = 3;
// localparam N_CS_CNT   = 2;

reg r_sck;
reg [N - 1:0] sck_hlf_cnt;
reg [N - 1:0] r_hlf_div;
reg [N - 1:0] r_miso_fifo;
// reg [N - 1:0] r_status;
reg [N_BITS_CNT - 1 : 0] r_bit_cnt;
reg r_en;
reg r_mosi;
reg r_miso;
reg [N_CS - 1:0] r_cs;

assign O_MOSI = r_mosi;
assign O_SCK = r_sck;
assign O_CS[N_CS - 1:0] = r_cs[N_CS - 1:0];
// assign O_SPI_STATUS = r_status;


always @(posedge I_SPI_MODE[BITNO_TRANS_START])
begin
    if (I_SPI_MODE[BITNO_TRANS_START])
        O_SPI_STATUS[CHAR_TRANS_DONE] <= 1'b0;
end

always @(negedge r_en or negedge r_sck)
begin
    if (!r_en) begin
        sck_hlf_cnt <= {N{1'b0}};
        r_bit_cnt <= N - 1;
        r_mosi <= I_TX_DATA[N - 1];
    end
    else
    begin 
        r_bit_cnt <= r_bit_cnt - 1;
        case (r_bit_cnt)
            0: 
            begin 
            O_SPI_STATUS[CHAR_TRANS_DONE] <= 1'b1;
            O_RX_DATA <= r_miso_fifo;
            end
            default : O_SPI_STATUS[CHAR_TRANS_DONE] <= 1'b0;

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
        O_RX_DATA <= {N{1'b1}};
        O_SPI_STATUS <= {N{1'b0}};
        r_miso_fifo <= {N{1'b1}};
        r_miso <= I_MISO;
        r_mosi <= I_TX_DATA[N - 1];
        r_en <= 0;
        r_sck <= 0;
        r_cs <= {N_CS{1'b1}};
        sck_hlf_cnt <= {N{1'b0}};
        r_hlf_div <= {N{1'b0}};
        r_bit_cnt <= N - 1;
        r_mosi <= I_TX_DATA[N - 1];
    end
    else
    begin
        r_hlf_div  <= (I_SPI_SCK_DIV >> 1);
        r_en <= I_SPI_MODE[BITNO_EN];

        if (sck_hlf_cnt == (r_hlf_div - 1)) begin
            sck_hlf_cnt <= {N{1'b0}};
            if (!O_SPI_STATUS[CHAR_TRANS_DONE]) 
                if (I_SPI_MODE[BITNO_EN])
                    r_sck <= ~r_sck;
                else
                    r_sck <= 1;
        end
        else begin
            sck_hlf_cnt <= sck_hlf_cnt + 1;
        end

        r_mosi <= I_TX_DATA[r_bit_cnt];
        r_miso <= I_MISO;
        
        if (I_SPI_MODE[BITNO_EN])
            case (I_SPI_MODE[BITNO_CS_HI:BITNO_CS_LO])
                2'h0 : r_cs[N_CS - 1:0] <= {{N_CS - 1{1'b1}}, 1'b0};
                2'h1 : r_cs[N_CS - 1:0] <= {{N_CS - 2{1'b1}}, 1'b0, {1{1'b1}}};
                2'h2 : r_cs[N_CS - 1:0] <= {{N_CS - 3{1'b1}}, 1'b0, {2{1'b1}}};
                2'h3 : r_cs[N_CS - 1:0] <= {{N_CS - 4{1'b1}}, 1'b0, {3{1'b1}}};
            endcase
        else
            r_cs[N_CS - 1:0] <= {N_CS{1'b1}};
    end
end
endmodule

