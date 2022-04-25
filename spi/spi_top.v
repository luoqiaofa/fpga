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
localparam NUM_TX_FIFO = 32;
localparam NUM_RX_FIFO = 32;

reg [31: 0] SPMODE;
reg [31: 0] SPIE;
reg [31: 0] SPIM;
reg [31: 0] SPCOM;
wire [31: 0] SPITF;
reg [31: 0] SPIRF;
reg [31: 0] CSX_SPMODE[0:NCS-1];
reg [31: 0] SPI_TXFIFO[0:NUM_TX_FIFO-1];
reg [31: 0] SPI_RXFIFO[0:NUM_RX_FIFO-1];

integer idx;
reg spmodex_updated;
reg [31: 0]  spmode_x;
wire [31: 0] CSMODE;
wire [CSMODE_PM_HI  - CSMODE_PM_LO  :0]    CSMODE_PM;
wire [CSMODE_LEN_HI - CSMODE_LEN_LO :0]    CSMODE_LEN;
wire [CSMODE_CSBEF_HI-CSMODE_CSBEF_LO:0]   CSMODE_CSBEF;
wire [CSMODE_CSAFT_HI-CSMODE_CSAFT_LO:0]   CSMODE_CSAFT;
wire [CSMODE_CSCG_HI -CSMODE_CSCG_LO :0]   CSMODE_CSCG;
wire [SPCOM_CS_HI-SPCOM_CS_LO : 0]         SPCOM_CS;
wire [SPCOM_RSKIP_HI-SPCOM_RSKIP_LO:0]     SPCOM_RSKIP;
wire [SPMODE_TXTHR_HI-SPMODE_TXTHR_LO:0]   SPMODE_TXTHR;
wire [SPMODE_RXTHR_HI-SPMODE_RXTHR_LO:0]   SPMODE_RXTHR;
wire [SPIE_RXCNT_HI-SPIE_RXCNT_LO:0]       SPIE_RXCNT;
wire [SPIE_TXCNT_HI-SPIE_TXCNT_LO:0]       SPIE_TXCNT;
wire [SPCOM_TRANLEN_HI-SPCOM_TRANLEN_LO:0] SPCOM_TRANLEN;

reg [CSMODE_CSBEF_HI-CSMODE_CSBEF_LO:0]   cnt_csbef;
reg [CSMODE_CSAFT_HI-CSMODE_CSAFT_LO:0]   cnt_csaft;
reg [CSMODE_CSCG_HI -CSMODE_CSCG_LO+1:0]  cnt_cscg;
reg [SPCOM_RSKIP_HI-SPCOM_RSKIP_LO:0]     cnt_rskip;
reg [SPMODE_TXTHR_HI-SPMODE_TXTHR_LO:0]   cnt_txthr;
reg [SPMODE_RXTHR_HI-SPMODE_RXTHR_LO:0]   cnt_rxthr;
reg [SPIE_RXCNT_HI-SPIE_RXCNT_LO:0]       cnt_rxcnt;
reg [SPIE_TXCNT_HI-SPIE_TXCNT_LO:0]       cnt_txcnt;
reg [SPCOM_TRANLEN_HI-SPCOM_TRANLEN_LO:0] cnt_trans;

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
reg chr_skip_calc;

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
wire [4:0] csmode_pm;
wire [9:0] brg_divider;

reg [SPCOM_TRANLEN_HI-SPCOM_TRANLEN_LO:0] num_trx_char;
reg [SPCOM_TRANLEN_HI-SPCOM_TRANLEN_LO:0] char_trx_idx;

reg [1:0] cs_idx;
reg [SPMODE_TXTHR_HI-SPMODE_TXTHR_LO + 1:0] spitf_idx;
// if CSMODE_LEN > 7 spitf_trx_idx = char_trx_idx >> 1 
// else (CSMODE_LEN <= 7) spitf_trx_idx >> 2
wire [SPMODE_TXTHR_HI-SPMODE_TXTHR_LO + 1:0] spitf_trx_idx;
//  char offset in spitf
wire [SPMODE_TXTHR_HI-SPMODE_TXTHR_LO + 1:0] spitf_trx_char_off;

