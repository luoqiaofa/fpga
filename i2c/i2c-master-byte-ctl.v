`include "timescale.v"

module i2c_master_byte_ctl(
    input             i_sysclk,
    input             i_nReset,   // sync reset

    input             i_enable,   // iic enable

    input      [15:0] i_prescale, // clock prescale cnt
    input      [5:0]  i_dfsr,     // Digital Filter Sampling Rate cnt

    input             i_cmd_trig,
    input      [3:0]  i_cmd,

    output            o_cmd_ack,
    output            o_i2c_ack,
    output            o_i2c_al,   // arbitration lost output
    output            o_i2c_busy, // i2c bus busy output

    input      [7:0]  i_data,
    output     [7:0]  o_data,

    input             i_scl,
    output            o_scl,
    output            o_scl_oen,
    input             i_sda,
    output            o_sda,
    output            o_sda_oen
);
`include "i2c-def.v"
`include "i2c-reg-def.v"

reg  s_i_bit;
reg  [3:0] s_bit_cmd;
reg  [3:0] s_c_state;
wire s_bit_done;
reg  s_cmd_done;
wire s_o_bit;
reg  s_bit_ack;
reg [7:0] s_shift_r;
reg [2:0] s_bit_cnt;
reg [7:0] s_data_read;

assign o_cmd_ack = s_cmd_done;
assign o_i2c_ack = s_bit_ack;
assign o_data    = s_data_read;
always @(posedge i_sysclk or negedge i_nReset)
begin
    if (!i_nReset || !i_enable) begin
        s_bit_ack   <= 0;
        s_bit_cmd   <= CMD_IDLE;
        s_i_bit     <= 1'b1;
        s_shift_r   <= 8'hff;
        s_bit_cnt   <= 3'h7;
        s_cmd_done  <= 0;
        s_c_state   <= CMD_IDLE;
        s_data_read <= 8'hff;
    end
    else begin
        s_bit_cmd  <= CMD_IDLE;
        s_cmd_done <= 1'b0;
        s_i_bit    <= s_shift_r[s_bit_cnt];
        if (s_bit_done) begin
            case (s_c_state)
                CMD_START: begin
                    s_cmd_done <= 1'b1;
                    s_shift_r  <= i_data;
                    s_bit_cnt  <= 3'h7;
                end
                CMD_WRITE: begin
                    s_bit_cmd <= s_c_state;
                    s_bit_cnt <= s_bit_cnt - 1;
                    if (s_bit_cnt == 1'b0) begin
                        s_cmd_done <= 1'b1;
                        s_bit_cnt  <= 3'h7;
                        s_shift_r  <= i_data;
                    end
                end
                CMD_READ: begin
                    s_shift_r[s_bit_cnt] <= s_o_bit;
                    s_bit_cmd <= s_c_state;
                    s_bit_cnt <= s_bit_cnt - 1;
                    if (s_bit_cnt == 1'b0) begin
                        s_cmd_done  <= 1'b1;
                        s_bit_cnt   <= 3'h7;
                        s_data_read <= s_shift_r;
                    end
                end
                CMD_WR_ACK: begin
                    s_cmd_done <= 1'b1;
                    s_bit_cnt  <= 3'h7;
                    s_shift_r  <= i_data;
                end
                CMD_WR_NAK: begin
                    s_cmd_done <= 1'b1;
                    s_c_state  <= CMD_STOP;
                end
                CMD_RD_ACK: begin
                    s_bit_ack  <= s_o_bit;
                    s_cmd_done <= 1'b1;
                    s_bit_cnt  <= 3'h7;
                    s_shift_r  <= i_data;
                end
                CMD_RESTART: begin
                    s_c_state  <= CMD_IDLE;
                    s_cmd_done <= 1'b1;
                end
                CMD_STOP: begin
                    s_cmd_done  <= 1'b1;
                    s_c_state   <= CMD_IDLE;
                    s_data_read <= 8'hff;
                end
                default : ;
            endcase
        end
        if (i_cmd_trig) begin
            s_c_state <= i_cmd;
            case (i_cmd)
                CMD_IDLE: begin
                    s_bit_cmd <= i_cmd;
                end
                CMD_START: begin
                    s_bit_cmd <= i_cmd;
                end
                CMD_WRITE: begin
                    s_shift_r <= i_data;
                    s_bit_cmd <= i_cmd;
                end
                CMD_READ: begin
                    s_bit_cmd <= i_cmd;
                end
                CMD_RD_ACK: begin
                    s_bit_cnt <= 3'h7;
                    s_shift_r <= i_data;
                    s_bit_cmd <= CMD_READ;
                end
                CMD_WR_ACK: begin
                    s_i_bit   <= 0;
                    s_bit_cmd <= CMD_WRITE;
                end
                CMD_WR_NAK: begin
                    s_i_bit   <= 1;
                    s_bit_cmd <= CMD_WRITE;
                end
                CMD_RESTART: begin
                    s_bit_cmd <= CMD_RESTART;
                end
                CMD_STOP: begin
                    s_bit_cmd <= CMD_STOP;
                end
                default :;
            endcase
        end
    end
end

i2c_bit_ctl bit_controller(
    .i_sysclk     (i_sysclk),   // system clock input
    .i_nReset     (i_nReset),  // sync reset
    .i_enable     (i_enable),   // iic enable

    .i_prescale   (i_prescale), // clock prescale cnt
    .i_dfsr       (i_dfsr),     // sample clk cnt

    .i_cmd        (s_bit_cmd),
    .o_cmd_ack    (s_bit_done),    // i_cmd compelete ack
    .o_busy       (o_i2c_busy),     // bus busy
    .o_arblost    (o_i2c_al),  // arbitration lost

    .i_din        (s_i_bit),
    .o_dout       (s_o_bit),

    .i_scl        (i_scl),
    .o_scl        (o_scl),
    .o_scl_oen    (o_scl_oen),
    .i_sda        (i_sda),
    .o_sda        (o_sda),
    .o_sda_oen    (o_sda_oen)
);

endmodule

