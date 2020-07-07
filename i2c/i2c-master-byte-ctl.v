`include "timescale.v"

module i2c_master_byte_ctl(
    input             sysclk_i,
    input             reset_n_i,  // sync reset

    input             enable_i,   // iic enable

    input      [15:0] prescale_i, // clock prescale cnt
    input      [15:0] dfsr_cnt,   // Digital Filter Sampling Rate cnt

    input      [2:0]  i2c_cmd_i,
    
    output            cmd_ack_o,
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
wire bit_done;
reg  cmd_done;
// reg bit_o;
reg [7:0] shift_r;
reg [2:0] bit_cnt;

assign cmd_ack_o = cmd_done;
always @(posedge sysclk_i or negedge reset_n_i)
begin
    if (!reset_n_i)
    begin
        bit_i  <= 1'b1;
        shift_r <= 8'hff;
        bit_cnt <= 3'h7;
        cmd_done <= 0;
    end
    else 
    begin
        cmd_done <= 1'b0;
        bit_i <= shift_r[bit_cnt];
        // cmd_done <= 1'b0;
        if (bit_done) 
        begin
            case (i2c_cmd_i)
                CMD_IDLE:
                begin
                    shift_r = data_i;
                end
                CMD_START:
                begin
                    cmd_done <= 1'b1;
                    shift_r = data_i;
                end
                CMD_WRITE:
                begin
                    bit_cnt <= bit_cnt - 1;
                    if (bit_cnt == 1'b0)
                        cmd_done <= 1'b1;
                end
                CMD_READ:;
                CMD_WR_ACK:;
                CMD_RD_ACK:;
                CMD_STOP:;
                default :;
            endcase
        end
    end
end


i2c_bit_ctl bit_controller(
    .sysclk_i   (sysclk_i),   // system clock input
    .reset_n_i  (reset_n_i),  // sync reset
    .enable_i   (enable_i),   // iic enable

    .prescale_i (prescale_i), // clock prescale cnt
    .dfsr_cnt   (dfsr_cnt), // sample clk cnt

    .cmd_i      (i2c_cmd_i),
    .cmd_ack    (bit_done),    // cmd compelete ack
    .busy_o     (busy_o),     // bus busy
    .arblost_o  (arblost_o),  // arbitration lost
 
    .bit_i      (bit_i),
    .bit_o      (bit_o),

    .scl_i      (scl_i),
    .scl_o      (scl_o),
    .scl_oen    (scl_oen),
    .sda_i      (sda_i),
    .sda_o      (sda_o),
    .sda_oen    (sda_oen)
    );

endmodule