assign spitf_trx_idx = CSMODE_LEN > 7 ? char_trx_idx[7:1] : char_trx_idx[8:2];
assign spitf_trx_char_off = CSMODE_LEN > 7 ? {6'h00, char_trx_idx[0]}:{5'h00, char_trx_idx[1:0]};
assign SPITF = SPI_TXFIFO[spitf_trx_idx];

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
wire t_spi_miso_oen;

wire i_spi_sck;
wire o_spi_sck;
wire t_spi_sck;

assign t_spi_sck  = !SPMODE[SPMODE_MASTER];
assign t_spi_mosi = !SPMODE[SPMODE_MASTER];
assign t_spi_miso =  SPMODE[SPMODE_MASTER];
assign o_spi_sck  = (FRAME_SM_IN_TRANS == frame_state) ? brg_clk : CSMODE[CSMODE_CPOL];
assign o_spi_mosi = shift_tx[char_bit_cnt];

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
assign SPCOM_RSKIP  = SPCOM[SPCOM_RSKIP_HI:SPCOM_RSKIP_LO];
assign SPCOM_TRANLEN= SPCOM[SPCOM_TRANLEN_HI:SPCOM_TRANLEN_LO];

assign SPMODE_TXTHR = SPCOM[SPMODE_TXTHR_HI:SPMODE_TXTHR_LO];
assign SPMODE_RXTHR = SPCOM[SPMODE_RXTHR_HI:SPMODE_RXTHR_LO];
assign SPIE_RXCNT   = SPIE[SPIE_RXCNT_HI:SPIE_RXCNT_LO];
assign SPIE_TXCNT   = SPIE[SPIE_TXCNT_HI:SPIE_TXCNT_LO];

assign CSMODE       = CSX_SPMODE[SPCOM_CS];
assign CSMODE_LEN   = CSMODE[CSMODE_LEN_HI  : CSMODE_LEN_LO];
assign CSMODE_PM    = CSMODE[CSMODE_PM_HI   : CSMODE_PM_LO];
assign CSMODE_CSBEF = CSMODE[CSMODE_CSBEF_HI: CSMODE_CSBEF_LO];
assign CSMODE_CSAFT = CSMODE[CSMODE_CSAFT_HI: CSMODE_CSAFT_LO];
assign CSMODE_CSCG  = CSMODE[CSMODE_CSCG_HI : CSMODE_CSCG_LO];

