`include "timescale.v"

module i2c_bit_ctl(
    input          sysclk_i,   // system clock input
    input          reset_n_i,  // sync reset
    input          enable_i,   // iic enable

    input [15:0]   prescale_i, // clock prescale cnt
    input [15:0]   dfsr_cnt, // sample clk cnt

    input [2:0]    cmd_i,
    output reg     cmd_ack,    // cmd compelete ack
    output reg     busy_o,     // bus busy
    output reg     arblost_o,  // arbitration lost

    input          bit_i,
    output         bit_o,

    input          scl_i,
    output         scl_o,
    output reg     scl_oen,
    input          sda_i,
    output         sda_o,
    output reg     sda_oen
);
`include "i2c-def.v"

reg [15:0] cnt;
reg [15:0] filter_cnt;
reg clk_en;
reg sda_chk;
// reg scl_chk;

always @(posedge sysclk_i or negedge reset_n_i)
begin
    if (!reset_n_i)
    begin
        clk_en <= 1'b0;
        cnt <= 16'd384;
        filter_cnt <= ((384)/16);
    end
    else if (!enable_i)
    begin
        cnt <= prescale_i;
        filter_cnt <= dfsr_cnt;
    end
    else 
    begin
        cnt <= cnt - 1;
        filter_cnt <= filter_cnt - 1;
        if (filter_cnt == 0)
        begin
            filter_cnt <= dfsr_cnt;
            clk_en <= 1'b1;
        end
        if (clk_en == 1'b1)
            clk_en <= 1'b0;
    end
end

reg [4:0] bit_state;

always @(posedge sysclk_i or negedge reset_n_i)
begin
    if (!reset_n_i)
    begin
        scl_oen <= 1'b1;
        sda_oen <= 1'b1;
        sda_chk <= 1'b0;
        cmd_ack <= 1'b0;
        busy_o  <= 1'b0;
        arblost_o <= 1'b0;
        bit_state <= BCTL_IDLE;
    end
    else if (!enable_i)
    begin
        sda_chk <= 1'b0;
        scl_oen <= 1'b1;
        sda_oen <= 1'b1;
        cmd_ack <= 1'b0;
        bit_state <= BCTL_IDLE;
    end
    else 
    begin
        cmd_ack <= 1'b0;
        if (clk_en)
        begin
            case (bit_state)
                BCTL_IDLE    : 
                begin
                    case (cmd_i)
                        CMD_IDLE   :bit_state <= BCTL_IDLE;
                        CMD_START  :bit_state <= BCTL_START_A;
                        CMD_STOP   :bit_state <= BCTL_STOP_A;
                        CMD_WRITE  :bit_state <= BCTL_WRITE_A;
                        CMD_READ   :bit_state <= BCTL_READ_A;
                        CMD_WR_ACK :bit_state <= BCTL_W_ACK_A;
                        CMD_RD_ACK :bit_state <= BCTL_R_ACK_A;
                        default    :bit_state <= BCTL_IDLE;
                    endcase
                    scl_oen <= scl_oen;
                    sda_oen <= sda_oen;
                    sda_chk <= 1'b0;
                end
                BCTL_START_A : 
                begin
                    scl_oen <= scl_oen;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                    bit_state <= BCTL_START_B;
                end
                BCTL_START_B : 
                begin
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                    bit_state <= BCTL_START_C;
                end
                BCTL_START_C : 
                begin
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b0;
                    sda_chk <= 1'b0;
                    bit_state <= BCTL_START_D;
                end
                BCTL_START_D : 
                begin
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b0;
                    sda_chk <= 1'b0;
                    bit_state <= BCTL_START_E;
                end
                BCTL_START_E : 
                begin
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b0;
                    sda_chk <= 1'b0;

                    cmd_ack <= 1'b1;
                    bit_state <= BCTL_IDLE;
                end
                BCTL_STOP_A  : 
                begin
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b0;
                    sda_chk <= 1'b0;

                    bit_state <= BCTL_STOP_B;
                end
                BCTL_STOP_B  : 
                begin
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b0;
                    sda_chk <= 1'b0;

                    bit_state <= BCTL_STOP_C;
                end
                BCTL_STOP_C  : 
                begin
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b0;
                    sda_chk <= 1'b0;

                    bit_state <= BCTL_STOP_D;
                end
                BCTL_STOP_D  : 
                begin
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;

                    cmd_ack <= 1'b1;
                    bit_state <= BCTL_IDLE;
                end
                BCTL_WRITE_A : 
                begin
                    scl_oen <= 1'b0;
                    sda_oen <= bit_i;
                    sda_chk <= 1'b0;

                    bit_state <= BCTL_WRITE_B;
                end
                BCTL_WRITE_B : 
                begin
                    scl_oen <= 1'b1;
                    sda_oen <= bit_i;
                    sda_chk <= 1'b0;

                    bit_state <= BCTL_WRITE_C;
                end
                BCTL_WRITE_C : 
                begin
                    scl_oen <= 1'b1;
                    sda_oen <= bit_i;
                    sda_chk <= 1'b1;

                    bit_state <= BCTL_WRITE_D;
                end
                BCTL_WRITE_D : 
                begin
                    scl_oen <= 1'b0;
                    sda_oen <= bit_i;
                    sda_chk <= 1'b0;

                    cmd_ack <= 1'b1;
                    bit_state <= BCTL_IDLE;
                end
                BCTL_READ_A  : 
                begin
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;

                    bit_state <= BCTL_READ_B;
                end
                BCTL_READ_B  : 
                begin
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;

                    bit_state <= BCTL_READ_C;
                end
                BCTL_READ_C  : 
                begin
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;

                    bit_state <= BCTL_READ_D;
                end
                BCTL_READ_D  : 
                begin
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;

                    cmd_ack <= 1'b1;
                    bit_state <= BCTL_IDLE;
                end
                BCTL_W_ACK_A : 
                begin
                    scl_oen <= 1'b0;
                    sda_oen <= bit_i;
                    sda_chk <= 1'b0;

                    bit_state <= BCTL_W_ACK_B;
                end
                BCTL_W_ACK_B : 
                begin
                    scl_oen <= 1'b1;
                    sda_oen <= bit_i;
                    sda_chk <= 1'b0;

                    bit_state <= BCTL_W_ACK_C;
                end
                BCTL_W_ACK_C : 
                begin
                    scl_oen <= 1'b1;
                    sda_oen <= bit_i;
                    sda_chk <= 1'b1;

                    bit_state <= BCTL_W_ACK_D;
                end
                BCTL_W_ACK_D : 
                begin
                    scl_oen <= 1'b0;
                    sda_oen <= bit_i;
                    sda_chk <= 1'b0;

                    cmd_ack <= 1'b1;
                    bit_state <= BCTL_IDLE;
                end
                BCTL_R_ACK_A : 
                begin
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;

                    bit_state <= BCTL_R_ACK_B;
                end
                BCTL_R_ACK_B : 
                begin
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;

                    bit_state <= BCTL_R_ACK_C;
                end
                BCTL_R_ACK_C : 
                begin
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;

                    bit_state <= BCTL_R_ACK_D;
                end
                BCTL_R_ACK_D : 
                begin
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;

                    cmd_ack <= 1'b1;
                    bit_state <= BCTL_IDLE;
                end
                default : bit_state <= BCTL_IDLE;
            endcase
        end
    end

end

assign scl_o = scl_oen;
assign sda_o = sda_oen;

endmodule

