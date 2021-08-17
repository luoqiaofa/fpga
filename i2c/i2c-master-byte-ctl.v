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
    output            o_i2c_ack,
    output            o_i2c_al,   // arbitration lost output
    output            o_i2c_busy, // i2c bus busy output

    input      [7:0]  i_data,
    output     [7:0]  o_data,

    input             i_scl,
    output            o_scl,
    output            scl_oen,
    input             i_sda,
    output            o_sda,
    output            sda_oen
);
`include "i2c-def.v"
`include "i2c-reg-def.v"

reg  i_bit;
reg  [2:0] bit_cmd;
reg  [2:0] c_state;
wire bit_done;
reg  cmd_done;
wire o_bit;
reg  bit_ack;
reg [7:0] shift_r;
reg [2:0] bit_cnt;
reg [7:0] data_read;

assign cmd_ack = cmd_done;
assign o_i2c_ack = bit_ack;
assign o_data = data_read;
always @(posedge sysclk or negedge nReset)
begin
    if (!nReset || !enable)
    begin
        bit_ack <= 0;
        bit_cmd <= CMD_IDLE;
        i_bit  <= 1'b1;
        shift_r <= 8'hff;
        bit_cnt <= 3'h7;
        cmd_done <= 0;
        c_state <= CMD_IDLE;
        data_read <= 8'hff;
    end
    else
    begin
        cmd_done <= 1'b0;
        i_bit <= shift_r[bit_cnt];
        // cmd_done <= 1'b0;
        if (bit_done)
        begin
            bit_cmd <= CMD_IDLE;
            case (c_state)
                CMD_START:
                begin
                    cmd_done <= 1'b1;
                    shift_r = i_data;
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
                        shift_r = i_data;
                    end
                end
                CMD_READ:
                begin
                    shift_r[bit_cnt] <= o_bit;
                    bit_cmd <= c_state;
                    bit_cnt <= bit_cnt - 1;
                    if (bit_cnt == 1'b0)
                    begin
                        cmd_done <= 1'b1;
                        bit_cnt <= 3'h7;
                        data_read <= shift_r;
                    end
                end
                CMD_WR_ACK:
                begin
                    cmd_done <= 1'b1;
                    bit_cnt <= 3'h7;
                    shift_r = i_data;
                end
                CMD_RD_ACK:
                begin
                    bit_ack = o_bit;
                    cmd_done <= 1'b1;
                    bit_cnt <= 3'h7;
                    shift_r = i_data;
                end
                CMD_RESTART:
                begin
                    bit_cmd <= CMD_IDLE;
                    c_state <= CMD_IDLE;
                    cmd_done <= 1'b1;
                end
                CMD_STOP:
                    begin
                        c_state <= CMD_IDLE;
                        data_read <= 8'hff;
                    end
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
                    shift_r = i_data;
                    bit_cmd <= cmd;
                end
                CMD_READ:
                begin
                    bit_cmd <= cmd;
                end
                CMD_RD_ACK:
                begin
                    bit_cnt <= 3'h7;
                    shift_r = i_data;
                    bit_cmd <= CMD_READ;
                end
                CMD_WR_ACK:
                begin
                    i_bit <= 0;
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
    .i_sysclk     (sysclk),   // system clock input
    .i_nReset     (nReset),  // sync reset
    .i_enable     (enable),   // iic enable

    .i_prescale   (prescale), // clock prescale cnt
    .i_dfsr       (dfsr),     // sample clk cnt

    .i_cmd        (bit_cmd),
    .o_cmd_ack    (bit_done),    // cmd compelete ack
    .o_busy       (o_i2c_busy),     // bus busy
    .o_arblost    (o_i2c_al),  // arbitration lost

    .i_din        (i_bit),
    .o_dout       (o_bit),

    .i_scl        (i_scl),
    .o_scl        (o_scl),
    .o_scl_oen    (scl_oen),
    .i_sda        (i_sda),
    .o_sda        (o_sda),
    .o_sda_oen    (sda_oen)
);

endmodule

