`include "timescale.v"

module i2c_top_module(
    input                i_sysclk,  // system clock input
    input                i_reset_n, // module reset input
    input                i_wr_ena,  // write enable
    input  wire [4:0]    i_wr_addr, // write address
    input  wire [7:0]    i_wr_data, // write date input
    input                i_rd_ena,  // read enable input
    input  wire [4:0]    i_rd_addr, // read address input
    output wire [7:0]    o_rd_data, // read date output
    output wire          o_read_ready, // data ready to read
    output wire          o_write_ready, // data ready to read
    inout  wire          scl_pin,   // scl pad pin
    inout  wire          sda_pin    // sda pad pin
);
`include "i2c-def.v"
`include "i2c-reg-def.v"

reg [7:0] I2CADR;
reg [7:0] I2CFDR;
reg [7:0] I2CCR;
reg [7:0] I2CSR;
reg [7:0] I2CDR;
reg [7:0] I2CDFSRR;
reg [7:0] data_out;
reg go;
reg go_go;
reg go_read;
reg go_write;
reg rd_ready_r;
reg wr_ready_r;

reg [2:0] i2c_state;

wire i_sda;
wire o_sda;
wire sda_oen;
wire i_scl;
wire o_scl;
wire scl_oen;


assign o_rd_data = data_out;
assign o_read_ready = rd_ready_r;
assign o_write_ready = wr_ready_r;

pullup scl_pu(scl_pin);
pullup sda_pu(sda_pin);

iobuf sda(
    .T  (sda_oen),
    .IO (sda_pin),
    .I  (o_sda),
    .O  (i_sda)
);

iobuf scl(
    .T  (scl_oen),
    .IO (scl_pin),
    .I  (o_scl),
    .O  (i_scl)
);


wire i_enable;   // iic enable

reg [15:0] i_prescale; // clock prescale cnt
reg [15:0] dfsr_cnt;   // Digital Filter Sampling Rate cnt

reg [2:0] i_i2c_cmd;

wire o_cmd_ack;
wire o_i2c_ack;
wire o_i2c_al;   // arbitration lost output
wire o_i2c_busy; // i2c bus busy output

// wire [7:0] i_data;
wire [7:0] o_data;

assign i_enable = I2CCR[CCR_MEN];

i2c_master_byte_ctl u1_byte_ctl(
    .sysclk    (i_sysclk),
    .nReset    (i_reset_n),  // sync reset
    .enable    (i_enable),   // iic enable
    .prescale  (i_prescale), // clock prescale cnt
    .dfsr      (dfsr_cnt),   // Digital Filter Sampling Rate cnt
    .go        (go | go_go),
    .cmd       (i_i2c_cmd),
    .cmd_ack   (o_cmd_ack),
    .o_i2c_ack (o_i2c_ack),
    .o_i2c_al  (o_i2c_al),   // arbitration lost output
    .o_i2c_busy(o_i2c_busy), // i2c bus busy output

    .i_data    (I2CDR),
    .o_data    (o_data),

    .i_scl     (i_scl),
    .o_scl     (o_scl),
    .scl_oen   (scl_oen),
    .i_sda     (i_sda),
    .o_sda     (o_sda),
    .sda_oen   (sda_oen)
);

wire div_ready;
reg  div_ena;
reg  [15:0] divisor;
wire [15:0] quotient;
wire [15:0] remainder;
wire div_done;

always @(posedge i_sysclk or negedge i_reset_n)
begin
    if (!i_reset_n)
    begin
        i_prescale <= 16'd384;
        div_ena <= 0;
        dfsr_cnt <= 16'd24;
    end
    else
    begin
        i_prescale <= freq_divid_get(I2CFDR);
        divisor    <= {{10{1'b0}}, I2CDFSRR[5:0]};
        if (div_ready)
        begin
            div_ena  <= 1'b1;
        end
        else if (div_done)
        begin
            dfsr_cnt <= quotient;
            div_ena  <= 1'b0;
        end
    end
end

div_fsm #(
    .DATA_WIDTH(16)
)
dfsr_div_u1
(
    /* input                        */ .clk      (i_sysclk),
    /* input                        */ .rstn     (i_reset_n),
    /* input                        */ .en       (div_ena),
    /* output wire                  */ .ready    (div_ready),
    /* input       [DATA_WIDTH-1:0] */ .dividend (i_prescale),
    /* input       [DATA_WIDTH-1:0] */ .divisor  (divisor),
    /* output wire [DATA_WIDTH-1:0] */ .quotient (quotient),
    /* output wire [DATA_WIDTH-1:0] */ .remainder(remainder),
    /* output wire                  */ .vld_out  (div_done)
);

always @(posedge I2CCR[CCR_MSTA])
begin
    if (I2CCR[CCR_MEN] & I2CCR[CCR_MSTA] & I2CCR[CCR_MTX])
    begin
        case (i2c_state)
            SM_IDLE:
            begin
                i_i2c_cmd <= CMD_START;
                i2c_state <= SM_START;
                go <= 1;
                wr_ready_r <= 1'b0;
            end
            SM_START  :;
            SM_STOP   :;
            SM_WRITE  :;
            SM_READ   :;
            SM_WR_ACK :;
            SM_RD_ACK :;
            SM_RESTART:;
            default   :;
        endcase
    end
end

always @(negedge I2CCR[CCR_MSTA])
begin
    if (I2CCR[CCR_MEN])
    begin
        i_i2c_cmd <= CMD_STOP;
        i2c_state <= SM_STOP;
        go <= 1;
    end
end

always @(posedge go_write)
begin
    if (I2CCR[CCR_MEN] & I2CCR[CCR_MSTA] & I2CCR[CCR_MTX])
    begin
        case (i2c_state)
            SM_IDLE   :;
            SM_START  :
            begin
                i2c_state <= SM_WRITE;
                i_i2c_cmd <= CMD_WRITE;
                go <= 1;
            end
            SM_STOP   :;
            SM_WRITE  :;
            SM_READ   :;
            SM_WR_ACK :;
            SM_RD_ACK :
            begin
                i2c_state <= SM_WRITE;
                i_i2c_cmd <= CMD_WRITE;
                go <= 1;
            end
            SM_RESTART:
            begin
                i2c_state <= SM_WRITE;
                i_i2c_cmd <= CMD_WRITE;
                go <= 1;
            end
            default   :;
        endcase
    end
end

always @(posedge go_read)
begin
    if (I2CCR[CCR_MEN] & I2CCR[CCR_MSTA])
    begin
        i2c_state <= SM_READ;
        i_i2c_cmd <= CMD_READ;
        go <= 1;
    end
end

always @(posedge i_sysclk or negedge i_reset_n)
begin
    if (!i_reset_n)
    begin
        go <= 0;
        i_i2c_cmd <= CMD_IDLE;
        i2c_state <= SM_IDLE;
    end
    else
    begin
        go <= 0;
        if (/* I2CCR[CCR_MIEN] & */ I2CCR[CCR_MEN] & I2CCR[CCR_MSTA])
        begin
            if (o_cmd_ack)
            begin
                case (i2c_state)
                    SM_IDLE   :;
                    SM_START  :
                    begin
                        I2CSR[CSR_MBB] <= 1'b1;
                        wr_ready_r <= 1'b1;
                    end
                    SM_STOP   :
                    begin
                        I2CSR[CSR_MBB] <= 1'b0;
                        I2CSR[CSR_MCF] <= 1'b1;
                        i2c_state <= SM_IDLE;
                        i_i2c_cmd <= CMD_IDLE;
                    end
                    SM_WRITE  :
                    begin
                        if (I2CCR[CCR_MTX])
                        begin
                            i2c_state = SM_RD_ACK;
                            i_i2c_cmd <= CMD_RD_ACK;
                            go <= 1;
                        end
                    end
                    SM_READ   :
                    begin
                        rd_ready_r <= 1'b1;
                        I2CDR <= o_data;
                        data_out <= o_data;
                        if (!I2CCR[CCR_TXAK])
                        begin
                            i2c_state <= SM_WR_ACK;
                            i_i2c_cmd <= CMD_WR_ACK;
                            go <= 1;
                        end
                        else
                        begin
                            I2CSR[CSR_MCF]  <= 1'b1;
                            // I2CSR[CSR_MAAS] <= 1'b0;
                            // I2CSR[CSR_MBB] <= o_i2c_busy;
                            I2CSR[CSR_MAL]  <= o_i2c_al;
                            // I2CSR[CSR_BCSTM] <= 1'b0;
                            // I2CSR[CSR_SRW] <= 1'b0;
                            I2CSR[CSR_MIF]  <= 1'b1;
                            I2CSR[CSR_RXAK] <= 1'b1;
                        end
                    end
                    SM_WR_ACK :
                        begin

                            I2CSR[CSR_MCF]  <= 1'b1;
                            // I2CSR[CSR_MAAS] <= 1'b0;
                            // I2CSR[CSR_MBB] <= o_i2c_busy;
                            I2CSR[CSR_MAL]  <= o_i2c_al;
                            // I2CSR[CSR_BCSTM] <= 1'b0;
                            // I2CSR[CSR_SRW] <= 1'b0;
                            I2CSR[CSR_MIF]  <= 1'b1;
                            I2CSR[CSR_RXAK] <= o_i2c_ack;
                        end
                    SM_RD_ACK :
                    begin
                        wr_ready_r <= 1'b1;
                        I2CSR[CSR_MCF]  <= 1'b1;
                        // I2CSR[CSR_MAAS] <= 1'b0;
                        // I2CSR[CSR_MBB] <= o_i2c_busy;
                        I2CSR[CSR_MAL]  <= o_i2c_al;
                        // I2CSR[CSR_BCSTM] <= 1'b0;
                        // I2CSR[CSR_SRW] <= 1'b0;
                        I2CSR[CSR_MIF]  <= 1'b1;
                        I2CSR[CSR_RXAK] <= o_i2c_ack;
                    end
                    SM_RESTART :
                    begin
                        wr_ready_r <= 1'b1;
                    end
                    default:
                    begin
                        i2c_state <= SM_IDLE;
                        i_i2c_cmd <= CMD_IDLE;
                    end
                endcase
            end
        end
    end
end

always @(posedge i_sysclk or negedge i_reset_n)
begin
    if (!i_reset_n)
    begin
        I2CADR   <= 8'h00;
        I2CFDR   <= 8'h00;
        I2CCR    <= 8'h00;
        I2CSR    <= 8'h81;
        I2CDR    <= 8'h00;
        I2CDFSRR <= 8'h10;
        data_out <= {{8{1'b1}}};
        go_go <= 0;
        go_read  <= 0;
        go_write <= 0;
        rd_ready_r <= 1'b1;
        wr_ready_r <= 1'b1;
    end
    else
    begin
        go_go <= 0;
        go_read <= 1'b0;
        go_write <= 1'b0;
        data_out <= data_out;
        if (i_wr_ena)
        begin
            case (i_wr_addr[4:2])
                ADDR_ADR   :
                begin
                    I2CADR   <= i_wr_data;
                end
                ADDR_FDR   :
                begin
                    I2CFDR   <= i_wr_data;
                end
                ADDR_CR    :
                begin
                    I2CCR    <= i_wr_data;
                    if (i_wr_data[CCR_RSTA] & i_wr_data[CCR_MEN] & i_wr_data[CCR_MSTA] & i_wr_data[CCR_MTX])
                    begin
                        case (i2c_state)
                            SM_IDLE   :;
                            SM_START  :;
                            SM_STOP   :;
                            SM_WRITE  :;
                            SM_READ   :;
                            SM_WR_ACK :
                            begin
                                i_i2c_cmd <= CMD_RESTART;
                                i2c_state <= SM_RESTART;
                                go <= 1'b1;
                                go_go <= 1'b1;
                                wr_ready_r <= 1'b0;
                            end
                            SM_RD_ACK :
                            begin
                                i_i2c_cmd <= CMD_RESTART;
                                i2c_state <= SM_RESTART;
                                go <= 1'b1;
                                go_go <= 1'b1;
                                wr_ready_r <= 1'b0;
                            end
                            SM_RESTART:;
                            default   :;
                        endcase
                    end
                end
                ADDR_SR    :
                begin
                    if (I2CSR[CSR_MBB] & I2CSR[CSR_MCF])
                    begin
                        I2CSR[CSR_MAL] <= i_wr_data[CSR_MAL];
                        I2CSR[CSR_MIF] <= i_wr_data[CSR_MIF];
                    end
                end
                ADDR_DR    :
                begin
                    if (I2CSR[CSR_MBB] & I2CSR[CSR_MCF] & (!I2CSR[CSR_MIF]))
                    begin
                        I2CSR[CSR_MCF] <= 1'b0;
                        I2CDR    <= i_wr_data;
                        go_write <= 1'b1;
                        wr_ready_r <= 1'b0;
                    end
                end
                ADDR_DFSRR : I2CDFSRR <= i_wr_data;
                default    : I2CSR    <= I2CSR;
            endcase
        end
        if (i_rd_ena)
        begin
            case (i_rd_addr[4:2])
                ADDR_ADR   :
                begin
                    data_out <= I2CADR  ;
                end
                ADDR_FDR   :
                begin
                    data_out <= I2CFDR  ;
                end
                ADDR_CR    :
                begin
                    data_out <= I2CCR   ;
                end
                ADDR_SR    :
                begin
                    data_out <= I2CSR   ;
                end
                ADDR_DR    :
                begin
                    if (I2CSR[CSR_MBB] & I2CSR[CSR_MCF])
                    begin
                        I2CSR[CSR_MCF] <= 1'b0;
                        // I2CDR <= i_data;
                        go_read <= 1'b1;
                        rd_ready_r <= 1'b0;
                    end
                end
                ADDR_DFSRR :
                begin
                    data_out <= I2CDFSRR;
                end
                default    :
                begin
                    data_out <= I2CSR   ;
                end
            endcase
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

// the follow copy from https://www.cnblogs.com/lyc-seu/p/12864956.html

module div_fsm #(
    parameter DATA_WIDTH = 16
)
(
    input                        clk,
    input                        rstn,
    input                        en,
    output wire                  ready,
    input       [DATA_WIDTH-1:0] dividend ,
    input       [DATA_WIDTH-1:0] divisor  ,
    output wire [DATA_WIDTH-1:0] quotient ,
    output wire [DATA_WIDTH-1:0] remainder,
    output wire                  vld_out
);

reg [DATA_WIDTH*2-1:0] dividend_e ;
reg [DATA_WIDTH*2-1:0] divisor_e  ;
reg [DATA_WIDTH-1:0]   quotient_e ;
reg [DATA_WIDTH-1:0]   remainder_e;

reg [1:0] current_state,next_state;

reg [DATA_WIDTH-1:0] count;

localparam IDLE  = 2'b00;
localparam SUB   = 2'b01;
localparam SHIFT = 2'b10;
localparam DONE  = 2'b11;

always@(posedge clk or negedge rstn)
begin
    if(!rstn)
        current_state <= IDLE;
    else
        current_state <= next_state;
end

always @(*)
begin
    next_state <= 2'bx;
    case(current_state)
        IDLE:
        begin
            if(en)
                next_state <= SUB;
            else
                next_state <= IDLE;
        end
        SUB:  next_state <= SHIFT;
        SHIFT:
        begin
            if(count < DATA_WIDTH)
                next_state <= SUB;
            else
                next_state <= DONE;
        end
        DONE: next_state <= IDLE;
    endcase
end

always@(posedge clk or negedge rstn)
begin
    if(!rstn)
    begin
        dividend_e  <= 0;
        divisor_e   <= 0;
        quotient_e  <= 0;
        remainder_e <= 0;
        count       <= 0;
    end
    else
    begin
    case(current_state)
        IDLE:
        begin
            dividend_e <= {{DATA_WIDTH{1'b0}},dividend};
            divisor_e  <= {divisor,{DATA_WIDTH{1'b0}}};
        end
        SUB:
        begin
            if(dividend_e>=divisor_e)
            begin
                quotient_e <= {quotient_e[DATA_WIDTH-2:0],1'b1};
                dividend_e <= dividend_e-divisor_e;
            end
            else
            begin
                quotient_e <= {quotient_e[DATA_WIDTH-2:0],1'b0};
                dividend_e <= dividend_e;
            end
        end
        SHIFT:
        begin
            if(count < DATA_WIDTH)
            begin
                dividend_e <= dividend_e<<1;
                count      <= count+1;
            end
            else begin
                remainder_e <= dividend_e[DATA_WIDTH*2-1:DATA_WIDTH];
            end
        end
        DONE:
        begin
            count <= 0;
        end
    endcase
end
end

assign quotient  = quotient_e;
assign remainder = remainder_e;

assign ready   = (current_state == IDLE)? 1'b1:1'b0;
assign vld_out = (current_state == DONE)? 1'b1:1'b0;


endmodule

