`include "timescale.v"

module i2c_master_byte_ctl(
    input             sysclk,
    input             nReset,   // sync reset

    input             enable,   // iic enable

    input      [15:0] prescale, // clock prescale cnt
    input      [15:0] dfsr,     // Digital Filter Sampling Rate cnt

    input             go,
    input      [2:0]  cmd,

    output            cmd_ack,
    output            i2c_ack_o,
    output            i2c_al_o,   // arbitration lost output
    output            i2c_busy_o, // i2c bus busy output

    input      [7:0]  data_i,
    output     [7:0]  data_o,

    input             scl_i,
    output            scl_o,
    output            scl_oen,
    input             sda_i,
    output            sda_o,
    output            sda_oen
);
`include "i2c-def.v"
`include "i2c-reg-def.v"

reg  bit_i;
reg  [2:0] bit_cmd;
reg  [2:0] c_state;
wire bit_done;
reg  cmd_done;
wire bit_o;
reg  bit_ack;
reg [7:0] shift_r;
reg [2:0] bit_cnt;

assign cmd_ack = cmd_done;
assign i2c_ack_o = bit_ack;
always @(posedge sysclk or negedge nReset)
begin
    if (!nReset || !enable)
    begin
        bit_ack <= 1;
        bit_cmd <= CMD_IDLE;
        bit_i  <= 1'b1;
        shift_r <= 8'hff;
        bit_cnt <= 3'h7;
        cmd_done <= 0;
        c_state <= CMD_IDLE;
    end
    else 
    begin
        // bit_ack = bit_o;
        cmd_done <= 1'b0;
        bit_i <= shift_r[bit_cnt];
        // cmd_done <= 1'b0;
        if (bit_done)
        begin
            bit_cmd <= CMD_IDLE;
            case (c_state)
                CMD_START:
                begin
                    cmd_done <= 1'b1;
                    shift_r = data_i;
                    bit_cnt <= 3'h7;
                end
                CMD_WRITE:
                begin
                    bit_cmd <= c_state;
                    bit_cnt <= bit_cnt - 1;
                    if (bit_cnt == 1'b0)
                    begin
                        cmd_done <= 1'b1;
                        bit_cnt <= 3'h7;
                        shift_r = data_i;
                    end
                end
                CMD_READ:
                begin
                    bit_cmd <= c_state;
                    bit_cnt <= bit_cnt - 1;
                    if (bit_cnt == 1'b0)
                    begin
                        cmd_done <= 1'b1;
                        bit_cnt <= 3'h7;
                    end
                end
                CMD_WR_ACK:
                begin
                    cmd_done <= 1'b1;
                    bit_cnt <= 3'h7;
                    shift_r = data_i;
                end
                CMD_RD_ACK:
                begin
                    cmd_done <= 1'b1;
                    bit_cnt <= 3'h7;
                    shift_r = data_i;
                end
                CMD_RESTART:
                begin
                    bit_cmd <= CMD_IDLE;
                    c_state <= CMD_IDLE;
                    cmd_done <= 1'b1;
                end
                CMD_STOP: c_state <= CMD_IDLE;
                default : bit_cmd <= CMD_IDLE;
            endcase
        end
        if (go)
        begin
            c_state <= cmd;
            case (cmd)
                CMD_IDLE:
                begin
                    bit_cmd <= CMD_IDLE;
                end
                CMD_START:
                begin
                    bit_cmd <= cmd;
                end
                CMD_WRITE:
                begin
                    bit_cmd <= cmd;
                end
                CMD_READ:
                begin
                    bit_cmd <= cmd;
                end
                CMD_RD_ACK:
                begin
                    bit_cnt <= 3'h7;
                    shift_r = data_i;
                    bit_cmd <= CMD_READ;
                end
                CMD_WR_ACK:
                begin
                    bit_i <= 0;
                    bit_cmd <= CMD_WRITE;
                end
                CMD_RESTART:
                begin
                    bit_cmd <= CMD_RESTART;
                end
                CMD_STOP: 
                begin
                    bit_cmd <= CMD_STOP;
                end
                default :;
            endcase
        end
    end
end


i2c_bit_ctl bit_controller(
    .sysclk     (sysclk),   // system clock input
    .nReset     (nReset),  // sync reset
    .enable     (enable),   // iic enable

    .prescale   (prescale), // clock prescale cnt
    .dfsr       (dfsr),     // sample clk cnt

    .cmd        (bit_cmd),
    .cmd_ack    (bit_done),    // cmd compelete ack
    .busy       (busy_o),     // bus busy
    .arblost    (arblost_o),  // arbitration lost

    .din        (bit_i),
    .dout       (bit_o),

    .scl_i      (scl_i),
    .scl_o      (scl_o),
    .scl_oen    (scl_oen),
    .sda_i      (sda_i),
    .sda_o      (sda_o),
    .sda_oen    (sda_oen)
);

endmodule

