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


i2c_bit_ctl bit_controller(
    .sysclk_i   (sysclk_i),   // system clock input
    .reset_n_i  (reset_n_i),  // sync reset
    .enable_i   (enable_i),   // iic enable

    .prescale_i (prescale_i), // clock prescale cnt
    .dfsr_cnt   (dfsr_cnt), // sample clk cnt

    .cmd_i      (i2c_cmd_i),
    .cmd_ack    (cmd_ack),    // cmd compelete ack
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

