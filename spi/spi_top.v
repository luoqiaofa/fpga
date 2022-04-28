`include "timescale.v"
module spi_intface # (parameter NCS = 4)
(
    input  wire S_SYSCLK,  // platform clock
    input  wire S_RESETN,  // reset
    input  wire [7:0] S_AWADDR,
    input  wire [31: 0] S_WDATA,
    input  wire [3 : 0] S_WSTRB,
    input  wire S_WVALID,
    input  wire S_AWVALID,
    output wire S_WREADY,
    output wire S_AWREADY,
    input  wire S_ARVALID,
    output wire S_ARREADY,
    input  wire [7 : 0]  S_ARADDR,
    output wire [31 : 0] S_RDATA,
    output wire S_RVALID,
    input  wire S_RREADY,
    input  wire S_BREADY,
    output wire S_BVALID,
    output wire [1 : 0] S_BRESP,
    output wire [1 : 0] S_RRESP,
    output wire S_INTERRUPT,
    inout  wire S_SPI_SCK,
    inout  wire S_SPI_MISO,
    inout  wire S_SPI_MOSI,
    inout  wire [NCS-1:0] S_SPI_SEL
);
`include "reg-bit-def.v"
`include "const.v"
localparam NBYTES_TXFIFO     = 1 << (NBITS_TXCNT - 1);
localparam NBYTES_RXFIFO     = 1 << (NBITS_RXCNT - 1);
localparam NWORD_TXFIFO      = NBYTES_TXFIFO / NBYTES_PER_WORD;
localparam NWORD_RXFIFO      = NBYTES_TXFIFO / NBYTES_PER_WORD;
localparam NBITS_WORD_TXFIFO = clogb2 (NWORD_TXFIFO);
localparam NBITS_WORD_RXFIFO = clogb2 (NWORD_RXFIFO);

reg [31: 0] SPMODE;
reg [31: 0] SPIE;
reg [31: 0] SPIM;
reg [31: 0] SPCOM;
wire [31: 0] SPITF;
reg [31: 0] SPIRF;
reg [31: 0] CSX_SPMODE[0:NCS-1];
reg [31: 0] SPI_TXFIFO[0:NWORD_TXFIFO-1];
reg [31: 0] SPI_RXFIFO[0:NWORD_RXFIFO-1];

integer idx;
reg spmodex_updated;
reg [31: 0]  spmode_x;
wire [31: 0] CSMODE;
wire [NBITS_PM-1:0]         CSMODE_PM;
wire [NBITS_CHARLEN-1:0]    CSMODE_LEN;
wire [NBITS_CSBEF-1:0]      CSMODE_CSBEF;
wire [NBITS_CSAFT-1:0]      CSMODE_CSAFT;
wire [NBITS_CSCG-1:0]       CSMODE_CSCG;
wire [NBITS_CS-1: 0]        SPCOM_CS;
wire [NBITS_TRANLEN-1:0]    SPCOM_RSKIP;
wire [NBITS_TRANLEN-1:0]    SPMODE_TXTHR;
wire [NBITS_TRANLEN-1:0]    SPMODE_RXTHR;
wire [NBITS_RXCNT-1:0]      SPIE_RXCNT;
wire [NBITS_TXCNT-1:0]      SPIE_TXCNT;
wire [NBITS_TRANLEN-1:0]    SPCOM_TRANLEN;

reg [NBITS_CSBEF-1:0]       cnt_csbef;
reg [NBITS_CSAFT-1:0]       cnt_csaft;
reg [NBITS_CSCG   :0]       cnt_cscg;
reg [NBITS_RSKIP-1:0]       cnt_rskip;
reg [NBITS_TXTHR-1:0]       cnt_txthr;
reg [NBITS_RXTHR-1:0]       cnt_rxthr;
reg [NBITS_RXCNT-1:0]       cnt_rxcnt;
reg [NBITS_TXCNT-1:0]       cnt_txcnt;
reg [NBITS_TRANLEN-1:0]     cnt_trans;

reg [NCS-1:0] spi_sel;

reg wvalid_pos_edge;
reg awvalid_pos_edge;
reg wready;
reg awready;
reg rrvalid;
reg arready;
reg	aw_en;
reg bvalid;
reg rvalid;
reg [1:0] rresp;
reg [1 : 0] bresp;
reg [31:0] rdata;
reg [31:0] reg_data_out;
reg [C_ADDR_WIDTH-1 : 0] awaddr;

/* spi transactions flags or counters begin */
reg frame_in_process;
reg chr_go;
reg chr_done;

localparam FRAME_SM_IDLE      = 0;
localparam FRAME_SM_BEF_WAIT  = 1;
localparam FRAME_SM_DATA_WAIT = 2;
localparam FRAME_SM_IN_TRANS  = 3;
localparam FRAME_SM_AFT_WAIT  = 4;
localparam FRAME_SM_CG_WAIT   = 5;
reg [2:0]  frame_state; // frame machine state;

reg [3:0] char_bit_cnt;
localparam MAX_BITNO_OF_CHAR = 4'hf;
/* spi transactions flags or counters end */

reg [15:0] data_tx;
reg [15:0] data_rx;
wire [15:0] shift_tx;

assign shift_tx = data_tx;

reg  brg_last_clk;
reg  spi_brg_go;
wire brg_clk;
wire brg_pos_edge;
wire brg_neg_edge;
localparam NBITS_BRG_DIVIDER = NBITS_PM + 4 + 2;
wire [NBITS_BRG_DIVIDER-1:0] csmode_pm;
wire [NBITS_BRG_DIVIDER-1:0] brg_divider;

wire [NBITS_TRANLEN-1:0] nbytes_to_spitf;
reg [NBITS_TRANLEN-1:0]  char_trx_idx;
wire [NBITS_TRANLEN-1:0] char_rx_idx; // count number of char from miso in master mode
// one word is 32 bit. half word is 16 bit
reg  [NBITS_TRANLEN-1:0] num_spitf_upd;
wire [NBITS_TRANLEN-1:0] num_spitf_trx;
wire TXE; // Tx FIFO empty flag;
wire TNF; // Tx FIFO full flag;
wire TXT; // Tx FIFO has less than TXTHR bytes, that is, at most TXTHR - 1 bytes

reg [1:0] cs_idx;
reg [NBITS_WORD_TXFIFO-1:0]  spitf_idx;
wire [NBITS_WORD_RXFIFO-1:0] spirf_wr_idx; // rx data to spirf(rx fifo)
reg [NBITS_WORD_RXFIFO-1:0]  spirf_char_idx; // char offset from miso to spirf(rx fifo)
reg [NBITS_WORD_RXFIFO-1:0]  spirf_rd_idx;
// if CSMODE_LEN > 7 spitf_trx_idx = char_trx_idx >> 1
// else (CSMODE_LEN <= 7) spitf_trx_idx >> 2
wire [NBITS_TXTHR-1:0] spitf_trx_idx;
//  char offset in spitf
wire [NBITS_TXTHR-1:0] spitf_trx_char_off;
wire [NBITS_TRANLEN-1:0] num_bytes_to_mosi;
wire [NBITS_TRANLEN-1:0] nbytes_need_tx;
wire [NBITS_TRANLEN-1:0] TXCNT;
assign SPITF = SPI_TXFIFO[spitf_trx_idx];
assign spitf_trx_idx = CSMODE_LEN > 7 ?  char_trx_idx[6:1] : char_trx_idx[7:2];
assign spitf_trx_char_off = CSMODE_LEN > 7 ? {5'b00, char_trx_idx[0]}:{4'h0, char_trx_idx[1:0]};
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
assign TXCNT = NBYTES_TXFIFO - nbytes_need_tx;
// assign TNF = TXCNT > 0 ? 1'b1: 1'b0;
assign TNF = TXCNT > (NBYTES_PER_WORD - 1) ? 1'b1 : 1'b0;
assign TXT = nbytes_need_tx < SPMODE_TXTHR ? 1'b1 : 1'b0;

assign char_rx_idx = char_trx_idx < SPCOM_RSKIP ? 0 : char_trx_idx - SPCOM_RSKIP;
wire   [NBITS_TRANLEN-1:0] nbytes_rx_from_miso;
wire   [NBITS_TRANLEN-1:0] nbytes_need_rd_in_rxfifo;
wire   [NBITS_TRANLEN-1:0] nbytes_valid_in_rxfifo;
wire   RNE;   // Not empty. Indicates that the Rx FIFO register contains a received character.
wire   RXT;   // Rx FIFO has more than RXTHR bytes, that is, at least RXTHR + 1 bytes
wire   RXF;   // Rx FIFO is full
wire   [NBITS_TRANLEN-1:0] RXCNT; // The current number of free Tx FIFO bytes
reg    [NBITS_TRANLEN-1:0] nbytes_read_from_spirf;
assign nbytes_rx_from_miso = CSMODE_LEN > 7 ? {char_rx_idx[NBITS_TRANLEN-1:1], 1'b0} : char_rx_idx;
assign nbytes_valid_in_rxfifo = nbytes_rx_from_miso - nbytes_read_from_spirf;
assign spirf_wr_idx = CSMODE_LEN > 7 ? spirf_char_idx >> 1 : spirf_char_idx >> 2;
assign RNE   = nbytes_valid_in_rxfifo > 0 ? 1'b1 : 1'b0;
assign RXF   = NBYTES_RXFIFO == nbytes_valid_in_rxfifo ? 1'b1 : 1'b0;
assign RXT   = nbytes_valid_in_rxfifo > SPMODE_RXTHR ? 1'b1 : 1'b0;
assign RXCNT = nbytes_valid_in_rxfifo;
wire   [31:0] SPIRF_WR;
assign SPIRF_WR = SPI_RXFIFO[spirf_wr_idx];

reg spcom_updated;
reg spitf_updated;
reg spirf_updated;

integer byte_index;

wire slv_reg_rden;
wire slv_reg_wren;

wire i_spi_mosi;
wire o_spi_mosi;
wire t_spi_mosi;

wire i_spi_miso;
wire o_spi_miso;
wire t_spi_miso;

wire i_spi_sck;
wire o_spi_sck;
wire t_spi_sck;

wire din;

assign t_spi_sck  = !SPMODE[SPMODE_MASTER];
assign t_spi_mosi = !SPMODE[SPMODE_MASTER];
assign t_spi_miso =  SPMODE[SPMODE_MASTER];
assign o_spi_sck  = (FRAME_SM_IN_TRANS == frame_state) ? brg_clk : CSMODE[CSMODE_CPOL];
assign o_spi_mosi = shift_tx[char_bit_cnt];

assign din = SPMODE[SPMODE_LOOP] ? o_spi_mosi : i_spi_miso;

wire [NCS-1:0] i_spi_sel;
wire [NCS-1:0] o_spi_sel;
wire [NCS-1:0] t_spi_sel;

iobuf ioc_spi_sck(
    .T(t_spi_sck),
    .IO(S_SPI_SCK),
    .I(o_spi_sck),
    .O(i_spi_sck)
);

iobuf ioc_spi_miso(
    .T(t_spi_miso),
    .IO(S_SPI_MISO),
    .I(o_spi_miso),
    .O(i_spi_miso)
);

iobuf ioc_spi_mosi(
    .T(t_spi_mosi),
    .IO(S_SPI_MOSI),
    .I(o_spi_mosi),
    .O(i_spi_mosi)
);

iosbuf #(.NUM_IO(NCS))iocs_spi_cs(
    .Ts(t_spi_sel),
    .IOs(S_SPI_SEL),
    .Is(o_spi_sel),
    .Os(i_spi_sel)
);

assign S_INTERRUPT = | (SPIM & SPIE);
assign o_spi_sel = spi_sel;
genvar var_cs;
generate for (var_cs = 0; var_cs < NCS; var_cs = var_cs + 1)
begin : gen_spi_cs
    assign t_spi_sel[var_cs] = !SPMODE[SPMODE_MASTER];
end
endgenerate

assign SPCOM_CS     = SPCOM[SPCOM_CS_HI: SPCOM_CS_LO];
assign SPCOM_RSKIP  = {{(NBITS_TRANLEN-NBITS_RSKIP){1'b0}}, SPCOM[SPCOM_RSKIP_HI:SPCOM_RSKIP_LO]};
assign SPCOM_TRANLEN= SPCOM[SPCOM_TRANLEN_HI:SPCOM_TRANLEN_LO];

assign SPMODE_TXTHR = {{(NBITS_TRANLEN-NBITS_TXTHR){1'b0}},SPCOM[SPMODE_TXTHR_HI:SPMODE_TXTHR_LO]};
assign SPMODE_RXTHR = {{(NBITS_TRANLEN-NBITS_RXTHR){1'b0}},SPCOM[SPMODE_RXTHR_HI:SPMODE_RXTHR_LO]};
assign SPIE_RXCNT   = SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO];
assign SPIE_TXCNT   = SPIE[SPIE_TXCNT_HI:SPIE_TXCNT_LO];

assign CSMODE       = CSX_SPMODE[SPCOM_CS];
assign CSMODE_LEN   = CSMODE[CSMODE_LEN_HI  : CSMODE_LEN_LO];
assign CSMODE_PM    = CSMODE[CSMODE_PM_HI   : CSMODE_PM_LO];
assign CSMODE_CSBEF = CSMODE[CSMODE_CSBEF_HI: CSMODE_CSBEF_LO];
assign CSMODE_CSAFT = CSMODE[CSMODE_CSAFT_HI: CSMODE_CSAFT_LO];
assign CSMODE_CSCG  = CSMODE[CSMODE_CSCG_HI : CSMODE_CSCG_LO];

assign csmode_pm   = {{(NBITS_BRG_DIVIDER-NBITS_PM){1'b0}}, CSMODE_PM} + 1;
assign brg_divider = CSMODE[CSMODE_DIV16] ? (csmode_pm << 4)-1 : csmode_pm-1;
// assign brg_divider = {{(NBITS_BRG_DIVIDER-4){1'b0}}, 4'h3};

assign S_AWREADY = awready;
assign S_WREADY  = wready;
assign S_BRESP   = bresp;
assign S_BVALID  = bvalid;
assign S_ARREADY = arready;
assign S_RDATA   = rdata;
assign S_RRESP   = rresp;
assign S_RVALID  = rvalid;

assign slv_reg_wren = wready && S_WVALID && awready && S_AWVALID & wvalid_pos_edge & awvalid_pos_edge;
assign slv_reg_rden = arready & S_ARVALID & ~rvalid;

always @(posedge S_WVALID or negedge S_RESETN)
begin
    if (!S_RESETN)
    begin
        wvalid_pos_edge <= 0;
    end
    else begin
        wvalid_pos_edge <= 1;
    end
end
always @(posedge S_AWVALID or negedge S_RESETN)
begin
    if (!S_RESETN)
    begin
        awvalid_pos_edge <= 0;
    end
    else begin
        awvalid_pos_edge <= 1;
    end
end

always @(negedge chr_go)
begin
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

always @(posedge chr_done)
begin
    if (CSMODE[CSMODE_CPHA]) begin
        if (CSMODE_LEN > 7) begin // occupy two bytes(16 bit)
            if (spirf_char_idx[0]) begin
                SPIRF <= SPIRF_WR[15:0];
                if (CSMODE[CSMODE_REV]) begin
                    SPIRF[31:16] <= {data_rx[15:1], din};
                end
                else begin
                    SPIRF[CSMODE_LEN + 16] <= din;
                    for(idx = 0; idx < 16; idx = idx + 1) begin
                        if (idx < CSMODE_LEN) begin
                            SPIRF[idx + 16] <= data_rx[idx];
                        end
                    end
                end
            end
            else begin
                SPIRF[31:16] <= 16'h0000;
                if (CSMODE[CSMODE_REV]) begin
                    SPIRF[15:0] <= {data_rx[15:1], din};
                end
                else begin
                    SPIRF[CSMODE_LEN] <= din;
                    for(idx = 0; idx < 16; idx = idx + 1) begin
                        if (idx < CSMODE_LEN) begin
                            SPIRF[idx] <= data_rx[idx];
                        end
                    end
                end
            end
        end
        else begin // occupy two bytes(8 bit)
            if (CSMODE[CSMODE_REV]) begin
                case(spirf_char_idx[1:0])
                    0 :
                    begin
                        SPIRF[31:8] <= 24'h000000;
                        SPIRF[7:0]  <= {data_rx[7:1], din};
                    end
                    1 :
                    begin
                        SPIRF[7:0]   <= SPIRF_WR[7:0];
                        SPIRF[15:8]  <= {data_rx[7:1], din};
                        SPIRF[31:16] <= 16'h0000;
                    end
                    2 :
                    begin
                        SPIRF[15:0]  <= SPIRF_WR[15:0];
                        SPIRF[23:16] <= {data_rx[7:1], din};
                        SPIRF[31:24] <= 8'h00;
                    end
                    3 :
                    begin
                        SPIRF[23:0]  <= SPIRF_WR[24:0];
                        SPIRF[31:24] <= {data_rx[7:1], din};
                    end
                endcase
            end
            else begin /* CSMODE_REV = 0 */
                case(spirf_char_idx[1:0])
                    0 :
                    begin
                        SPIRF[31:8] <= 24'h000000;
                        SPIRF[CSMODE_LEN] <= din;
                        for (idx = 0; idx < 8; idx = idx + 1) begin
                            SPIRF[idx] <= din;
                        end
                    end
                    1 :
                    begin
                        SPIRF[7:0]   <= SPIRF_WR[7:0];
                        SPIRF[31:16] <= 16'h0000;
                        SPIRF[8+CSMODE_LEN] <= din;
                        for (idx = 0; idx < 8; idx = idx + 1) begin
                            SPIRF[8+idx] <= din;
                        end
                    end
                    2 :
                    begin
                        SPIRF[15:0]  <= SPIRF_WR[15:0];
                        SPIRF[16+CSMODE_LEN] <= din;
                        for (idx = 0; idx < 8; idx = idx + 1) begin
                            SPIRF[16+idx] <= din;
                        end
                        SPIRF[31:24] <= 8'h00;
                    end
                    3 :
                    begin
                        SPIRF[23:0]  <= SPIRF_WR[24:0];
                        SPIRF[24+CSMODE_LEN] <= din;
                        for (idx = 0; idx < 8; idx = idx + 1) begin
                            SPIRF[24+idx] <= din;
                        end
                    end
                endcase
            end
        end
    end
    else begin /* CP=0 full char received from din */
        if (CSMODE_LEN > 7) begin
            if (spirf_char_idx[0]) begin
                SPIRF[15:0]  <= SPIRF_WR[15:0];
                SPIRF[31:16] <= data_rx;
            end
            else begin
                SPIRF[31:16] <= 16'h0000;
                SPIRF[15:0]  <= data_rx;
            end
        end
        else begin
            case(spirf_char_idx[1:0])
                0 :
                begin
                    SPIRF[31:8] <= 24'h000000;
                    SPIRF[7:0]  <= data_rx[7:0];
                end
                1 :
                begin
                    SPIRF[7:0]   <= SPIRF_WR[7:0];
                    SPIRF[15:8]  <= data_rx[7:0];
                    SPIRF[31:16] <= 16'h0000;
                end
                2 :
                begin
                    SPIRF[15:0]  <= SPIRF_WR[15:0];
                    SPIRF[23:16] <= data_rx[7:0];
                    SPIRF[31:24] <= 8'h00;
                end
                3 :
                begin
                    SPIRF[23:0]  <= SPIRF_WR[24:0];
                    SPIRF[31:24] <= data_rx[7:0];
                end
            endcase
        end
    end
end

always @(negedge chr_done)
begin
    if (char_rx_idx > 0) begin
        SPI_RXFIFO[spirf_wr_idx] <= SPIRF;
        spirf_char_idx <= spirf_char_idx + 1;
    end
    else begin
        spirf_char_idx <= 0;
    end
end

always @(negedge chr_done)
begin
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

wire brg_out_second_edge;
assign brg_out_second_edge = CSMODE[CSMODE_CPOL] ? brg_pos_edge: brg_neg_edge;
always @(negedge brg_out_second_edge)
begin
    if (CSMODE[CSMODE_CPHA])
    begin
        if (FRAME_SM_IN_TRANS == frame_state) begin
            data_rx[char_bit_cnt] <= din;
            if (CSMODE[CSMODE_REV]) begin
                if (0 == char_bit_cnt) begin
                    chr_done <= 1;
                    char_trx_idx <= char_trx_idx + 1;
                    if (char_trx_idx == SPCOM_TRANLEN) begin
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
                        // char_trx_idx <= 0;
                        frame_state <= FRAME_SM_AFT_WAIT;
                    end
                    else begin
                        chr_go <= 1;
                    end
                end
            end
        end
    end
    else begin /* (!CSMODE[CSMODE_CPHA]) */
        if (FRAME_SM_IN_TRANS == frame_state) begin
            if (CSMODE[CSMODE_REV]) begin
                char_bit_cnt <= char_bit_cnt - 1;
                if (0 == char_bit_cnt) begin
                    chr_done <= 1;
                    char_bit_cnt <= CSMODE_LEN;
                    char_trx_idx <= char_trx_idx + 1;
                    if (char_trx_idx == SPCOM_TRANLEN) begin
                        char_trx_idx <= 0;
                        frame_state <= FRAME_SM_AFT_WAIT;
                    end
                end
            end
            else begin
                char_bit_cnt <= char_bit_cnt + 1;
                if (CSMODE_LEN == char_bit_cnt) begin
                    chr_done <= 1;
                    char_bit_cnt <= 0;
                    char_trx_idx <= char_trx_idx + 1;
                    if (char_trx_idx == SPCOM_TRANLEN) begin
                        char_trx_idx <= 0;
                        frame_state <= FRAME_SM_AFT_WAIT;
                    end
                end
            end
        end
    end
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
                    frame_state <= FRAME_SM_IN_TRANS;
                    chr_go <= 1;
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
                frame_in_process <= 0;
                SPIE[SPIE_DON] = 1'b1;
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
                cnt_cscg <= CSMODE_CSCG;
                if (frame_in_process) begin
                    frame_state <= FRAME_SM_BEF_WAIT;
                end
                else begin
                    frame_state <= FRAME_SM_IDLE;
                end
            end
        end
        default:;
    endcase
end

wire brg_out_first_edge;
assign brg_out_first_edge = CSMODE[CSMODE_CPOL] ? brg_neg_edge : brg_pos_edge;
always @(negedge brg_out_first_edge)
begin
    if (CSMODE[CSMODE_CPHA])
    begin
        if (FRAME_SM_IN_TRANS == frame_state) begin
            if (CSMODE[CSMODE_REV]) begin
                char_bit_cnt <= char_bit_cnt - 1;
            end
            else begin
                char_bit_cnt <= char_bit_cnt + 1;
            end
        end
    end
    else begin
        if (FRAME_SM_IN_TRANS == frame_state) begin
            data_rx[char_bit_cnt] <= din;
        end
    end
end

always @(posedge frame_in_process)
begin
    char_trx_idx <= 0;
    spitf_idx <= 0;
    num_spitf_upd <= 0;

    spi_sel[SPCOM_CS] <= CSMODE[CSMODE_POL] ? 1'b0 : 1'b1;
    if (CSMODE_CSBEF > 0) begin
        cnt_csbef <= CSMODE_CSBEF - 1;
    end
    else begin
        cnt_csbef <= CSMODE_CSBEF;
    end
    cnt_csaft <= CSMODE_CSAFT;
    // if (CSMODE_CSAFT > 0) begin
    //     cnt_csaft <= CSMODE_CSAFT - 1;
    // end
    // else begin
    //     cnt_csaft <= CSMODE_CSAFT;
    // end
    if (&cnt_cscg) begin
        frame_state <= FRAME_SM_CG_WAIT;
    end
    else begin
        cnt_cscg  <= CSMODE_CSCG;
        frame_state <= FRAME_SM_BEF_WAIT;
    end
end

// counter processing
always @(posedge S_SYSCLK or negedge S_RESETN)
begin
    if (!S_RESETN || (!SPMODE[SPMODE_EN])) begin
        cnt_csbef <= 0;
        cnt_csaft <= 0;
        cnt_cscg  <= 0;
        cnt_rskip <= 0;
        cnt_txthr <= 0;
        cnt_rxthr <= 0;
        cnt_rxcnt <= 0;
        cnt_txcnt <= 0;
        cnt_trans <= 0;

        spcom_updated <= 0;
        spitf_updated <= 0;
        spirf_updated <= 0;
        spitf_idx <= 0;
        spirf_rd_idx <= 0;

        char_trx_idx <= 0;
        num_spitf_upd <= 0;

        spirf_rd_idx <= 0;
        spirf_char_idx <= 0;
        nbytes_read_from_spirf <= 0;
    end
    else begin
        chr_go <= 0;
        chr_done <= 0;

        spcom_updated <= 0;
        spitf_updated <= 0;
        spirf_updated <= 0;
    end
end

always @(negedge spcom_updated)
begin
    if (SPMODE[SPMODE_EN]) begin
        spi_brg_go <= 1;
        frame_in_process <= 1;
        if (|cnt_cscg) begin
            frame_state <= FRAME_SM_CG_WAIT;
        end
        else begin
            frame_state <= FRAME_SM_BEF_WAIT;
        end
    end
    else begin
        frame_state <= FRAME_SM_IDLE;
    end
end

always @(negedge spitf_updated)
begin
    if (!frame_in_process) begin
        char_trx_idx   <= 0;
    end
end

always @(negedge SPMODE[SPMODE_EN] or negedge S_RESETN)
begin
    if (!S_RESETN) begin
        brg_last_clk <= 0;
    end
    else begin
        brg_last_clk <= 1;
    end
end

always @(posedge S_SYSCLK or negedge S_RESETN)
begin
    if (!S_RESETN)
    begin
        rrvalid <= 0;
        arready <= 0;
        rresp   <= 2'b00;
        reg_data_out <= 0;
        cs_idx <= 0;
        data_tx <= 17'h00000;
        data_rx <= 17'h00000;
        chr_go <= 0;
        chr_done <= 0;
        spi_brg_go <= 0;
        char_bit_cnt <= 0;
        frame_in_process <= 0;
        frame_state <= FRAME_SM_IDLE;

        for (byte_index = 0; byte_index < NWORD_TXFIFO; byte_index = byte_index + 1)
        begin
            SPI_TXFIFO[byte_index] <= 0;
        end
        for (byte_index = 0; byte_index < NWORD_TXFIFO; byte_index = byte_index + 1)
        begin
            SPI_RXFIFO[byte_index] <= 0;
        end

    end
    else begin
        if (CSMODE_LEN > 7) begin
            if (spitf_trx_char_off) begin
                data_tx <= SPITF[31:16];
            end
            else begin
                data_tx <= SPITF[15:0];
            end
        end
        else begin
            case (spitf_trx_char_off)
                0: data_tx <= {8'h00, SPITF[7:0]};
                1: data_tx <= {8'h00, SPITF[15:8]};
                2: data_tx <= {8'h00, SPITF[23:16]};
                3: data_tx <= {8'h00, SPITF[31:24]};
                default :;
            endcase
        end
    end
end

always @( posedge S_SYSCLK or negedge S_RESETN)
begin
    if (S_RESETN == 1'b0 )
    begin
        byte_index <= 0;
        SPMODE  <= SPMODE_DEF;
        SPIE    <= SPIE_DEF;
        SPIM    <= SPIM_DEF;
        SPCOM   <= SPCOM_DEF;
        SPIRF   <= SPIRF_DEF;
        for (idx = 0; idx < NCS; idx = idx + 1) begin
            CSX_SPMODE[idx] <= CSMODE_DEF;
        end
        cs_idx <= 0;
        spmode_x <= CSMODE_DEF;
        spmodex_updated <= 0;
        spi_sel <= {NCS{1'b1}};
    end
    else begin
        if (spmodex_updated) begin
            spmodex_updated <= 0;
            CSX_SPMODE[cs_idx] <= spmode_x;
        end
        if (slv_reg_wren) begin
            wvalid_pos_edge <= 0;
            awvalid_pos_edge <= 0;
            if (S_WSTRB == {4{1'b1}}) begin /* only support 32bits write */
                case (awaddr[7:2])
                    ADDR_SPMODE : SPMODE[31:0] <= S_WDATA;
                ADDR_SPIE[7:2]:
                    for (idx = SPIE_TXT; idx <= SPIE_TXE; idx = idx + 1) begin
                        if (S_WDATA[idx]) begin
                            SPIE[idx] <= 1'b0;
                        end
                    end
                ADDR_SPIM[7:2]: SPIM <= S_WDATA;
                ADDR_SPCOM[7:2]:
                begin
                    if (!frame_in_process) begin
                        SPCOM <= S_WDATA;
                        spcom_updated <= 1;
                        if (SPMODE[SPMODE_EN]) begin
                            if (SPCOM_CS != S_WDATA[SPCOM_CS_HI:SPCOM_CS_LO]) begin
                                spi_brg_go <= 0;
                            end
                        end
                    end
                end
                ADDR_SPITF[7:2]:
                begin
                    // if (TNF)
                    begin
                        spitf_updated <= 1;
                        SPI_TXFIFO[spitf_idx] <= S_WDATA;
                        spitf_idx <= spitf_idx + 1;
                        num_spitf_upd <= num_spitf_upd  + 1;
                    end
                end
                ADDR_SPIRF[7:2]: ; // read only for SPIRF
                ADDR_SPMODE0[7:2], ADDR_SPMODE0[7:2], ADDR_SPMODE2[7:2], ADDR_SPMODE3[7:2]:
                begin
                    cs_idx <= awaddr[7:2] - ADDR_SPMODE0[7:2];
                    spmode_x <= S_WDATA;
                    spmodex_updated <= 1;
                end
                default : begin
                end
            endcase
        end
        end
    end
end

always @( posedge S_SYSCLK )
begin
    if (S_RESETN == 1'b0 )
    begin
        awaddr <= 0;
        aw_en  <= 1;
    end
    else begin
        if (~awready && S_AWVALID && S_WVALID && aw_en)
        begin
            // Write Address latching
            awaddr <= S_AWADDR;
        end
    end
end

always @( posedge S_SYSCLK)
begin
    if (S_RESETN == 1'b0 )
    begin
        wready <= 1'b1;
    end
    else begin
        if (~wready && S_WVALID && S_AWVALID && aw_en)
        begin
            // slave is ready to accept write data when
            // there is a valid write address and write data
            // on the write address and data bus. This design
            // expects no outstanding transactions.
            wready <= 1'b1;
        end
        else begin
            wready <= 1'b0;
        end
    end
end

always @( posedge S_SYSCLK )
begin
    if (S_RESETN == 1'b0 )
    begin
        awready <= 1'b0;
        aw_en <= 1'b1;
    end
    else begin
        if (~awready && S_AWVALID && S_WVALID && aw_en)
        begin
            // slave is ready to accept write address when
            // there is a valid write address and write data
            // on the write address and data bus. This design
            // expects no outstanding transactions.
            awready <= 1'b1;
            aw_en <= 1'b0;
        end
        else if (S_BREADY && bvalid)
        begin
            aw_en <= 1'b1;
            awready <= 1'b0;
        end
        else begin
            awready <= 1'b0;
        end
    end
end

always @( posedge S_SYSCLK)
begin
    if (S_RESETN == 1'b0 )
    begin
        bvalid  <= 0;
        bresp   <= 2'b0;
    end
    else
    begin
    if (awready && S_AWVALID && ~bvalid && wready && S_WVALID)
    begin
        // indicates a valid write response is available
        bvalid <= 1'b1;
        bresp  <= 2'b0; // 'OKAY' response
    end                   // work error responses in future
    else
    begin
        if (S_BREADY && bvalid)
            //check if bready is asserted while bvalid is high)
                //(there is a possibility that bready is always asserted high)
            begin
                bvalid <= 1'b0;
            end
        end
    end
end

always @( posedge S_SYSCLK)
begin
    if ( S_RESETN == 1'b0)
    begin
        rvalid <= 0;
        rresp  <= 0;
    end
    else begin
        if (arready && S_ARVALID && ~rvalid)
        begin
            // Valid read data is available at the read data bus
            rvalid <= 1'b1;
            rresp  <= 2'b0; // 'OKAY' response
        end
        else if (rvalid && S_RREADY)
        begin
            // Read data is accepted by the master
            rvalid <= 1'b0;
        end
    end
end

// Output register or memory read data
always @( posedge S_SYSCLK )
begin
    if (S_RESETN == 1'b0 )
    begin
        rdata  <= 0;
    end
    else
    begin
        // When there is a valid read address (S_ARVALID) with
        // acceptance of read address by the slave (arready),
        // output the read dada
        if (slv_reg_rden)
        begin
            rdata <= reg_data_out;     // register read data
        end
    end
end

spi_clk_gen # (.C_DIVIDER_WIDTH(NBITS_BRG_DIVIDER)) spi_brg (
    .sysclk(S_SYSCLK),           // system clock input
    .rst_n(S_RESETN),            // module reset
    .enable(SPMODE[SPMODE_EN]),  // module enable
    .go(spi_brg_go),                 // start transmit
    .CPOL(CSMODE[CSMODE_CPOL]),           // clock polarity
    .last_clk(brg_last_clk),     // last clock
    .divider_i(brg_divider),     // divider;
    .clk_out(brg_clk),           // clock output
    .pos_edge(brg_pos_edge),     // positive edge flag
    .neg_edge(brg_neg_edge)      // negtive edge flag
);

endmodule

