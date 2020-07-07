`include "timescale.v"

module i2c_top_module(
    input                sysclk_i,  // system clock input
    input                reset_n_i, // module reset input
    input                wr_ena_i,  // write enable
    input  wire [4:0]    wr_addr_i, // write address
    input  wire [7:0]    wr_data_i, // write date input
    input                rd_ena_i,  // read enable input
    input  wire [4:0]    rd_addr_i, // read address input
    output wire [7:0]    rd_data_o, // read date output
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

wire sda_i;
wire sda_o;
wire sda_oen;
wire scl_i;
wire scl_o;
wire scl_oen;

assign rd_data_o = data_out;

pullup scl_pu(scl_pin);
pullup sda_pu(sda_pin);

iobuf sda(
    .T  (sda_oen),
    .IO (sda_pin),
    .I  (sda_o),
    .O  (sda_i)
);

iobuf scl(
    .T  (scl_oen),
    .IO (scl_pin),
    .I  (scl_o),
    .O  (scl_i)
);


wire enable_i;   // iic enable

reg [15:0] prescale_i; // clock prescale cnt
reg [15:0] dfsr_cnt;   // Digital Filter Sampling Rate cnt

reg [2:0] i2c_cmd_i;

wire cmd_ack_o;
wire i2c_ack_o;
wire i2c_al_o;   // arbitration lost output
wire i2c_busy_o; // i2c bus busy output

wire [7:0] data_i;
wire [7:0] data_o;

assign enable_i = I2CCR[BIT_MEN];

i2c_master_byte_ctl u1_byte_ctl(
    .sysclk_i  (sysclk_i),
    .reset_n_i (reset_n_i),  // sync reset

    .enable_i  (enable_i),   // iic enable

    .prescale_i(prescale_i), // clock prescale cnt
    .dfsr_cnt  (dfsr_cnt),   // Digital Filter Sampling Rate cnt

    .i2c_cmd_i (i2c_cmd_i),
    
    .cmd_ack_o (cmd_ack_o),
    .i2c_ack_o (i2c_ack_o),
    .i2c_al_o  (i2c_al_o),   // arbitration lost output
    .i2c_busy_o(i2c_busy_o), // i2c bus busy output

    .data_i    (I2CDR),
    .data_o    (data_o),

    .scl_i     (scl_i),
    .scl_o     (scl_o),
    .scl_oen   (scl_oen),
    .sda_i     (sda_i),
    .sda_o     (sda_o),
    .sda_oen   (sda_oen)
);

wire div_ready;
reg  div_ena;
reg  [15:0] divisor;
wire [15:0] quotient;
wire [15:0] remainder;
wire div_done;

always @(posedge sysclk_i or negedge reset_n_i)
begin
    if (!reset_n_i)
    begin
        prescale_i <= 16'd384;
        div_ena <= 0;
        dfsr_cnt <= 16'd24;
    end
    else 
    begin
        prescale_i <= freq_divid_get(I2CFDR);
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
    /* input                        */ .clk      (sysclk_i),
    /* input                        */ .rstn     (reset_n_i),
    /* input                        */ .en       (div_ena),
    /* output wire                  */ .ready    (div_ready),
    /* input       [DATA_WIDTH-1:0] */ .dividend (prescale_i),
    /* input       [DATA_WIDTH-1:0] */ .divisor  (divisor),
    /* output wire [DATA_WIDTH-1:0] */ .quotient (quotient),
    /* output wire [DATA_WIDTH-1:0] */ .remainder(remainder),
    /* output wire                  */ .vld_out  (div_done)
);


always @(posedge sysclk_i or negedge reset_n_i)
begin
    if (!reset_n_i)
    begin
        i2c_cmd_i <= CMD_IDLE;
    end
    else 
    begin
        if (i2c_cmd_i == CMD_IDLE)
        begin
            if (I2CCR[BIT_MEN] & I2CCR[BIT_MSTA])
                i2c_cmd_i <= CMD_START;
        end
        
        if (cmd_ack_o && (i2c_cmd_i == CMD_START))
        begin
            i2c_cmd_i <= CMD_WRITE;
        end
    end
end

always @(posedge sysclk_i or negedge reset_n_i)
begin
    if (!reset_n_i)
    begin
        I2CADR   <= 8'h00;
        I2CFDR   <= 8'h00;
        I2CCR    <= 8'h00;
        I2CSR    <= 8'h81;
        I2CDR    <= 8'h50;
        I2CDFSRR <= 8'h10;
        data_out <= {{8{1'b0}}};
    end
    else
    begin
        if (wr_ena_i)
        begin
            case (wr_addr_i[4:2])
                ADDR_ADR   : I2CADR   <= wr_data_i;
                ADDR_FDR   : I2CFDR   <= wr_data_i;
                ADDR_CR    : I2CCR    <= wr_data_i;
                ADDR_SR    : I2CSR    <= wr_data_i;
                ADDR_DR    : I2CDR    <= wr_data_i;
                ADDR_DFSRR : I2CDFSRR <= wr_data_i;
                default    : I2CSR    <= I2CSR;
            endcase
        end
        if (rd_ena_i)
        begin
            case (rd_addr_i[4:2])
                ADDR_ADR   : data_out <= I2CADR  ;
                ADDR_FDR   : data_out <= I2CFDR  ;
                ADDR_CR    : data_out <= I2CCR   ;
                ADDR_SR    : data_out <= I2CSR   ;
                ADDR_DR    : data_out <= I2CDR   ;
                ADDR_DFSRR : data_out <= I2CDFSRR;
                default    : data_out <= I2CSR   ;
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

