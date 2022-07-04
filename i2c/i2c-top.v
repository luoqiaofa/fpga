`include "timescale.v"

module i2c_top_module(
    input                i_sysclk,  // system clock input
    input                i_reset_n, // module reset input
    input                i_wr_ena,  // write enable
    input       [5:0]    i_wr_addr, // write address
    input       [7:0]    i_wr_data, // write date input
    input                i_rd_ena,  // read enable input
    input       [5:0]    i_rd_addr, // read address input
    output wire [7:0]    o_rd_data, // read date output
    output               o_interrupt, // data ready to read
    inout                scl_pin,   // scl pad pin
    inout                sda_pin    // sda pad pin
);
`include "i2c-def.v"
`include "i2c-reg-def.v"

reg [7:0] I2CADR;
reg [7:0] I2CFDR;
reg [7:0] I2CCR;
reg [7:0] I2CSR;
reg [7:0] I2CDR;
reg [7:0] I2CDFSRR;
reg [7:0] s_data_out;
reg s_cmd_go;
reg go_read;
reg go_write;
reg s_start_done;
reg s_dr_updated;
reg s_need_rd_seq;
wire s_interrupt;

reg [3:0] i2c_state;

wire s_sda;
wire o_sda;
wire s_sda_oen;
wire s_scl;
wire o_scl;
wire s_scl_oen;

assign s_interrupt = I2CSR[CSR_MIF] | I2CSR[CSR_MAL];
assign o_interrupt = I2CCR[CCR_MIEN] ? s_interrupt : 0;
assign o_rd_data = s_data_out;

pullup scl_pu(scl_pin);
pullup sda_pu(sda_pin);

iobuf sda(
    .T  (s_sda_oen),
    .IO (sda_pin),
    .I  (o_sda),
    .O  (s_sda)
);

iobuf scl(
    .T  (s_scl_oen),
    .IO (scl_pin),
    .I  (o_scl),
    .O  (s_scl)
);

reg [15:0] s_prescale; // clock prescale cnt
reg [3:0]  s_cmd;

wire s_cmd_ack;
wire s_i2c_ack;
wire s_i2c_al;   // arbitration lost output
wire s_i2c_busy; // i2c bus busy output

// wire [7:0] i_data;
wire [7:0] s_rddata;
wire s_cmd_trig;

assign s_cmd_trig = s_cmd_go;

always @(posedge i_sysclk)
begin
    if (1'b0 == i_reset_n) begin
        I2CADR   <= 8'h00;
        I2CFDR   <= 8'h00;
        I2CCR    <= 8'h00;
        I2CSR    <= 8'h81;
        I2CDR    <= 8'h00;
        I2CDFSRR <= 8'h10;

        s_cmd_go <= 0;
        s_cmd <= CMD_IDLE;
        i2c_state <= SM_IDLE;
    end
    else begin
        if (1'b1 == i_rd_ena) begin
            case (i_rd_addr)
                ADDR_DR    : 
                begin
                    if (!s_need_rd_seq) begin
                        if (s_start_done) begin
                            if (I2CSR[CSR_MIF] & (!I2CCR[CCR_MTX])) begin
                                I2CSR[CSR_MIF] <= 1'b0;
                                I2CSR[CSR_MCF] <= 1'b0;
                                s_cmd        <= CMD_READ;
                                s_cmd_go     <= 1;
                                i2c_state    <= SM_READ;
                            end
                        end
                        else begin
                            if ((SM_RESTART == i2c_state) || (SM_START == i2c_state)) begin
                                s_need_rd_seq  <= 1;
                                I2CSR[CSR_MIF] <= 1'b0;
                                I2CSR[CSR_MCF] <= 1'b0;
                            end
                        end
                    end
                end
                default    :; 
            endcase
        end

        if (1'b1 == i_wr_ena) begin
            case (i_wr_addr)
                ADDR_ADR   : begin
                    I2CADR   <= i_wr_data;
                end
                ADDR_FDR   : begin
                    I2CFDR   <= i_wr_data;
                end
                ADDR_CR    : begin
                    I2CCR <= i_wr_data;
                end
                ADDR_SR    : begin
                    if (I2CSR[CSR_MAL]) begin
                        I2CSR[CSR_MAL] <= i_wr_data[CSR_MAL];
                    end
                    if (I2CSR[CSR_MIF]) begin
                        I2CSR[CSR_MIF] <= i_wr_data[CSR_MIF];
                    end
                end
                ADDR_DR    : begin
                    I2CDR  <= i_wr_data;
                end
                ADDR_DFSRR : I2CDFSRR <= i_wr_data;
                default    : I2CSR    <= I2CSR;
            endcase
        end
    end
    if (s_cmd_ack) begin
        case (i2c_state)
            SM_IDLE     : begin
                s_start_done  <= 0;
            end
            SM_START    : begin
                if (s_i2c_busy & ~s_i2c_al) begin
                    s_start_done   <= 1;
                end
            end
            SM_STOP     : begin
                s_cmd     <= CMD_IDLE;
                s_cmd_go  <= 1;
                i2c_state <= SM_IDLE;
                I2CSR[CSR_RXAK] <= 1;
                I2CSR[CSR_MIF] <= 0;
                s_start_done   <= 0;
            end
            SM_WRITE    : begin
                I2CSR[CSR_MCF] <= 1'b1;
                s_cmd     <= CMD_RD_ACK;
                s_cmd_go  <= 1;
                i2c_state <= SM_RD_ACK;
            end
            SM_READ     : begin
                I2CSR[CSR_MCF] <= 1'b1;
                I2CDR <= s_rddata;
                s_cmd_go  <= 1;
                if (I2CCR[CCR_TXAK]) begin
                    s_cmd     <= CMD_WR_NAK;
                    i2c_state <= SM_WR_NAK;
                end
                else begin
                    s_cmd     <= CMD_WR_ACK;
                    i2c_state <= SM_WR_ACK;
                end
            end
            SM_WR_ACK   : begin
                I2CSR[CSR_MIF] <= 1;
            end
            SM_WR_NAK   : begin
                I2CSR[CSR_MIF] <= 1;
            end
            SM_RD_ACK   : begin
                I2CSR[CSR_MIF] <= 1;
                I2CSR[CSR_RXAK] <= s_i2c_ack;
            end
            SM_RESTART  : begin
                if (s_i2c_busy & ~s_i2c_al) begin
                    s_start_done  <= 1;
                end
            end
            default     : ;
        endcase
    end
end

always @(*)
begin
    case (i_rd_addr)
        ADDR_ADR  : s_data_out <= I2CADR;
        ADDR_FDR  : s_data_out <= I2CFDR;     // register read data
        ADDR_CR   : s_data_out <= I2CCR;
        ADDR_SR   : s_data_out <= I2CSR;
        ADDR_DR   : s_data_out <= I2CDR;
        ADDR_DFSRR: s_data_out <= I2CDFSRR;
        default   : s_data_out <= 0;
    endcase
end

i2c_master_byte_ctl u1_byte_ctl(
    .i_sysclk   (i_sysclk),
    .i_nReset   (i_reset_n),        // sync reset
    .i_enable   (I2CCR[CCR_MEN]),   // iic enable
    .i_prescale (s_prescale),       // clock prescale cnt
    .i_dfsr     (I2CDFSRR[5:0]),    // Digital Filter Sampling Rate cnt
    .i_cmd_trig (s_cmd_trig),
    .i_cmd      (s_cmd),
    .o_cmd_ack  (s_cmd_ack),
    .o_i2c_ack  (s_i2c_ack),
    .o_i2c_al   (s_i2c_al),   // arbitration lost output
    .o_i2c_busy (s_i2c_busy), // i2c bus busy output
    .i_data     (I2CDR),
    .o_data     (s_rddata),
    .i_scl      (s_scl),
    .o_scl      (o_scl),
    .o_scl_oen  (s_scl_oen),
    .i_sda      (s_sda),
    .o_sda      (o_sda),
    .o_sda_oen  (s_sda_oen)
);

wire div_ready;
reg  div_ena;
reg  [15:0] divisor;

always @(posedge i_sysclk)
begin
    case (I2CFDR[5:0])
        8'h00 : s_prescale = 384;
        8'h01 : s_prescale = 416;
        8'h02 : s_prescale = 480;
        8'h03 : s_prescale = 576;
        8'h04 : s_prescale = 640;
        8'h05 : s_prescale = 704;
        8'h06 : s_prescale = 832;
        8'h07 : s_prescale = 1024;
        8'h08 : s_prescale = 1152;
        8'h09 : s_prescale = 1280;
        8'h0A : s_prescale = 1536;
        8'h0B : s_prescale = 1920;
        8'h0C : s_prescale = 2304;
        8'h0D : s_prescale = 2560;
        8'h0E : s_prescale = 3072;
        8'h0F : s_prescale = 3840;
        8'h10 : s_prescale = 4608;
        8'h11 : s_prescale = 5120;
        8'h12 : s_prescale = 6144;
        8'h13 : s_prescale = 7680;
        8'h14 : s_prescale = 9216;
        8'h15 : s_prescale = 10240;
        8'h16 : s_prescale = 12288;
        8'h17 : s_prescale = 15360;
        8'h18 : s_prescale = 18432;
        8'h19 : s_prescale = 20480;
        8'h1A : s_prescale = 24576;
        8'h1B : s_prescale = 30720;
        8'h1C : s_prescale = 36864;
        8'h1D : s_prescale = 40960;
        8'h1E : s_prescale = 49152;
        8'h1F : s_prescale = 61440;
        8'h20 : s_prescale = 256;
        8'h21 : s_prescale = 288;
        8'h22 : s_prescale = 320;
        8'h23 : s_prescale = 352;
        8'h24 : s_prescale = 384;
        8'h25 : s_prescale = 448;
        8'h26 : s_prescale = 512;
        8'h27 : s_prescale = 576;
        8'h28 : s_prescale = 640;
        8'h29 : s_prescale = 768;
        8'h2A : s_prescale = 896;
        8'h2B : s_prescale = 1024;
        8'h2C : s_prescale = 1280;
        8'h2D : s_prescale = 1536;
        8'h2E : s_prescale = 1792;
        8'h2F : s_prescale = 2048;
        8'h30 : s_prescale = 2560;
        8'h31 : s_prescale = 3072;
        8'h32 : s_prescale = 3584;
        8'h33 : s_prescale = 4096;
        8'h34 : s_prescale = 5120;
        8'h35 : s_prescale = 6144;
        8'h36 : s_prescale = 7168;
        8'h37 : s_prescale = 8192;
        8'h38 : s_prescale = 10240;
        8'h39 : s_prescale = 12288;
        8'h3A : s_prescale = 14336;
        8'h3B : s_prescale = 16384;
        8'h3C : s_prescale = 20480;
        8'h3D : s_prescale = 24576;
        8'h3E : s_prescale = 28672;
        8'h3F : s_prescale = 32768;
    endcase
end

endmodule
