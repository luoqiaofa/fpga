`include "timescale.v"

module i2c_master_byte_ctl(
    input             sysclk_i,
    input             reset_n_i,  // sync reset
    input             nRst_i,     // async reset

    input      [15:0] prescale_i, // clock prescale cnt
    input      [15:0] dfsr_cnt,   // Digital Filter Sampling Rate cnt

    input             enable_i,   // iic enable
    input      [3:0]  i2c_cmd_i,
    
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


endmodule

