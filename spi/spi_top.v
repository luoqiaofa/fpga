`include "timescale.v"
module spi_intface # (parameter NCS = 4)
(
    input  wire S_SYSCLK,  // platform clock
    input  wire S_RESETN,  // reset
    input  wire [7:0] S_AWADDR,
    input  wire [31: 0] S_WDATA,
    input  wire [3 : 0] S_WSTRB,
    input  wire S_REG_WEN,
    input  wire [7 : 0]  S_ARADDR,
    output wire [31 : 0] S_RDATA,
    input  wire S_REG_RDEN,
    output wire S_INTERRUPT,
    output wire S_SPI_SCK,
    input  wire S_SPI_MISO,
    inout  wire S_SPI_MOSI,
    output wire [NCS-1:0] S_SPI_SEL
);
`include "reg-bit-def.v"
`include "const.v"
localparam NBITS_WORD_TXFIFO = clogb2 (NWORD_TXFIFO-1);
localparam NBITS_WORD_RXFIFO = clogb2 (NWORD_RXFIFO-1);

(* keep = "true" *) reg [31: 0] SPMODE;
(* keep = "true" *) reg [31: 0] SPIE;
(* keep = "true" *) reg [31: 0] SPIM;
(* keep = "true" *) reg [31: 0] SPCOM;
wire [31: 0] SPITF;
(* keep = "true" *) reg [31: 0] SPIRF;
(* keep = "true" *) reg [31: 0] CSXMODE[0:NCS-1];
(* keep = "true" *) reg [31: 0] SPI_TXFIFO[0:NWORD_TXFIFO-1];
(* keep = "true" *) reg [31: 0] SPI_RXFIFO[0:NWORD_RXFIFO-1];

integer idx;
reg csmodex_updated;
reg [31: 0]  csmodex;
wire [31: 0] CSMODE;
wire [NBITS_PM-1:0]         CSMODE_PM;
wire [NBITS_CHARLEN-1:0]    CSMODE_LEN;
wire [NBITS_CSBEF-1:0]      CSMODE_CSBEF;
wire [NBITS_CSAFT-1:0]      CSMODE_CSAFT;
wire [NBITS_CSCG-1:0]       CSMODE_CSCG;
wire [NBITS_CS-1: 0]        SPCOM_CS;
wire [NBITS_TRANLEN-1:0]    SPCOM_RSKIP;
wire [NBITS_TRANLEN-1:0]    TXTHR;
wire [NBITS_TRANLEN-1:0]    RXTHR;
wire [NBITS_RXCNT-1:0]      SPIE_RXCNT;
wire [NBITS_TXCNT-1:0]      SPIE_TXCNT;
wire [NBITS_TRANLEN-1:0]    SPCOM_TRANLEN;

reg [NBITS_CSBEF-1:0]       cnt_csbef;
reg [NBITS_CSAFT-1:0]       cnt_csaft;
reg [NBITS_CSCG   :0]       cnt_cscg;
// reg [NBITS_RSKIP-1:0]       cnt_rskip;
// reg [NBITS_TXTHR-1:0]       cnt_txthr;
// reg [NBITS_RXTHR-1:0]       cnt_rxthr;
// reg [NBITS_RXCNT-1:0]       cnt_rxcnt;
// reg [NBITS_TXCNT-1:0]       cnt_txcnt;
// reg [NBITS_TRANLEN-1:0]     cnt_trans;


reg [NCS-1:0] spi_sel;

reg [31:0] reg_data_out;

/* spi transactions flags or counters begin */
(* mark_debug = "true" *) reg frame_in_process;
(* mark_debug = "true" *) reg frame_next_start;
(* mark_debug = "true" *) reg frame_go;
(* mark_debug = "true" *) reg frame_done;
(* mark_debug = "true" *) reg [2:0] frame_state; // frame machine state;
reg  chr_go;
wire chr_go_wire;
reg  chr_done;
wire char_done_wire;

localparam FRAME_SM_IDLE      = 0;
localparam FRAME_SM_BEF_WAIT  = 1;
localparam FRAME_SM_DATA_WAIT = 2;
localparam FRAME_SM_IN_TRANS  = 3;
localparam FRAME_SM_AFT_WAIT  = 4;
localparam FRAME_SM_CG_WAIT   = 5;

(* mark_debug = "true" *) reg [3:0] char_bit_cnt;
localparam MAX_BITNO_OF_CHAR = 4'hf;
/* spi transactions flags or counters end */

reg [15:0] data_rx;
reg [15:0] data_tx;

reg  spi_brg_go;
wire brg_clk;
wire brg_pos_edge;
wire brg_neg_edge;
localparam NBITS_BRG_DIVIDER = NBITS_PM + 4 + 2;
wire [NBITS_BRG_DIVIDER-1:0] csmode_pm;
wire [NBITS_BRG_DIVIDER-1:0] brg_divider;

wire [NBITS_TRANLEN-1:0] nbytes_to_spitf;
(* mark_debug = "true" *) reg  [NBITS_TRANLEN-1:0] char_trx_idx;
(* mark_debug = "true" *) reg  [NBITS_TRANLEN-1:0] char_rx_idx; // count number of char from miso in master mode
// one word is 32 bit. half word is 16 bit
(* mark_debug = "true" *) reg  [NBITS_TRANLEN-1:0] num_spitf_upd;
wire [NBITS_TRANLEN-1:0] num_spitf_trx;
wire TXE; // Tx FIFO empty flag;
wire TNF; // Tx FIFO full flag;
wire TXT; // Tx FIFO has less than TXTHR bytes, that is, at most TXTHR - 1 bytes

reg [1:0] cs_idx;
(* mark_debug = "true" *) reg [NBITS_WORD_TXFIFO-1:0]  spitf_idx;
wire [NBITS_WORD_RXFIFO-1:0] spirf_wr_idx; // rx data to spirf(rx fifo)
(* mark_debug = "true" *) reg [NBITS_TRANLEN-1:0] spirf_char_idx; // char offset from miso to spirf(rx fifo)
(* mark_debug = "true" *) reg [NBITS_WORD_RXFIFO-1:0] spirf_rd_idx;
// CSMODE_LEN > 7 spitf_trx_idx = char_trx_idx >> 1
// (CSMODE_LEN <= 7) spitf_trx_idx >> 2
wire [NBITS_WORD_TXFIFO-1:0] spitf_trx_idx;
//  char offset in spitf
wire [NBITS_WORD_TXFIFO-1:0] spitf_trx_char_off;
wire [NBITS_TRANLEN-1:0] num_bytes_to_mosi;
wire [NBITS_TRANLEN-1:0] nbytes_need_tx;
wire [NBITS_TRANLEN-1:0] TXCNT;
assign SPITF = SPI_TXFIFO[spitf_trx_idx];
assign spitf_trx_idx = CSMODE_LEN > 7 ?  char_trx_idx[NBITS_WORD_TXFIFO:1] : char_trx_idx[NBITS_WORD_TXFIFO+1:2];
assign spitf_trx_char_off = CSMODE_LEN > 7 ? {{(NBITS_WORD_TXFIFO-1){1'b0}}, char_trx_idx[0]}:{{(NBITS_WORD_TXFIFO-2){1'b0}}, char_trx_idx[1:0]};
// Tx FIFO is empty or not
assign num_bytes_to_mosi = CSMODE_LEN > 7 ? {char_trx_idx[NBITS_TRANLEN-2:0], 1'b0} : char_trx_idx;

wire [NBITS_TRANLEN-1:0] nbytes_word_aligned_trx;
wire [NBITS_TRANLEN-1:0] nword_need_tx_in_fifo;
assign nbytes_word_aligned_trx = (num_bytes_to_mosi + 3) & {{(NBITS_TRANLEN-2){1'b1}}, 2'b00};
assign num_spitf_trx = CSMODE_LEN > 7 ?  {1'b0, char_trx_idx[15:1]} : {2'b00, char_trx_idx[15:2]};

// 4 bytes per word
assign nbytes_to_spitf = {num_spitf_upd[NBITS_TRANLEN-3:0], 2'b00};
assign nbytes_need_tx = nbytes_to_spitf - num_bytes_to_mosi;
assign nword_need_tx_in_fifo = {2'b00, nbytes_need_tx[NBITS_TRANLEN-2:2]};
assign TXE = (num_spitf_trx == num_spitf_upd) ? 1'b1: 1'b0;
assign TXCNT = num_spitf_upd > 0 ? NBYTES_TXFIFO - nbytes_need_tx : NBYTES_TXFIFO;
// assign TNF = TXCNT > 0 ? 1'b1: 1'b0;
assign TNF = TXCNT > (NBYTES_PER_WORD - 1) ? 1'b1 : 1'b0;
assign TXT = nbytes_need_tx < TXTHR ? 1'b1 : 1'b0;

// assign char_rx_idx = char_trx_idx < SPCOM_RSKIP ? 0 : char_trx_idx - SPCOM_RSKIP;
wire   [NBITS_TRANLEN-1:0] nbytes_rx_from_miso;
wire   [NBITS_TRANLEN-1:0] nbytes_valid_in_rxfifo;
wire   RNE;   // Not empty. Indicates that the Rx FIFO register contains a received character.
wire   RXT;   // Rx FIFO has more than RXTHR bytes, that is, at least RXTHR + 1 bytes
wire   RXF;   // Rx FIFO is full
wire   [NBITS_TRANLEN-1:0] RXCNT; // The current number of free Tx FIFO bytes
reg    [NBITS_TRANLEN-1:0] nbytes_read_from_spirf;
assign nbytes_rx_from_miso = CSMODE_LEN > 7 ? {char_rx_idx[NBITS_TRANLEN-1:1], 1'b0} : char_rx_idx;
assign nbytes_valid_in_rxfifo = nbytes_rx_from_miso - nbytes_read_from_spirf;
assign spirf_wr_idx = CSMODE_LEN > 7 ? spirf_char_idx[NBITS_WORD_TXFIFO:1] : spirf_char_idx[NBITS_WORD_TXFIFO+1:2];
assign RNE   = nbytes_valid_in_rxfifo > 0 ? 1'b1 : 1'b0;
assign RXF   = nbytes_valid_in_rxfifo < NBYTES_RXFIFO ? 1'b0 : 1'b1;
assign RXT   = nbytes_valid_in_rxfifo > RXTHR ? 1'b1 : 1'b0;
assign RXCNT = nbytes_valid_in_rxfifo < NBYTES_RXFIFO ? nbytes_valid_in_rxfifo : NBYTES_RXFIFO;
wire   [31:0] SPIRF_WR;
assign SPIRF_WR = SPI_RXFIFO[spirf_wr_idx];

(* mark_debug = "true" *) reg spcom_updated;
reg spitf_updated;
reg spirf_updated;

integer byte_index;

wire i_spi_mosi;
wire o_spi_mosi;
reg  t_spi_mosi;

wire i_spi_miso;

wire din;
reg  dout;

// pullup pullup_miso_i(i_spi_miso);
// pullup pullup_mosi_i(i_spi_mosi);

// assign o_spi_mosi = data_tx[char_bit_cnt];
assign S_SPI_SCK  = (FRAME_SM_IN_TRANS == frame_state) ? brg_clk : CSMODE[CSMODE_CI];
assign S_SPI_SEL  = spi_sel;

assign i_spi_miso = CSMODE[CSMODE_IS3WIRE] ? i_spi_mosi : S_SPI_MISO;
assign o_spi_mosi = dout;
assign din = SPMODE[SPMODE_LOOP] ? o_spi_mosi : i_spi_miso;

iobuf ioc_spi_mosi(
    .T(t_spi_mosi),
    .IO(S_SPI_MOSI),
    .I(o_spi_mosi),
    .O(i_spi_mosi)
);

assign S_INTERRUPT = | (SPIM & SPIE);

assign SPCOM_CS     = SPCOM[SPCOM_CS_HI: SPCOM_CS_LO];
assign SPCOM_RSKIP  = {{(NBITS_TRANLEN-NBITS_RSKIP){1'b0}}, SPCOM[SPCOM_RSKIP_HI:SPCOM_RSKIP_LO]};
assign SPCOM_TRANLEN= SPCOM[SPCOM_TRANLEN_HI:SPCOM_TRANLEN_LO];

assign TXTHR = {{(NBITS_TRANLEN-NBITS_TXTHR){1'b0}},SPMODE[SPMODE_TXTHR_HI:SPMODE_TXTHR_LO]};
assign RXTHR = {{(NBITS_TRANLEN-NBITS_RXTHR){1'b0}},SPMODE[SPMODE_RXTHR_HI:SPMODE_RXTHR_LO]};
assign SPIE_RXCNT   = SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO];
assign SPIE_TXCNT   = SPIE[SPIE_TXCNT_HI:SPIE_TXCNT_LO];

assign CSMODE       = CSXMODE[SPCOM_CS];
assign CSMODE_LEN   = CSMODE[CSMODE_LEN_HI  : CSMODE_LEN_LO];
assign CSMODE_PM    = CSMODE[CSMODE_PM_HI   : CSMODE_PM_LO];
assign CSMODE_CSBEF = CSMODE[CSMODE_CSBEF_HI: CSMODE_CSBEF_LO];
assign CSMODE_CSAFT = CSMODE[CSMODE_CSAFT_HI: CSMODE_CSAFT_LO];
assign CSMODE_CSCG  = CSMODE[CSMODE_CSCG_HI : CSMODE_CSCG_LO];

assign csmode_pm   = {{(NBITS_BRG_DIVIDER-NBITS_PM){1'b0}}, CSMODE_PM} + 1;
assign brg_divider = CSMODE[CSMODE_DIV16] ? (csmode_pm << 4)-1 : csmode_pm-1;
// assign brg_divider = {{(NBITS_BRG_DIVIDER-4){1'b0}}, 4'h3};

assign char_go_wire = chr_go;
assign char_done_wire = chr_done;

wire   brg_out_first_edge;
assign brg_out_first_edge = CSMODE[CSMODE_CI] ? brg_neg_edge : brg_pos_edge;
wire   brg_out_second_edge;
assign brg_out_second_edge = CSMODE[CSMODE_CI] ? brg_pos_edge : brg_neg_edge;

// always @(posedge brg_out_second_edge)
always @(posedge S_SYSCLK /* or negedge S_RESETN */)
begin
    if (1'b0 == S_RESETN) begin
        data_rx <= 16'h0000;
        spi_sel <= {NCS{1'b1}};

        cnt_csbef <= 0;
        cnt_csaft <= 0;
        cnt_cscg  <= 0;

        t_spi_mosi <= 0;
        spi_brg_go <= 0;

        chr_go       <= 0;
        chr_done     <= 0;
        char_bit_cnt <= 0;
        char_trx_idx <= 0;
        char_rx_idx <= 0;
        spirf_char_idx <= 0;

        frame_go   <= 0;
        frame_done <= 0;
        frame_in_process <= 0;
        frame_next_start <= 0;
        frame_state <= FRAME_SM_IDLE;
        for (idx = 0; idx < NCS; idx = idx + 1) begin
            CSXMODE[idx] <= CSMODE_DEF;
        end
        // SPIRF_WR <= 0;
    end
    else begin
        // SPIRF_WR = SPI_RXFIFO[spirf_wr_idx];
        if (csmodex_updated) begin
            CSXMODE[cs_idx] <= csmodex;
            spi_sel[cs_idx] <= csmodex[CSMODE_POL] ? 1'b1 : 1'b0;
        end

        if (spirf_updated) begin
            if (0 == spirf_rd_idx) begin
                spirf_char_idx <= 0; // need to another side to reset
            end
        end

        if (frame_go) begin
            frame_go <= 0;

            // 0: MOSI pin as output; 1: MOSI is input;
            t_spi_mosi <= 1'b0;
            char_trx_idx <= 0;
            spirf_char_idx <= 0;
            spi_sel[SPCOM_CS] <= CSMODE[CSMODE_POL] ? 1'b0 : 1'b1;
            spi_brg_go <= 1;
        end
        if (1'b1 == frame_done) begin
            frame_done <= 0;
            char_trx_idx <= 0;
        end
        if (chr_done) begin
            chr_done <= 0;
            if (1'b0 == SPCOM[SPCOM_TO]) begin
                if (char_trx_idx > SPCOM_RSKIP) begin
                    char_rx_idx <= char_trx_idx - SPCOM_RSKIP;
                end
                else if (char_rx_idx > 0) begin
                    char_rx_idx <= char_rx_idx + 1;
                end
                if (char_rx_idx > 0) begin
                    spirf_char_idx <= spirf_char_idx + 1;
                end
                else begin
                    spirf_char_idx <= 0;
                end
                if (CSMODE[CSMODE_IS3WIRE]) begin
                    if ((SPCOM_RSKIP > 0) && (char_trx_idx == SPCOM_RSKIP)) begin
                        t_spi_mosi <= 1'b1; // change mosi pin as input
                    end
                end
            end
            if (frame_in_process) begin
                case(frame_state)
                    FRAME_SM_IN_TRANS:
                    begin
                        if (TXE) begin
                            frame_state <= FRAME_SM_DATA_WAIT;
                        end
                    end
                    default:;
                endcase
            end
        end
        if (chr_go) begin
            chr_go <= 0;
        end
        if (char_go_wire) begin
            if (CSMODE[CSMODE_CP]) begin
                if (CSMODE[CSMODE_REV]) begin
                    char_bit_cnt <= CSMODE_LEN + 1;
                end
                else begin
                    char_bit_cnt <= MAX_BITNO_OF_CHAR;
                end
            end
            else begin
                if (CSMODE[CSMODE_REV]) begin
                    char_bit_cnt <= CSMODE_LEN;
                end
                else begin
                    char_bit_cnt <= 0;
                end
            end
        end
        if (spcom_updated) begin
            spi_brg_go <= 0;
            char_rx_idx <= 0;
            if (FRAME_SM_IDLE == frame_state) begin
                frame_go <= 1;
                frame_in_process <= 1;
                frame_state <= FRAME_SM_BEF_WAIT;
                cnt_cscg <= CSMODE_CSCG;
            end
            else begin
                frame_next_start <= 1;
            end

            cnt_csbef <= CSMODE_CSBEF;
            cnt_csaft <= CSMODE_CSAFT;
        end
        if (1'b1 == brg_out_second_edge) begin
            if (FRAME_SM_IN_TRANS == frame_state) begin
                if (1'b1 == CSMODE[CSMODE_CP]) begin
                    data_rx[char_bit_cnt] <= din;
                end /* (1'b1 = CSMODE[CSMODE_CP]) */
                else begin /* (1'b0 = CSMODE[CSMODE_CP]) */
                    if (CSMODE[CSMODE_REV]) begin
                        char_bit_cnt <= char_bit_cnt - 1;
                    end
                    else begin
                        char_bit_cnt <= char_bit_cnt + 1;
                    end
                end
                if (CSMODE[CSMODE_REV]) begin
                    if (0 == char_bit_cnt) begin
                        chr_done <= 1;
                        char_trx_idx <= char_trx_idx + 1;
                        if (char_trx_idx == SPCOM_TRANLEN) begin
                            char_trx_idx <= 0;
                            frame_state <= FRAME_SM_AFT_WAIT;
                        end
                        else begin
                            chr_go <= 1;
                        end
                    end
                end
                else begin
                    if (CSMODE_LEN == char_bit_cnt) begin
                        chr_done <= 1;
                        char_trx_idx <= char_trx_idx + 1;
                        if (char_trx_idx == SPCOM_TRANLEN) begin
                            char_trx_idx <= 0;
                            frame_state <= FRAME_SM_AFT_WAIT;
                        end
                        else begin
                            chr_go <= 1;
                        end
                    end
                end
            end /* (FRAME_SM_IN_TRANS == frame_state) */
            /* frame state deal at the second clock phase */
            case (frame_state)
                FRAME_SM_IDLE: ;
                FRAME_SM_BEF_WAIT:
                begin
                    if (cnt_csbef > 0) begin
                        cnt_csbef <= cnt_csbef - 1;
                    end
                    else begin
                        if (TXE) begin
                            frame_state <= FRAME_SM_DATA_WAIT;
                        end
                        else begin
                            chr_go <= 1;
                            frame_state <= FRAME_SM_IN_TRANS;
                        end
                    end
                end
                FRAME_SM_DATA_WAIT:
                begin
                    if (!TXE) begin
                        frame_state <= FRAME_SM_IN_TRANS;
                        chr_go <= 1;
                    end
                end
                FRAME_SM_IN_TRANS:;
                FRAME_SM_AFT_WAIT:
                begin
                    if (cnt_csaft > 0) begin
                        cnt_csaft <= cnt_csaft - 1;
                    end
                    else begin
                        frame_done <= 1;
                        frame_in_process <= 0;
                        frame_state <= FRAME_SM_CG_WAIT;
                        spi_sel[SPCOM_CS] <= CSMODE[CSMODE_POL] ? 1'b1 : 1'b0;
                    end
                end
                FRAME_SM_CG_WAIT:
                begin
                    if (cnt_cscg > 0) begin
                        cnt_cscg <= cnt_cscg - 1;
                    end
                    else begin
                        if (frame_next_start) begin
                            frame_state <= FRAME_SM_BEF_WAIT;
                            frame_next_start <= 0;
                            frame_go <= 1;
                            frame_in_process <= 1;
                            cnt_cscg <= CSMODE_CSCG;
                        end
                        else begin
                            frame_state <= FRAME_SM_IDLE;
                        end
                    end
                end
                default:;
            endcase
        end /* (1'b1 == brg_out_second_edge) */
        if (brg_out_first_edge) begin
            if (FRAME_SM_IN_TRANS == frame_state) begin
                if (1'b1 == CSMODE[CSMODE_CP])
                begin
                    if (CSMODE[CSMODE_REV]) begin
                        char_bit_cnt <= char_bit_cnt - 1;
                    end
                    else begin
                        char_bit_cnt <= char_bit_cnt + 1;
                    end
                end /* CSMODE_CP=1'b1 */
                else begin
                    data_rx[char_bit_cnt] <= din;
                end
            end
        end
    end
end

// always @(posedge char_done_wire)
always @(posedge S_SYSCLK /* or negedge S_RESETN */)
begin
    if (1'b0 == S_RESETN) begin
        for (byte_index = 0; byte_index < NWORD_TXFIFO; byte_index = byte_index + 1)
        begin
            SPI_RXFIFO[byte_index] <= 0;
        end
    end
    else begin
        if (1'b1 == brg_out_second_edge) begin
            if (FRAME_SM_IN_TRANS == frame_state) begin
                if (CSMODE[CSMODE_CP]) begin
                    if (1'b1 == CSMODE[CSMODE_REV]) begin
                        if (0 == char_bit_cnt) begin
                            if (CSMODE_LEN > 7) begin // occupy two bytes(16 bit)
                                if (1'b1 == spirf_char_idx[0]) begin
                                    SPI_RXFIFO[spirf_wr_idx] <= {data_rx[15:1], din, SPIRF_WR[15:0]};
                                end
                                else begin
                                    SPI_RXFIFO[spirf_wr_idx] <= {{16{1'b0}}, data_rx[15:1], din};
                                end
                            end
                            else begin
                                case(spirf_char_idx[1:0])
                                    0 : SPI_RXFIFO[spirf_wr_idx] <= {{24{1'b0}}, data_rx[7:1], din};
                                    1 : SPI_RXFIFO[spirf_wr_idx] <= {{16{1'b0}}, data_rx[7:1], din, SPIRF_WR[7:0]};
                                    2 : SPI_RXFIFO[spirf_wr_idx] <= {{8{1'b0}}, data_rx[7:1], din, SPIRF_WR[15:0]};
                                    3 : SPI_RXFIFO[spirf_wr_idx] <= {data_rx[7:1], din, SPIRF_WR[23:0]};
                                endcase
                            end
                        end
                    end
                    else begin /* (1'b0 == CSMODE[CSMODE_REV]) */
                        if (CSMODE_LEN == char_bit_cnt) begin
                            if (CSMODE_LEN > 7) begin // occupy two bytes(16 bit)
                                if (1'b1 == spirf_char_idx[0]) begin
                                    case (CSMODE_LEN)
                                        8 : SPI_RXFIFO[spirf_wr_idx] <= {{7{1'b0}}, din, data_rx[7:0] , SPIRF_WR[15:0]};
                                        9 : SPI_RXFIFO[spirf_wr_idx] <= {{6{1'b0}}, din, data_rx[8:0] , SPIRF_WR[15:0]};
                                        10: SPI_RXFIFO[spirf_wr_idx] <= {{5{1'b0}}, din, data_rx[9:0] , SPIRF_WR[15:0]};
                                        11: SPI_RXFIFO[spirf_wr_idx] <= {{4{1'b0}}, din, data_rx[10:0], SPIRF_WR[10:0]};
                                        12: SPI_RXFIFO[spirf_wr_idx] <= {{3{1'b0}}, din, data_rx[11:0], SPIRF_WR[15:0]};
                                        13: SPI_RXFIFO[spirf_wr_idx] <= {{2{1'b0}}, din, data_rx[12:0], SPIRF_WR[15:0]};
                                        14: SPI_RXFIFO[spirf_wr_idx] <= {{{1'b0}} , din, data_rx[13:0], SPIRF_WR[15:0]};
                                        15: SPI_RXFIFO[spirf_wr_idx] <= {din,            data_rx[14:0], SPIRF_WR[15:0]};
                                    endcase
                                end
                                else begin
                                    case (CSMODE_LEN)
                                        8 : SPI_RXFIFO[spirf_wr_idx] <= {{16{1'b0}}, {7{1'b0}}, din, data_rx[7:0]};
                                        9 : SPI_RXFIFO[spirf_wr_idx] <= {{16{1'b0}}, {6{1'b0}}, din, data_rx[8:0]};
                                        10: SPI_RXFIFO[spirf_wr_idx] <= {{16{1'b0}}, {5{1'b0}}, din, data_rx[9:0]};
                                        11: SPI_RXFIFO[spirf_wr_idx] <= {{16{1'b0}}, {4{1'b0}}, din, data_rx[10:0]};
                                        12: SPI_RXFIFO[spirf_wr_idx] <= {{16{1'b0}}, {3{1'b0}}, din, data_rx[11:0]};
                                        13: SPI_RXFIFO[spirf_wr_idx] <= {{16{1'b0}}, {2{1'b0}}, din, data_rx[12:0]};
                                        14: SPI_RXFIFO[spirf_wr_idx] <= {{16{1'b0}}, {1{1'b0}}, din, data_rx[13:0]};
                                        15: SPI_RXFIFO[spirf_wr_idx] <= {{16{1'b0}}, din, data_rx[14:0]};
                                    endcase
                                end
                            end
                            else begin
                                if (0 == spirf_char_idx[1:0]) begin
                                    case(CSMODE_LEN)
                                        0 : SPI_RXFIFO[spirf_wr_idx] <= {{31{1'b0}}, din};
                                        1 : SPI_RXFIFO[spirf_wr_idx] <= {{30{1'b0}}, din, data_rx[0]};
                                        2 : SPI_RXFIFO[spirf_wr_idx] <= {{29{1'b0}}, din, data_rx[1:0]};
                                        3 : SPI_RXFIFO[spirf_wr_idx] <= {{28{1'b0}}, din, data_rx[2:0]};
                                        4 : SPI_RXFIFO[spirf_wr_idx] <= {{27{1'b0}}, din, data_rx[3:0]};
                                        5 : SPI_RXFIFO[spirf_wr_idx] <= {{26{1'b0}}, din, data_rx[4:0]};
                                        6 : SPI_RXFIFO[spirf_wr_idx] <= {{25{1'b0}}, din, data_rx[5:0]};
                                        7 : SPI_RXFIFO[spirf_wr_idx] <= {{24{1'b0}}, din, data_rx[6:0]};
                                    endcase
                                end
                                if (1 == spirf_char_idx[1:0]) begin
                                    case(CSMODE_LEN)
                                        0 : SPI_RXFIFO[spirf_wr_idx] <= {{23{1'b0}}, din, SPIRF_WR[7:0]};
                                        1 : SPI_RXFIFO[spirf_wr_idx] <= {{22{1'b0}}, din, data_rx[0], SPIRF_WR[7:0]};
                                        2 : SPI_RXFIFO[spirf_wr_idx] <= {{21{1'b0}}, din, data_rx[1:0], SPIRF_WR[7:0]};
                                        3 : SPI_RXFIFO[spirf_wr_idx] <= {{20{1'b0}}, din, data_rx[2:0], SPIRF_WR[7:0]};
                                        4 : SPI_RXFIFO[spirf_wr_idx] <= {{19{1'b0}}, din, data_rx[3:0], SPIRF_WR[7:0]};
                                        5 : SPI_RXFIFO[spirf_wr_idx] <= {{18{1'b0}}, din, data_rx[4:0], SPIRF_WR[7:0]};
                                        6 : SPI_RXFIFO[spirf_wr_idx] <= {{17{1'b0}}, din, data_rx[5:0], SPIRF_WR[7:0]};
                                        7 : SPI_RXFIFO[spirf_wr_idx] <= {{16{1'b0}}, din, data_rx[6:0], SPIRF_WR[7:0]};
                                    endcase
                                end
                                if (2 == spirf_char_idx[1:0]) begin
                                    case(CSMODE_LEN)
                                        0 : SPI_RXFIFO[spirf_wr_idx] <= {{15{1'b0}}, din,               SPIRF_WR[15:0]};
                                        1 : SPI_RXFIFO[spirf_wr_idx] <= {{14{1'b0}}, din, data_rx[0],   SPIRF_WR[15:0]};
                                        2 : SPI_RXFIFO[spirf_wr_idx] <= {{13{1'b0}}, din, data_rx[1:0], SPIRF_WR[15:0]};
                                        3 : SPI_RXFIFO[spirf_wr_idx] <= {{12{1'b0}}, din, data_rx[2:0], SPIRF_WR[15:0]};
                                        4 : SPI_RXFIFO[spirf_wr_idx] <= {{11{1'b0}}, din, data_rx[3:0], SPIRF_WR[15:0]};
                                        5 : SPI_RXFIFO[spirf_wr_idx] <= {{10{1'b0}}, din, data_rx[4:0], SPIRF_WR[15:0]};
                                        6 : SPI_RXFIFO[spirf_wr_idx] <= {{9{1'b0}} , din, data_rx[5:0], SPIRF_WR[15:0]};
                                        7 : SPI_RXFIFO[spirf_wr_idx] <= {{8{1'b0}} , din, data_rx[6:0], SPIRF_WR[15:0]};
                                    endcase
                                end
                                if (3 == spirf_char_idx[1:0]) begin
                                    case(CSMODE_LEN)
                                        0 : SPI_RXFIFO[spirf_wr_idx] <= {{7{1'b0}}, din,               SPIRF_WR[23:0]};
                                        1 : SPI_RXFIFO[spirf_wr_idx] <= {{6{1'b0}}, din, data_rx[0],   SPIRF_WR[23:0]};
                                        2 : SPI_RXFIFO[spirf_wr_idx] <= {{5{1'b0}}, din, data_rx[1:0], SPIRF_WR[23:0]};
                                        3 : SPI_RXFIFO[spirf_wr_idx] <= {{4{1'b0}}, din, data_rx[2:0], SPIRF_WR[23:0]};
                                        4 : SPI_RXFIFO[spirf_wr_idx] <= {{3{1'b0}}, din, data_rx[3:0], SPIRF_WR[23:0]};
                                        5 : SPI_RXFIFO[spirf_wr_idx] <= {{2{1'b0}}, din, data_rx[4:0], SPIRF_WR[23:0]};
                                        6 : SPI_RXFIFO[spirf_wr_idx] <= {{1{1'b0}}, din, data_rx[5:0], SPIRF_WR[23:0]};
                                        7 : SPI_RXFIFO[spirf_wr_idx] <= {din, data_rx[6:0],            SPIRF_WR[23:0]};
                                    endcase
                                end
                            end
                        end
                    end
                end /* (1'b1 == CSMODE[CSMODE_CP]) */
            else begin /* (1'b0 == CSMODE[CSMODE_CP]) */
                /* CP=0 full char received from din */
                if ((1'b1 == CSMODE[CSMODE_REV] && 0 == char_bit_cnt) ||
                    (1'b0 == CSMODE[CSMODE_REV] && CSMODE_LEN == char_bit_cnt)) begin /* (1'b1 == chr_done) */
                    if (CSMODE_LEN > 7) begin
                        if (spirf_char_idx[0]) begin
                            SPI_RXFIFO[spirf_wr_idx] <= {data_rx[15:0], SPIRF_WR[15:0]};
                        end
                        else begin
                            SPI_RXFIFO[spirf_wr_idx] <= {{16{1'b0}}, data_rx[15:0]};
                        end
                    end
                    else begin
                        case(spirf_char_idx[1:0])
                            0 : SPI_RXFIFO[spirf_wr_idx] <= {{24{1'b0}}, data_rx[7:0]};
                            1 : SPI_RXFIFO[spirf_wr_idx] <= {{16{1'b0}}, data_rx[7:0], SPIRF_WR[7:0]};
                            2 : SPI_RXFIFO[spirf_wr_idx] <= {{8{1'b0}}, data_rx[7:0], SPIRF_WR[15:0]};
                            3 : SPI_RXFIFO[spirf_wr_idx] <= {data_rx[7:0], SPIRF_WR[23:0]};
                        endcase
                    end
                end /* if (1'b0 == CSMODE[CSMODE_CP]) */
            end /* FRAME_SM_IN_TRANS */
            end /* FRAME_SM_IN_TRANS */
        end /* (1'b1 == brg_out_second_edge) */
    end /* S_RESETN = 1'b1 */
end

always @(posedge S_SYSCLK /* or negedge S_RESETN */)
begin
    if (1'b0 == S_RESETN)
    begin
        dout <= 0;
        data_tx <= 16'h0000;
    end
    else begin
        if (FRAME_SM_IN_TRANS == frame_state) begin
            dout = data_tx[char_bit_cnt];
        end
        if (CSMODE_LEN > 7) begin
            if (spitf_trx_char_off) begin
                data_tx <= SPITF[31:16];
            end
            else begin
                data_tx <= SPITF[15:0];
            end
        end
        else begin
            case (spitf_trx_char_off[1:0])
                0: data_tx <= {8'h00, SPITF[7:0]};
                1: data_tx <= {8'h00, SPITF[15:8]};
                2: data_tx <= {8'h00, SPITF[23:16]};
                3: data_tx <= {8'h00, SPITF[31:24]};
                default :;
            endcase
        end
    end
end

always @(posedge S_SYSCLK /* or negedge S_RESETN */)
begin
    if (S_RESETN == 1'b0 )
    begin
        SPMODE  <= SPMODE_DEF;
        SPIE    <= SPIE_DEF;
        SPIM    <= SPIM_DEF;
        SPCOM   <= SPCOM_DEF;
        SPIRF   <= SPIRF_DEF;
        cs_idx <= 0;
        csmodex <= CSMODE_DEF;
        csmodex_updated <= 0;

        spcom_updated <= 0;
        spitf_updated <= 0;
        spirf_updated <= 0;

        spirf_rd_idx <= 0;

        spitf_idx <= 0;
        num_spitf_upd <= 0;

        nbytes_read_from_spirf <= 0;
        for (byte_index = 0; byte_index < NWORD_TXFIFO; byte_index = byte_index + 1)
        begin
            SPI_TXFIFO[byte_index] <= 0;
        end
        // SPITF <= 0;
    end
    else begin
        if (SPMODE[SPMODE_EN]) begin
            SPIRF <= SPI_RXFIFO[spirf_rd_idx];
        end
        else begin
            SPIRF <= SPIRF_DEF;
            spitf_idx <= 0;
            num_spitf_upd <= 0;

            spirf_rd_idx  <= 0;
            spirf_updated <= 0;
            nbytes_read_from_spirf <= 0;
        end
        SPIE[SPIE_TXE] <= TXE;
        SPIE[SPIE_TNF] <= TNF;
        SPIE[SPIE_TXT] <= TXT;
        SPIE[SPIE_RNE] <= RNE;
        SPIE[SPIE_RXF] <= RXF;
        SPIE[SPIE_RXT] <= RXT;
        SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO] <= RXCNT[NBITS_RXCNT-1: 0];
        SPIE[SPIE_TXCNT_HI:SPIE_TXCNT_LO] <= TXCNT[NBITS_TXCNT-1: 0];
        if (frame_done) begin
            SPIE[SPIE_DON] <= 1'b1;
            spitf_idx <= 0;
            num_spitf_upd <= 0;
        end
        if (frame_go) begin
            spirf_rd_idx  <= 0;
            spirf_updated <= 0;
            nbytes_read_from_spirf <= 0;
        end
        if (1'b1 == spcom_updated) begin
            spcom_updated <= 0;
        end
        if (1'b1 == spitf_updated) begin
            spitf_updated <= 0;
        end
        if (1'b1 == spirf_updated) begin
            spirf_updated <= 0;
        end
        if (csmodex_updated) begin
            csmodex_updated <= 0;
        end

        // SPITF = SPI_TXFIFO[spitf_trx_idx];
        if (S_REG_RDEN)
        begin
            case (S_ARADDR)
                ADDR_SPIRF  :
                begin
                    if (RNE) begin
                        spirf_updated <= 1;
                        if (nbytes_valid_in_rxfifo < NBYTES_PER_WORD) begin
                            spirf_rd_idx <= 0;
                            nbytes_read_from_spirf <= nbytes_read_from_spirf + nbytes_valid_in_rxfifo;
                        end
                        else begin
                            spirf_rd_idx <= spirf_rd_idx + 1;
                            nbytes_read_from_spirf <= nbytes_read_from_spirf + NBYTES_PER_WORD;
                        end
                    end
                end
                default: ;
            endcase
        end
        if (S_REG_WEN) begin
            if (S_WSTRB == {4{1'b1}}) begin /* only support 32bits write */
                case (S_AWADDR[7:2])
                    ADDR_SPMODE : SPMODE <= S_WDATA;
                    ADDR_SPIE[7:2]:
                    begin
                        // SPIE <= S_WDATA;
                        for (idx = 0; idx < NBITS_PER_WORD; idx = idx + 1) begin
                            if (S_WDATA[idx]) begin
                                SPIE[idx] <= 1'b0;
                            end
                        end
                    end
                    ADDR_SPIM[7:2]: SPIM <= S_WDATA;
                    ADDR_SPCOM[7:2]:
                    begin
                        SPCOM <= S_WDATA;
                        if ((FRAME_SM_IDLE == frame_state) || (FRAME_SM_CG_WAIT == frame_state)) begin
                            if (1'b1 == SPMODE[SPMODE_EN]) begin
                                spcom_updated <= 1; // new frame can start
                            end
                        end
                    end
                    ADDR_SPITF[7:2]:
                    begin
                        if (SPMODE[SPMODE_EN]) begin
                            if (TNF)
                            begin
                                spitf_updated <= 1;
                                SPI_TXFIFO[spitf_idx] <= S_WDATA;
                                spitf_idx <= spitf_idx + 1;
                                num_spitf_upd <= num_spitf_upd  + 1;
                            end
                        end
                    end
                    ADDR_SPIRF[7:2]: ; // read only for SPIRF
                    ADDR_CSMODE0[7:2], ADDR_CSMODE1[7:2], ADDR_CSMODE2[7:2], ADDR_CSMODE3[7:2]:
                    begin
                        cs_idx <= S_AWADDR[7:2] - ADDR_CSMODE0[7:2];
                        csmodex <= S_WDATA;
                        csmodex_updated <= 1;
                    end
                    default : begin
                    end
                endcase
            end
        end
    end
end

spi_clk_gen # (.C_DIVIDER_WIDTH(NBITS_BRG_DIVIDER)) spi_brg (
    .sysclk(S_SYSCLK),           // system clock input
    .rst_n(S_RESETN),            // module reset
    .enable(spi_brg_go),  // module enable
    .go(spi_brg_go),                 // start transmit
    .CPOL(CSMODE[CSMODE_CI]),           // clock polarity
    .last_clk(1'b0),     // last clock
    .divider_i(brg_divider),     // divider;
    .clk_out(brg_clk),           // clock output
    .pos_edge(brg_pos_edge),     // positive edge flag
    .neg_edge(brg_neg_edge)      // negtive edge flag
);

assign S_RDATA = reg_data_out;
always @(*)
begin
    case (S_ARADDR)
        ADDR_SPMODE : reg_data_out <= SPMODE;
        ADDR_SPIE   : reg_data_out <= SPIE;     // register read data
        ADDR_SPCOM  : reg_data_out <= SPCOM;
        ADDR_SPIM   : reg_data_out <= SPIM;
        ADDR_CSMODE0: reg_data_out <= CSXMODE[0];
        ADDR_CSMODE1: reg_data_out <= NCS < 2? {32{1'b0}} : CSXMODE[1];
        ADDR_CSMODE2: reg_data_out <= NCS < 3? {32{1'b0}} : CSXMODE[2];
        ADDR_CSMODE3: reg_data_out <= NCS < 4? {32{1'b0}} : CSXMODE[3];
        ADDR_SPITF  : reg_data_out <= SPITF;
        ADDR_SPIRF  : reg_data_out <= SPIRF;
        default     : reg_data_out <= 0;
    endcase
end

endmodule

