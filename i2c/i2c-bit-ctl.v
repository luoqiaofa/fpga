`include "timescale.v"

module i2c_bit_ctl(
    input          sysclk_i,   // system clock input
    input          reset_n_i,  // sync reset
    input          enable_i,   // iic enable
    input          nRst_i,     // async reset

    input [15:0]   prescale_i, // clock prescale cnt
    input [ 7:0]   filter_cnt, // sample clk cnt

    input [3:0]    cmd_i,
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

endmodule
