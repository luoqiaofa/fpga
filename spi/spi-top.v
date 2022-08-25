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
`include "spi-reg-def.v"
`include "const.v"

(* keep = "true" *) reg [31: 0] SPMODE;
(* keep = "true" *) reg [31: 0] SPIE;
(* keep = "true" *) reg [31: 0] SPIM;
(* keep = "true" *) reg [31: 0] SPCOM;
(* keep = "true" *) reg [31: 0] SPITD;
(* keep = "true" *) reg [31: 0] SPIRD;
(* keep = "true" *) reg [31: 0] CSXMODE[0:NCS-1];

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
wire [NBITS_TRANLEN-1:0]    SPCOM_TRANLEN;

reg [NBITS_CSBEF-1:0]       cnt_csbef;
reg [NBITS_CSAFT-1:0]       cnt_csaft;
reg [NBITS_CSCG   :0]       cnt_cscg;

reg [NCS-1:0] spi_sel;

reg [31:0] reg_data_out;

/* spi transactions flags or counters begin */
(* mark_debug = "true" *) reg frame_in_process;
(* mark_debug = "false" *) reg frame_next_start;
(* mark_debug = "true" *) reg frame_go;
(* mark_debug = "true" *) reg frame_done;
(* mark_debug = "true" *) reg [2:0] frame_state; // frame machine state;
(* mark_debug = "true" *) reg  chr_go;
(* mark_debug = "true" *) reg  chr_done;

localparam FRAME_SM_IDLE      = 0;
localparam FRAME_SM_BEF_WAIT  = 1;
localparam FRAME_SM_DATA_WAIT = 2;
localparam FRAME_SM_IN_TRANS  = 3;
localparam FRAME_SM_AFT_WAIT  = 4;
localparam FRAME_SM_CG_WAIT   = 5;

(* mark_debug = "true" *) reg [3:0] char_bit_cnt;
localparam MAX_BITNO_OF_CHAR = 4'hf;
/* spi transactions flags or counters end */

(* mark_debug = "true" *) reg [15:0] data_rx;
(* mark_debug = "true" *) reg [15:0] data_tx;

reg  spi_brg_go;
(* mark_debug = "true" *) wire brg_clk;
wire brg_pos_edge;
wire brg_neg_edge;
localparam NBITS_BRG_DIVIDER = NBITS_PM + 4 + 2;
wire [NBITS_BRG_DIVIDER-1:0] csmode_pm;
wire [NBITS_BRG_DIVIDER-1:0] brg_divider;

(* mark_debug = "true" *) reg  [NBITS_TRANLEN-1:0] char_trx_idx;
(* mark_debug = "true" *) reg  [NBITS_TRANLEN-1:0] char_rx_idx; // count number of char from miso in master mode
// one word is 32 bit. half word is 16 bit
(* mark_debug = "true" *) reg  [NBITS_TRANLEN-1:0] num_spitd_upd;

reg [1:0] cs_idx;
(* mark_debug = "true" *) reg [NBITS_TRANLEN-1:0] spird_char_idx; // char offset from miso to spird(rx fifo)
//  char offset in spitd
// 4 bytes per word

// assign char_rx_idx = char_trx_idx < SPCOM_RSKIP ? 0 : char_trx_idx - SPCOM_RSKIP;
reg    RNE;   // Received not empty. 
reg    TNF;   // tansmmiter is not full, ie. have no data to be tx

(* mark_debug = "true" *) reg spcom_updated;
(* mark_debug = "true" *) reg spitd_updated;
(* mark_debug = "true" *) reg spird_updated;

integer idx;

(* mark_debug = "true" *) wire i_spi_mosi;
(* mark_debug = "true" *) wire o_spi_mosi;
reg  t_spi_mosi;

wire i_spi_miso;

wire din;

// pullup pullup_miso_i(i_spi_miso);
// pullup pullup_mosi_i(i_spi_mosi);

assign o_spi_mosi = (FRAME_SM_IN_TRANS == frame_state) ? data_tx[char_bit_cnt] : 1'b0;
assign S_SPI_SCK  = (FRAME_SM_IN_TRANS == frame_state) ? brg_clk : CSMODE[CSMODE_CPOL];
assign S_SPI_SEL  = spi_sel;

assign i_spi_miso = CSMODE[CSMODE_IS3WIRE] ? i_spi_mosi : S_SPI_MISO;
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

wire   brg_out_first_edge;
assign brg_out_first_edge = CSMODE[CSMODE_CPOL] ? brg_neg_edge : brg_pos_edge;
wire   brg_out_second_edge;
assign brg_out_second_edge = CSMODE[CSMODE_CPOL] ? brg_pos_edge : brg_neg_edge;

