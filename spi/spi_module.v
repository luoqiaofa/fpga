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
    parameter N = 8,
    parameter N_CS = 4
)
   (
    input                I_CLK,
    input                I_RST_N,
    input                I_MISO,
    output               O_MOSI,
    output               O_SCK,
    output     [N_CS -1 :0]  O_CS,
    input      [N - 1:0]     I_TX_DATA,
    output reg [N - 1:0]     O_RX_DATA,
    input      [N - 1:0]     I_SPI_MODE,
    input      [N - 1:0]     I_SPI_SCK_DIV,
    output               O_SPI_TX_DONE
);

localparam BITNO_EN          = 0;
localparam BITNO_CS_LO       = 1;
localparam BITNO_CS_HI       = 2;
localparam BITNO_TRANS_START = 3;

localparam CS_HI       = N_CS - 1;

//value of the ceiling of the log base 2.
function integer clogb2 (input integer bit_depth);
    begin
        for(clogb2=0; bit_depth > 0; clogb2=clogb2+1)
            bit_depth = bit_depth>>1;
    end
endfunction

// localparam N_BITS_CNT = clogb2(N);
// localparam N_CS_CNT   = clogb2(N_CS);
localparam N_BITS_CNT = 3;
localparam N_CS_CNT   = 2;

reg r_sck;
reg [N - 1:0] sck_hlf_cnt;
reg [N - 1:0] r_hlf_div;
reg [N - 1:0] r_miso_fifo;
reg [N_BITS_CNT - 1 : 0] r_bit_cnt;
reg r_en;
reg r_mosi;
reg r_miso;
reg r_tx_done;
reg [N_CS - 1:0] r_cs;

assign O_MOSI = r_mosi;
assign O_SCK = r_sck;
assign O_SPI_TX_DONE = r_tx_done;
assign O_CS[N_CS - 1:0] = r_cs[N_CS - 1:0];


always @(posedge I_SPI_MODE[BITNO_TRANS_START])
begin
    if (I_SPI_MODE[BITNO_TRANS_START])
        r_tx_done <= 0;
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
        r_tx_done <= 0;
    end
    else
    begin
        r_hlf_div  <= (I_SPI_SCK_DIV >> 1);
        r_en <= I_SPI_MODE[BITNO_EN];

        if (sck_hlf_cnt == (r_hlf_div - 1)) begin
            sck_hlf_cnt <= {N{1'b0}};
            if (!r_tx_done) 
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

