`include "timescale.v"

module i2c_bit_ctl(
    input          sysclk,   // system clock input
    input          nReset,   // sync reset
    input          enable,   // iic enable

    input [15:0]   prescale, // clock prescale cnt
    input [15:0]   dfsr,     // sample clk cnt

    input [2:0]    cmd,
    output reg     cmd_ack,  // cmd compelete ack
    output reg     busy,     // bus busy
    output reg     arblost,  // arbitration lost

    input          din,
    output         dout,

    input          scl_i,
    output         scl_o,
    output reg     scl_oen,
    input          sda_i,
    output         sda_o,
    output reg     sda_oen
);
`include "i2c-def.v"

reg [4:0] c_state;
reg [15:0] cnt;
reg [15:0] filter_cnt;
reg clk_en;
reg sda_chk;
reg fSCL;
reg sSda;
// reg scl_chk;

always @(posedge sysclk or negedge nReset)
begin
    if (!nReset)
    begin
        sSda <= 0;
        fSCL <= 0;
        clk_en <= 1'b1;
        cnt <= 16'd192;
        filter_cnt <= (192/16);
    end
    else if (!enable)
    begin
        sSda <= 0;
        clk_en <= 1'b1;
        cnt <= {2'b0, prescale[15:2]};
        filter_cnt <= {1'b0, dfsr[15:1]};
    end
    else 
    begin
        cnt <= cnt - 1;
        filter_cnt <= filter_cnt - 1;
        if (filter_cnt == 0) begin
            fSCL <= ~fSCL;
            filter_cnt <= {1'b0, dfsr[15:1]};
        end
        else
        begin
            fSCL <= fSCL;
        end
        if (sda_oen)
        begin
            sSda <= sda_i;
        end
        if (cnt == 0)
        begin
            if (c_state == B_IDLE) begin
                cnt <= {4'b0, prescale[15:4]};
            end
            else begin
                cnt <= {2'b0, prescale[15:2]};
            end
            clk_en <= 1'b1;
        end
        else begin
            clk_en <= 1'b0;
        end
    end
end


always @(posedge sysclk or negedge nReset)
begin
    if (!nReset)
    begin
        scl_oen <= 1'b1;
        sda_oen <= 1'b1;
        sda_chk <= 1'b0;
        cmd_ack <= 1'b0;
        busy    <= 1'b0;
        arblost <= 1'b0;
        c_state <= B_IDLE;
    end
    else if (!enable)
    begin
        scl_oen <= 1'b1;
        sda_oen <= 1'b1;
        sda_chk <= 1'b0;
        cmd_ack <= 1'b0;
        busy    <= 1'b0;
        arblost <= 1'b0;
        c_state <= B_IDLE;
    end
    else 
    begin
        cmd_ack <= 1'b0;
        if (clk_en)
        begin
            case (c_state)
                B_IDLE    : 
                begin
                    case (cmd)
                        CMD_IDLE   :c_state <= B_IDLE;
                        CMD_START  :c_state <= B_START_A;
                        CMD_STOP   :c_state <= B_STOP_A;
                        CMD_WRITE  :c_state <= B_WRITE_A;
                        CMD_READ   :c_state <= B_READ_A;
                        CMD_RESTART:c_state <= B_RESTART_A;
                        default    :c_state <= B_IDLE;
                    endcase
                    scl_oen <= scl_oen;
                    sda_oen <= sda_oen;
                    sda_chk <= 1'b0;
                end
                B_START_A : 
                begin
                    c_state <= B_START_B;
                    scl_oen <= scl_oen;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                end
                B_START_B : 
                begin
                    c_state <= B_START_C;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                end
                B_START_C : 
                begin
                    c_state <= B_START_D;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b0;
                    sda_chk <= 1'b0;
                end
                B_START_D : 
                begin
                    c_state <= B_START_E;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b0;
                    sda_chk <= 1'b0;
                end
                B_START_E : 
                begin
                    c_state <= B_IDLE;
                    cmd_ack <= 1'b1;
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b0;
                    sda_chk <= 1'b0;
                end

                B_STOP_A  : 
                begin
                    c_state <= B_STOP_B;
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b0;
                    sda_chk <= 1'b0;
                end
                B_STOP_B  : 
                begin
                    c_state <= B_STOP_C;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b0;
                    sda_chk <= 1'b0;
                end
                B_STOP_C  : 
                begin
                    c_state <= B_STOP_D;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b1;
                end
                B_STOP_D  : 
                begin
                    c_state <= B_IDLE;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    cmd_ack <= 1'b1;
                    sda_chk <= 1'b0;
                end

                B_READ_A  : 
                begin
                    c_state <= B_READ_B;
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                end
                B_READ_B  : 
                begin
                    c_state <= B_READ_C;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                end
                B_READ_C  : 
                begin
                    c_state <= B_READ_D;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                end
                B_READ_D  : 
                begin
                    c_state <= B_IDLE;
                    cmd_ack <= 1'b1;
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                end

                B_WRITE_A : 
                begin
                    c_state <= B_WRITE_B;
                    scl_oen <= 1'b0;
                    sda_oen <= din;
                    sda_chk <= 1'b0;
                end
                B_WRITE_B : 
                begin
                    c_state <= B_WRITE_C;
                    scl_oen <= 1'b1;
                    sda_oen <= din;
                    sda_chk <= 1'b0;
                end
                B_WRITE_C : 
                begin
                    c_state <= B_WRITE_D;
                    scl_oen <= 1'b1;
                    sda_oen <= din;
                    sda_chk <= 1'b1;
                end
                B_WRITE_D : 
                begin
                    c_state <= B_IDLE;
                    cmd_ack <= 1'b1;
                    scl_oen <= 1'b0;
                    sda_oen <= din;
                    sda_chk <= 1'b0;
                end

                B_RESTART_A : 
                begin
                    c_state <= B_RESTART_B;
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                end
                B_RESTART_B : 
                begin
                    c_state <= B_RESTART_C;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                end
                B_RESTART_C : 
                begin
                    c_state <= B_RESTART_D;
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b0;
                    sda_chk <= 1'b1;
                end
                B_RESTART_D : 
                begin
                    c_state <= B_IDLE;
                    cmd_ack <= 1'b1;
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b0;
                    sda_chk <= 1'b0;
                end

                default : c_state <= B_IDLE;
            endcase
        end
    end
end

assign scl_o = scl_oen;
assign sda_o = sda_oen;

assign dout = sSda;

endmodule