assign csmode_pm   = {1'b0, CSMODE_PM} + 1;
assign brg_divider = CSMODE[CSMODE_DIV16] ? {1'b0, csmode_pm, 4'h0}-1 : {4'h0, csmode_pm, 1'b0}-1;

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

always @(posedge chr_go)
begin
    if (CSMODE[CSMODE_CPHA]) begin
        if (CSMODE_LEN == MAX_BITNO_OF_CHAR) begin
            chr_skip_calc <= 1;
        end
        else begin
            chr_skip_calc <= 0;
        end
        if (CSMODE[CSMODE_REV]) begin
            char_bit_cnt <= CSMODE_LEN + 1;
        end
        else begin
            char_bit_cnt <= MAX_BITNO_OF_CHAR;
        end
    end
    else begin
        chr_skip_calc <= 0;
        if (CSMODE[CSMODE_REV]) begin
            char_bit_cnt <= CSMODE_LEN;
        end
        else begin
            char_bit_cnt <= 0;
        end
    end
end

wire brg_out_second_edge;
assign brg_out_second_edge = CSMODE[CSMODE_CPOL] ? brg_pos_edge: brg_neg_edge;
always @(negedge brg_out_second_edge)
begin
    if (!CSMODE[CSMODE_CPHA])
    begin
        if (FRAME_SM_IN_TRANS == frame_state) begin
            data_rx[char_bit_cnt] <= i_spi_miso;
            if (CSMODE[CSMODE_REV]) begin
                char_bit_cnt <= char_bit_cnt - 1;
                if (0 == char_bit_cnt) begin
                    if (chr_go) begin
                        chr_go <= 0;
                    end
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
                    if (chr_go) begin
                        chr_go <= 0;
                    end
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
                frame_state <= FRAME_SM_IN_TRANS;
                chr_go <= 1;
            end
        end
        FRAME_SM_DATA_WAIT:;
        FRAME_SM_IN_TRANS:;
        FRAME_SM_AFT_WAIT:
        begin
            if (cnt_csaft > 0) begin
                cnt_csaft <= cnt_csaft - 1;
            end
            else begin
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
            data_rx[char_bit_cnt] <= i_spi_miso;
            if (CSMODE[CSMODE_REV]) begin
                char_bit_cnt <= char_bit_cnt - 1;
                if (0 == char_bit_cnt) begin
                    if (chr_go) begin
                        chr_go <= 0;
                    end
                    chr_done <= 1;
                    if (chr_skip_calc) begin
                        chr_skip_calc <= 0;
                    end
                    else begin
                        char_trx_idx <= char_trx_idx + 1;
                    end
                    char_bit_cnt <= CSMODE_LEN;
                    if (char_trx_idx == SPCOM_TRANLEN) begin
                        char_trx_idx <= 0;
                        frame_state <= FRAME_SM_AFT_WAIT;
                    end
                end
            end
            else begin
                char_bit_cnt <= char_bit_cnt + 1;
                if (CSMODE_LEN == char_bit_cnt) begin
                    if (chr_go) begin
                        chr_go <= 0;
                    end
                    chr_done <= 1;
                    char_bit_cnt <= 0;
                    if (chr_skip_calc) begin
                        chr_skip_calc <= 0;
                    end
                    else begin
                        char_trx_idx <= char_trx_idx + 1;
                    end
                    if (char_trx_idx == SPCOM_TRANLEN) begin
                        char_trx_idx <= 0;
                        frame_state <= FRAME_SM_AFT_WAIT;
                    end
                end
            end
        end
    end
end

always @(posedge frame_in_process)
begin
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

        spitf_idx <= 0;
        char_trx_idx <= 0;
        num_trx_char <= 0;
    end
    else begin
        // chr_go <= 0;
        chr_done <= 0;
        spcom_updated <= 0;
        if (chr_done) begin
            chr_done <= 0;
        end
        if (spcom_updated) begin
            if (SPMODE[SPMODE_EN]) begin
                spi_brg_go <= 1;
                frame_in_process <= 1;
                if (&cnt_cscg) begin
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

        spitf_updated <= 0;
        if (spitf_updated) begin
            if (CSMODE_LEN > 7) begin
                num_trx_char <= {spitf_idx[15:0], 1'b0};
            end
            else begin
                num_trx_char <= {spitf_idx[14:0], 2'b00};
            end
            if (!frame_in_process) begin
                char_trx_idx   <= 0;
            end
        end
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
        chr_skip_calc <= 0;
        spi_brg_go <= 0;
        char_bit_cnt <= 0;
        frame_in_process <= 0;
        frame_state <= FRAME_SM_IDLE;

        spcom_updated <= 0;
        spitf_updated <= 0;
        spirf_updated <= 0;
        for (byte_index = 0; byte_index < NUM_TX_FIFO; byte_index = byte_index + 1) 
        begin
            SPI_TXFIFO[byte_index] <= 0;
        end
        for (byte_index = 0; byte_index < NUM_RX_FIFO; byte_index = byte_index + 1) 
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
                    SPCOM <= S_WDATA;
                    spcom_updated <= 1;
                    if (!frame_in_process & SPMODE[SPMODE_EN]) begin
                        if (SPCOM_CS != S_WDATA[SPCOM_CS_HI:SPCOM_CS_LO]) begin
                            spi_brg_go <= 0;
                        end
                    end
                end
                ADDR_SPITF[7:2]:
                begin
                    spitf_updated <= 1;
                    SPI_TXFIFO[spitf_idx] <= S_WDATA;
                    spitf_idx = spitf_idx + 1;

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

spi_clk_gen # (.C_DIVIDER_WIDTH(8)) spi_brg (
    .sysclk(S_SYSCLK),           // system clock input
    .rst_n(S_RESETN),            // module reset
    .enable(SPMODE[SPMODE_EN]),  // module enable
    .go(spi_brg_go),                 // start transmit
    .CPOL(CSMODE[CSMODE_CPOL]),           // clock polarity
    .last_clk(brg_last_clk),     // last clock
    .divider_i(brg_divider[7:0]),     // divider;
    .clk_out(brg_clk),           // clock output
    .pos_edge(brg_pos_edge),     // positive edge flag
    .neg_edge(brg_neg_edge)      // negtive edge flag
);

endmodule

