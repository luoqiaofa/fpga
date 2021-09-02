`include "timescale.v"

module i2c_top_module(
    input                i_sysclk,  // system clock input
    input                i_reset_n, // module reset input
    input                i_wr_ena,  // write enable
    input       [4:0]    i_wr_addr, // write address
    input       [7:0]    i_wr_data, // write date input
    input                i_rd_ena,  // read enable input
    input       [4:0]    i_rd_addr, // read address input
    output      [7:0]    o_rd_data, // read date output
    output               o_read_ready, // data ready to read
    output               o_write_ready, // data ready to read
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
reg rd_ready_r;
reg wr_ready_r;
reg s_start_done;
reg s_dr_updated;
reg s_need_rd_seq;
wire s_interrupt;
wire s_MIF;

reg [3:0] i2c_state;

wire s_sda;
wire o_sda;
wire s_sda_oen;
wire s_scl;
wire o_scl;
wire s_scl_oen;

assign  s_MIF = I2CSR[CSR_MIF];
assign s_interrupt = I2CSR[CSR_MIF] | I2CSR[CSR_MAL];
assign o_interrupt = I2CCR[CCR_MIEN] ? s_interrupt : 0;
assign o_rd_data = s_data_out;
assign o_read_ready = rd_ready_r;
assign o_write_ready = wr_ready_r;

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
wire s_write_enable;
wire s_read_enable;

assign s_cmd_trig = s_cmd_go;
assign s_write_enable = i_wr_ena;
assign s_read_enable  = i_rd_ena;

always @(posedge i_sysclk or posedge s_i2c_al or negedge i_reset_n)
begin
    if (i_reset_n) begin
        I2CSR[CSR_MAL] <= s_i2c_al;
    end
end

always @(posedge s_cmd_ack)
begin
    case (i2c_state)
        SM_IDLE     : begin
            s_start_done  <= 0;
        end
        SM_START    : begin
            s_start_done   <= 1;
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
            s_start_done   <= 1;
        end
        default     : ;
    endcase
end

always @(posedge s_write_enable or negedge i_reset_n)
begin
    if (i_reset_n) begin
        case (i_wr_addr[4:2])
            ADDR_ADR   : begin
                I2CADR   <= i_wr_data;
            end
            ADDR_FDR   : begin
                I2CFDR   <= i_wr_data;
            end
            ADDR_CR    : begin
                I2CCR <= i_wr_data;
                if (i_wr_data[CCR_RSTA]) begin
                    s_cmd        <= CMD_RESTART;
                    s_cmd_go     <= 1;
                    i2c_state    <= SM_RESTART;
                    s_start_done <= 0;
                end
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
                if (!s_dr_updated & I2CSR[CSR_MCF]) begin
                    I2CSR[CSR_MCF] <= 0;
                    I2CSR[CSR_MIF] <= 0;
                    I2CDR        <= i_wr_data;
                    s_dr_updated <= 1;
                end
            end
            ADDR_DFSRR : I2CDFSRR <= i_wr_data;
            default    : I2CSR    <= I2CSR;
        endcase
    end
end

always @(posedge s_read_enable or negedge i_reset_n)
begin
    if (i_reset_n) begin
        rd_ready_r <= 1'b0;
        case (i_rd_addr[4:2])
            ADDR_ADR   : begin
                s_data_out <= I2CADR  ;
            end
            ADDR_FDR   : begin
                s_data_out <= I2CFDR  ;
            end
            ADDR_CR    : begin
                s_data_out <= I2CCR   ;
            end
            ADDR_SR    : begin
                s_data_out <= I2CSR   ;
            end
            ADDR_DR    : begin
                s_data_out <= I2CDR   ;
                if (!s_need_rd_seq) begin
                    if (s_start_done) begin
                        if (I2CSR[CSR_MBB] & I2CSR[CSR_MIF] & (!I2CCR[CCR_MTX])) begin
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
            ADDR_DFSRR : begin
                s_data_out <= I2CDFSRR;
            end
            default    : begin
                s_data_out <= I2CSR   ;
            end
        endcase
    end
end

i2c_master_byte_ctl u1_byte_ctl(
    .i_sysclk   (i_sysclk),
    .i_nReset   (i_reset_n),  // sync reset
    .i_enable   (I2CCR[CCR_MEN]),   // iic enable
    .i_prescale (s_prescale), // clock prescale cnt
    .i_dfsr     (I2CDFSRR[5:0]),   // Digital Filter Sampling Rate cnt
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

always @(posedge i_sysclk or negedge i_reset_n)
begin
    if (!i_reset_n) begin
        s_prescale <= 16'd384;
    end
    else begin
        I2CSR[CSR_MBB] <= s_i2c_busy;
        s_prescale <= freq_divid_get(I2CFDR);
    end
end

always @(posedge I2CCR[CCR_MSTA])
begin
    if (I2CCR[CCR_MEN]) begin
        s_cmd    <= CMD_START;
        s_cmd_go <= 1;
        i2c_state <= SM_START;
        I2CSR[CSR_MIF] <= 0;
    end
end

always @(negedge I2CCR[CCR_MSTA])
begin
    if (I2CCR[CCR_MEN]) begin
        I2CSR[CSR_MIF] <= 0;
        s_cmd    <= CMD_STOP;
        s_cmd_go <= 1;
        i2c_state <= SM_STOP;
    end
end

always @(posedge i_sysclk or negedge i_reset_n)
begin
    if (!i_reset_n) begin
        s_cmd_go <= 0;
        s_cmd <= CMD_IDLE;
        i2c_state <= SM_IDLE;
    end
    else if (!I2CCR[CCR_MEN]) begin
        s_cmd <= CMD_IDLE;
        s_cmd_go <= 0;
    end
    else begin
        I2CSR <= I2CSR;
        if (s_cmd_go) begin
            s_cmd_go <= 0;
        end
    end
end

always @(posedge i_sysclk or negedge i_reset_n)
begin
    if (!i_reset_n) begin
        I2CADR   <= 8'h00;
        I2CFDR   <= 8'h00;
        I2CCR    <= 8'h00;
        I2CSR    <= 8'h81;
        I2CDR    <= 8'h00;
        I2CDFSRR <= 8'h10;
        s_data_out <= {{8{1'b1}}};
        go_read  <= 0;
        go_write <= 0;
        rd_ready_r <= 1'b1;
        wr_ready_r <= 1'b1;
        s_start_done <= 0;
        s_dr_updated <= 0;
        s_need_rd_seq <= 0;
    end
    else begin
        go_read <= 1'b0;
        go_write <= 1'b0;
        s_data_out <= s_data_out;

        if (s_start_done & s_dr_updated & I2CCR[CCR_MTX]) begin
            s_dr_updated <= 0;
            s_cmd    <= CMD_WRITE;
            s_cmd_go <= 1;
            i2c_state <= SM_WRITE;
            I2CSR[CSR_MIF] <= 0;
        end
        if ((i_rd_ena) && (ADDR_DR == i_rd_addr[4:2])) begin
            rd_ready_r <= 1;
        end
        else begin
            rd_ready_r <= 1;
        end
        if (s_need_rd_seq & s_start_done) begin
            if (((SM_RESTART == i2c_state) || (SM_START == i2c_state))) begin
                s_need_rd_seq   <= 0;
                I2CSR[CSR_MIF]  <= 1'b0;
                s_cmd        <= CMD_READ;
                s_cmd_go     <= 1;
                i2c_state    <= SM_READ;
            end
        end
    end
end

function [15:0] freq_divid_get(
    input [7:0] fdr
);
reg [15:0] freq_div;

begin

    case (fdr & 8'h3f)
        8'h00 : freq_div = 384;
        8'h01 : freq_div = 416;
        8'h02 : freq_div = 480;
        8'h03 : freq_div = 576;
        8'h04 : freq_div = 640;
        8'h05 : freq_div = 704;
        8'h06 : freq_div = 832;
        8'h07 : freq_div = 1024;
        8'h08 : freq_div = 1152;
        8'h09 : freq_div = 1280;
        8'h0A : freq_div = 1536;
        8'h0B : freq_div = 1920;
        8'h0C : freq_div = 2304;
        8'h0D : freq_div = 2560;
        8'h0E : freq_div = 3072;
        8'h0F : freq_div = 3840;
        8'h10 : freq_div = 4608;
        8'h11 : freq_div = 5120;
        8'h12 : freq_div = 6144;
        8'h13 : freq_div = 7680;
        8'h14 : freq_div = 9216;
        8'h15 : freq_div = 10240;
        8'h16 : freq_div = 12288;
        8'h17 : freq_div = 15360;
        8'h18 : freq_div = 18432;
        8'h19 : freq_div = 20480;
        8'h1A : freq_div = 24576;
        8'h1B : freq_div = 30720;
        8'h1C : freq_div = 36864;
        8'h1D : freq_div = 40960;
        8'h1E : freq_div = 49152;
        8'h1F : freq_div = 61440;
        8'h20 : freq_div = 256;
        8'h21 : freq_div = 288;
        8'h22 : freq_div = 320;
        8'h23 : freq_div = 352;
        8'h24 : freq_div = 384;
        8'h25 : freq_div = 448;
        8'h26 : freq_div = 512;
        8'h27 : freq_div = 576;
        8'h28 : freq_div = 640;
        8'h29 : freq_div = 768;
        8'h2A : freq_div = 896;
        8'h2B : freq_div = 1024;
        8'h2C : freq_div = 1280;
        8'h2D : freq_div = 1536;
        8'h2E : freq_div = 1792;
        8'h2F : freq_div = 2048;
        8'h30 : freq_div = 2560;
        8'h31 : freq_div = 3072;
        8'h32 : freq_div = 3584;
        8'h33 : freq_div = 4096;
        8'h34 : freq_div = 5120;
        8'h35 : freq_div = 6144;
        8'h36 : freq_div = 7168;
        8'h37 : freq_div = 8192;
        8'h38 : freq_div = 10240;
        8'h39 : freq_div = 12288;
        8'h3A : freq_div = 14336;
        8'h3B : freq_div = 16384;
        8'h3C : freq_div = 20480;
        8'h3D : freq_div = 24576;
        8'h3E : freq_div = 28672;
        8'h3F : freq_div = 32768;
    endcase
    freq_divid_get = freq_div;
end

endfunction

endmodule