always @(posedge S_SYSCLK)
begin
    if (1'b0 == S_RESETN) begin
        data_rx <= 0;
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

        frame_go   <= 0;
        frame_done <= 0;
        frame_in_process <= 0;
        frame_next_start <= 0;
        frame_state <= FRAME_SM_IDLE;
        for (idx = 0; idx < NCS; idx = idx + 1) begin
            CSXMODE[idx] <= CSMODE_DEF;
        end
        RNE <= 1'b0;
        TNF <= 1'b1;
    end
    else begin
        if (1'b1 == spitd_updated) begin
            TNF <= 1'b0;
            if (FRAME_SM_DATA_WAIT == frame_state) begin
                frame_state <= FRAME_SM_IN_TRANS;
            end
        end
        else begin
            if (1'b1 == chr_done) begin
                if (CSMODE_LEN > 7) begin
                    if (1'b0 == char_trx_idx[0]) begin
                        TNF <= 1'b1;
                        if (FRAME_SM_IN_TRANS == frame_state) begin
                            frame_state <= FRAME_SM_DATA_WAIT;
                        end
                    end
                end
                else begin
                    if (2'b00 == char_trx_idx[1:0]) begin
                        TNF <= 1'b1;
                        if (FRAME_SM_IN_TRANS == frame_state) begin
                            frame_state <= FRAME_SM_DATA_WAIT;
                        end
                    end
                end
            end
        end
        if (spird_char_idx > 0) begin
            RNE = 1;
        end
        if (1'b1 == spird_updated) begin
            RNE = 0;
            spird_char_idx <= 0;
        end
        if (csmodex_updated) begin
            CSXMODE[cs_idx] <= csmodex;
            spi_sel[cs_idx] <= csmodex[CSMODE_POL] ? 1'b1 : 1'b0;
        end

        if (frame_go) begin
            frame_go <= 0;

            // 0: MOSI pin as output; 1: MOSI is input;
            t_spi_mosi <= 1'b0;
            char_trx_idx <= 0;
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
                        if (TNF) begin
                            frame_state <= FRAME_SM_DATA_WAIT;
                        end
                    end
                    default:;
                endcase
            end
        end
        if (chr_go) begin
            chr_go <= 0;
            data_rx <= 0;
        end
        if (char_go_wire || spcom_updated) begin
            if (CSMODE[CSMODE_CPHA]) begin
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
            char_trx_idx <= 0;
            if (FRAME_SM_IDLE == frame_state) begin
                frame_go <= 1;
                spi_brg_go <= 0;
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
                if (1'b1 == CSMODE[CSMODE_CPHA]) begin
                    data_rx[char_bit_cnt] <= din;
                end /* (1'b1 = CSMODE[CSMODE_CPHA]) */
                else begin /* (1'b0 = CSMODE[CSMODE_CPHA]) */
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
                        if (TNF) begin
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
                    if (!TNF) begin
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
                            spi_brg_go <= 0;
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
                if (1'b1 == CSMODE[CSMODE_CPHA])
                begin
                    if (CSMODE[CSMODE_REV]) begin
                        char_bit_cnt <= char_bit_cnt - 1;
                    end
                    else begin
                        char_bit_cnt <= char_bit_cnt + 1;
                    end
                end /* CSMODE_CPHA=1'b1 */
                else begin
                    data_rx[char_bit_cnt] <= din;
                end
            end
        end
    end
end

always @(posedge S_SYSCLK)
begin
    if (1'b0 == S_RESETN || (1'b0 == SPMODE[SPMODE_EN])) begin
        SPIRD <= SPIRD_DEF;
        char_rx_idx <= 0;
        spird_char_idx <= 0;
    end
    else begin
        if (spcom_updated) begin
            char_rx_idx <= 0;
            spird_char_idx <= 0;
        end

        if (chr_done) begin /* (1'b1 == chr_done) */
            if (1'b0 == SPCOM[SPCOM_TO]) begin
                if (char_rx_idx > 0) begin
                    spird_char_idx <= spird_char_idx + 1;
                end
                else begin
                    spird_char_idx <= 0;
                end
            end
        end /* if (1'b0 == CSMODE[CSMODE_CPHA]) */
        if (1'b1 == brg_out_second_edge && (1'b0 == SPCOM[SPCOM_TO])) begin
            if (FRAME_SM_IN_TRANS == frame_state) begin
                if (CSMODE[CSMODE_CPHA]) begin
                    if (CSMODE[CSMODE_REV]) begin
                        if (0 == char_bit_cnt) begin
                            if (~(|SPCOM_RSKIP)) begin
                                char_rx_idx <= char_rx_idx + 1;
                            end
                            else begin
                                if (char_trx_idx > (SPCOM_RSKIP - 1)) begin
                                    char_rx_idx <= char_trx_idx + 1 - SPCOM_RSKIP;
                                end
                                else if (char_rx_idx > 0) begin
                                    char_rx_idx <= char_rx_idx + 1;
                                end
                            end
                            if (CSMODE_LEN > 7) begin
                                if (spird_char_idx[0]) begin
                                    SPIRD[31:16] <= {data_rx[15:1], din};
                                end
                                else begin
                                    SPIRD <= {{16{1'b0}}, data_rx[15:1], din};
                                end
                            end
                            else begin
                                case(spird_char_idx[1:0])
                                    0 : SPIRD        <= {{24{1'b0}}, data_rx[7:1], din};
                                    1 : SPIRD[15:8]  <= {data_rx[7:1], din};
                                    2 : SPIRD[23:16] <= {data_rx[7:1], din};
                                    3 : SPIRD[31:24] <= {data_rx[7:1], din};
                                endcase
                            end
                        end
                    end /* (1'b1 == CSMODE[CSMODE_REV]) */
                    else begin /* (1'b0 == CSMODE[CSMODE_REV]) */
                        if (CSMODE_LEN == char_bit_cnt) begin
                            if (~(|SPCOM_RSKIP)) begin
                                char_rx_idx <= char_rx_idx + 1;
                            end
                            else begin
                                if (char_trx_idx > (SPCOM_RSKIP - 1)) begin
                                    char_rx_idx <= char_trx_idx + 1 - SPCOM_RSKIP;
                                end
                                else if (char_rx_idx > 0) begin
                                    char_rx_idx <= char_rx_idx + 1;
                                end
                            end
                            if (CSMODE_LEN > 7) begin
                                if (spird_char_idx[0]) begin
                                    case (CSMODE_LEN)
                                         8: SPIRD[31:16] <= {{7{1'b0}}, din, data_rx[7:0]};
                                         9: SPIRD[31:16] <= {{6{1'b0}}, din, data_rx[8:0]};
                                        10: SPIRD[31:16] <= {{5{1'b0}}, din, data_rx[9:0]};
                                        11: SPIRD[31:16] <= {{4{1'b0}}, din, data_rx[10:0]};
                                        12: SPIRD[31:16] <= {{3{1'b0}}, din, data_rx[11:0]};
                                        13: SPIRD[31:16] <= {{2{1'b0}}, din, data_rx[12:0]};
                                        14: SPIRD[31:16] <= {{1{1'b0}}, din, data_rx[13:0]};
                                        15: SPIRD[31:16] <= {           din, data_rx[14:0]};
                                    endcase
                                end
                                else begin
                                    case (CSMODE_LEN)
                                         8: SPIRD <= {{23{1'b0}}, din, data_rx[7:0]};
                                         9: SPIRD <= {{22{1'b0}}, din, data_rx[8:0]};
                                        10: SPIRD <= {{21{1'b0}}, din, data_rx[9:0]};
                                        11: SPIRD <= {{20{1'b0}}, din, data_rx[10:0]};
                                        12: SPIRD <= {{19{1'b0}}, din, data_rx[11:0]};
                                        13: SPIRD <= {{18{1'b0}}, din, data_rx[11:0]};
                                        14: SPIRD <= {{17{1'b0}}, din, data_rx[13:0]};
                                        15: SPIRD <= {{16{1'b0}}, din, data_rx[14:0]};
                                    endcase
                                end
                            end
                            else begin
                                if (0 == spird_char_idx[1:0]) begin
                                    case (CSMODE_LEN)
                                        0: SPIRD <= {{31{1'b0}}, din               };
                                        1: SPIRD <= {{30{1'b0}}, din, data_rx[0]};
                                        2: SPIRD <= {{29{1'b0}}, din, data_rx[1:0]};
                                        3: SPIRD <= {{28{1'b0}}, din, data_rx[2:0]};
                                        4: SPIRD <= {{27{1'b0}}, din, data_rx[3:0]};
                                        5: SPIRD <= {{26{1'b0}}, din, data_rx[4:0]};
                                        6: SPIRD <= {{25{1'b0}}, din, data_rx[5:0]};
                                        7: SPIRD <= {{24{1'b0}}, din, data_rx[6:0]};
                                    endcase
                                end
                                if (1 == spird_char_idx[1:0]) begin
                                    case (CSMODE_LEN)
                                        0: SPIRD[15:8] <= {{7{1'b0}}, din               };
                                        1: SPIRD[15:8] <= {{6{1'b0}}, din, data_rx[  0]};
                                        2: SPIRD[15:8] <= {{5{1'b0}}, din, data_rx[1:0]};
                                        3: SPIRD[15:8] <= {{4{1'b0}}, din, data_rx[2:0]};
                                        4: SPIRD[15:8] <= {{3{1'b0}}, din, data_rx[3:0]};
                                        5: SPIRD[15:8] <= {{2{1'b0}}, din, data_rx[4:0]};
                                        6: SPIRD[15:8] <= {{1{1'b0}}, din, data_rx[5:0]};
                                        7: SPIRD[15:8] <= {           din, data_rx[6:0]};
                                    endcase
                                end
                                if (2 == spird_char_idx[1:0]) begin
                                    case (CSMODE_LEN)
                                        0: SPIRD[23:16] <= {{7{1'b0}}, din               };
                                        1: SPIRD[23:16] <= {{6{1'b0}}, din, data_rx[  0]};
                                        2: SPIRD[23:16] <= {{5{1'b0}}, din, data_rx[1:0]};
                                        3: SPIRD[23:16] <= {{4{1'b0}}, din, data_rx[2:0]};
                                        4: SPIRD[23:16] <= {{3{1'b0}}, din, data_rx[3:0]};
                                        5: SPIRD[23:16] <= {{2{1'b0}}, din, data_rx[4:0]};
                                        6: SPIRD[23:16] <= {{1{1'b0}}, din, data_rx[5:0]};
                                        7: SPIRD[23:16] <= {           din, data_rx[6:0]};
                                    endcase
                                end
                                if (3 == spird_char_idx[1:0]) begin
                                    case (CSMODE_LEN)
                                        0: SPIRD[31:24] <= {{7{1'b0}}, din               };
                                        1: SPIRD[31:24] <= {{6{1'b0}}, din, data_rx[  0]};
                                        2: SPIRD[31:24] <= {{5{1'b0}}, din, data_rx[1:0]};
                                        3: SPIRD[31:24] <= {{4{1'b0}}, din, data_rx[2:0]};
                                        4: SPIRD[31:24] <= {{3{1'b0}}, din, data_rx[3:0]};
                                        5: SPIRD[31:24] <= {{2{1'b0}}, din, data_rx[4:0]};
                                        6: SPIRD[31:24] <= {{1{1'b0}}, din, data_rx[5:0]};
                                        7: SPIRD[31:24] <= {           din, data_rx[6:0]};
                                    endcase
                                end
                            end
                        end
                    end /* (1'b0 == CSMODE[CSMODE_REV]) */
                end /* (1'b1 == CSMODE[CSMODE_CPHA]) */
                else begin
                    if ((CSMODE[CSMODE_REV] && ~(|char_bit_cnt)) || (!CSMODE[CSMODE_REV] && (CSMODE_LEN == char_bit_cnt))) begin
                        if (~(|SPCOM_RSKIP)) begin
                            char_rx_idx <= char_rx_idx + 1;
                        end
                        else begin
                            if (char_trx_idx > (SPCOM_RSKIP - 1)) begin
                                char_rx_idx <= char_trx_idx + 1 - SPCOM_RSKIP;
                            end
                            else if (char_rx_idx > 0) begin
                                char_rx_idx <= char_rx_idx + 1;
                            end
                        end
                        if (CSMODE_LEN > 7) begin
                            if (spird_char_idx[0]) begin
                                SPIRD[31:16] <= data_rx;
                            end
                            else begin
                                SPIRD <= {{16{1'b0}}, data_rx};
                            end
                        end
                        else begin
                            case(spird_char_idx[1:0])
                                0 : SPIRD        <= {{24{1'b0}}, data_rx};
                                1 : SPIRD[15:8]  <= data_rx[7:0];
                                2 : SPIRD[23:16] <= data_rx[7:0];
                                3 : SPIRD[31:24] <= data_rx[7:0];
                            endcase
                        end
                    end
                end /* (1'b0 == CSMODE[CSMODE_CPHA]) */
            end /* (FRAME_SM_IN_TRANS == frame_state) */
        end /* (1'b1 == brg_out_second_edge) */
        /* CP=0 full char received from din */
    end /* S_RESETN = 1'b1 */
end

always @(posedge S_SYSCLK)
begin
    if (1'b0 == S_RESETN)
    begin
        data_tx <= 16'h0000;
    end
    else begin
        if (CSMODE_LEN > 7) begin
            if (char_trx_idx[0]) begin
                data_tx <= SPITD[31:16];
            end
            else begin
                data_tx <= SPITD[15:0];
            end
        end
        else begin
            case (char_trx_idx[1:0])
                0: data_tx <= {8'h00, SPITD[7:0]};
                1: data_tx <= {8'h00, SPITD[15:8]};
                2: data_tx <= {8'h00, SPITD[23:16]};
                3: data_tx <= {8'h00, SPITD[31:24]};
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
        cs_idx <= 0;
        csmodex <= CSMODE_DEF;
        csmodex_updated <= 0;

        spcom_updated <= 0;
        spitd_updated <= 0;
        spird_updated <= 0;

        num_spitd_upd <= 0;

        SPITD <= 0;
    end
    else begin
        if (1'b0 == SPMODE[SPMODE_EN]) begin
            num_spitd_upd <= 0;
            spird_updated <= 0;
        end
        if (frame_done) begin
            SPIE[SPIE_DON] <= 1'b1;
            num_spitd_upd <= 0;
        end
        SPIE[SPIE_DNR] <= 0;
        SPIE[SPIE_OV]  <= 0;
        SPIE[SPIE_UN]  <= 0;
        SPIE[SPIE_MME] <= 0;
        SPIE[SPIE_RNE] <= RNE;
        SPIE[SPIE_TNF] <= TNF;
        if (frame_go) begin
            spird_updated <= 0;
        end
        if (1'b1 == spcom_updated) begin
            spcom_updated <= 0;
        end
        if (1'b1 == spitd_updated) begin
            spitd_updated <= 0;
        end
        if (1'b1 == spird_updated) begin
            spird_updated <= 0;
        end
        if (csmodex_updated) begin
            csmodex_updated <= 0;
        end

        if (S_REG_RDEN)
        begin
            case (S_ARADDR)
                ADDR_SPIRD  :
                begin
                    spird_updated <= 1;
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
                        for (idx = 0; idx < NBITS_PER_WORD; idx = idx + 1) begin
                            if (S_WDATA[idx]) begin
                                SPIE[idx] <= 1'b0;
                            end
                        end
                    end
                    ADDR_SPIM[7:2]: SPIM <= S_WDATA;
                    ADDR_SPCOM[7:2]:
                    begin
                        if ((FRAME_SM_IDLE == frame_state) || (FRAME_SM_CG_WAIT == frame_state)) begin
                            SPCOM <= S_WDATA;
                            if (1'b1 == SPMODE[SPMODE_EN]) begin
                                spcom_updated <= 1; // new frame can start
                            end
                        end
                    end
                    ADDR_SPITD[7:2]:
                    begin
                        if (SPMODE[SPMODE_EN]) begin
                            if (TNF)
                            begin
                                SPITD <= S_WDATA;
                                spitd_updated <= 1;
                                num_spitd_upd <= num_spitd_upd  + 1;
                            end
                        end
                    end
                    ADDR_SPIRD[7:2]: ; // read only for SPIRD
                    ADDR_CSMODE0[7:2]:
                    begin
                        csmodex <= S_WDATA;
                        cs_idx <= 0;
                        csmodex_updated <= 1;
                    end
                    ADDR_CSMODE1[7:2]:
                        if (NCS > 1) begin
                            csmodex <= S_WDATA;
                            cs_idx <= 1;
                            csmodex_updated <= 1;
                        end
                    ADDR_CSMODE2[7:2]:
                        if (NCS > 2) begin
                            csmodex <= S_WDATA;
                            cs_idx <= 2;
                            csmodex_updated <= 1;
                        end
                    ADDR_CSMODE3[7:2]:
                        if (NCS > 3) begin
                            cs_idx <= 3;
                            csmodex <= S_WDATA;
                            csmodex_updated <= 1;
                        end
                    default : ;
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
    .CPOL(CSMODE[CSMODE_CPOL]),           // clock polarity
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
        ADDR_SPITD  : reg_data_out <= SPITD;
        ADDR_SPIRD  : reg_data_out <= /* RNE ? SPIRD : 0 */ SPIRD;
        ADDR_CSMODE0: 
            reg_data_out <= CSMODE;
        ADDR_CSMODE1:
            if (NCS > 1)
                reg_data_out <= CSMODE;
            else
                reg_data_out <= 0;
        ADDR_CSMODE2:
            if (NCS > 2)
                reg_data_out <= CSMODE;
            else
                reg_data_out <= 0;
        ADDR_CSMODE3:
            if (NCS > 3)
                reg_data_out <= CSMODE;
            else begin
                reg_data_out <= 0;
            end
        default     : reg_data_out <= 0;
    endcase
end

endmodule

