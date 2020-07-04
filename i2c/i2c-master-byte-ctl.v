`include "timescale.v"

module i2c_master_byte_ctl(
    input          sysclk_i,
    input          reset_n_i, // sync reset
    input          nRst_i,    // async reset

    input [15:0]   prescale_i, // clock prescale cnt
    input [ 7:0]   filter_cnt, // sample clk cnt

    input          enable_i,  // iic enable
    input   [3:0]  cmd_i,
    
    output         cmd_ack_o,
    output         i2c_ack_o,
    output         arbloss_o,

    input          scl_i,
    output         scl_o,
    output         scl_oen,
    input          sda_i,
    output         sda_o,
    output         sda_oen,
);
`include "i2c-reg-def.v"


endmodule

