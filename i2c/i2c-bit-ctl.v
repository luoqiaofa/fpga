`include "timescale.v"

module i2c_bit_ctl(
    input          i_sysclk,   // system clock input
    input          i_nReset,   // sync reset
    input          i_enable,   // iic i_enable

    input [15:0]   i_prescale, // clock i_prescale s_
    input [5:0]    i_dfsr,     // sample clk cnt

    input [2:0]    i_cmd,
    output reg     o_cmd_ack,  // i_cmd compelete ack
    output reg     o_busy,     // bus o_busy
    output reg     o_arblost,  // arbitration lost

    input          i_din,
    output         o_dout,

    input          i_scl,
    output         o_scl,
    output reg     o_scl_oen,
    input          i_sda,
    output         o_sda,
    output reg     o_sda_oen
);
`include "i2c-def.v"

reg [4:0]  s_c_state;
reg [15:0] s_cnt;
reg s_clk_en;
reg s_sda_chk;
reg s_sSda;

wire s_state_clk_div4;
clk_divn #(.CLK_DIVN_WIDTH(16))
clk_divn_inst2 (
    .i_clk(i_sysclk),
    .i_resetn(i_nReset),
    .i_divn({2'b0, i_prescale[15:2]}),
    .o_clk(s_state_clk_div4)
);

always @(posedge i_sysclk or negedge i_nReset)
begin
    if (!i_nReset) begin
        s_clk_en <= 1'b0;
    end
    else  begin
        s_clk_en <= 1'b0;
        if (o_sda_oen) begin
            s_sSda <= i_sda;
        end
    end
end

always @(posedge s_state_clk_div4)
begin
    if (i_enable) begin
        s_clk_en <= 1;
    end
    else begin
        s_clk_en <= 1'b0;
    end
end


always @(posedge i_sysclk or negedge i_nReset)
begin
    if (!i_nReset) begin
        o_scl_oen <= 1'b1;
        o_sda_oen <= 1'b1;
        s_sda_chk <= 1'b0;
        o_cmd_ack <= 1'b0;
        o_busy    <= 1'b0;
        o_arblost <= 1'b0;
        s_c_state <= B_IDLE;
    end
    else if (!i_enable) begin
        o_scl_oen <= 1'b1;
        o_sda_oen <= 1'b1;
        s_sda_chk <= 1'b0;
        o_cmd_ack <= 1'b0;
        o_busy    <= 1'b0;
        o_arblost <= 1'b0;
        s_c_state <= B_IDLE;
    end
    else begin
        o_cmd_ack <= 1'b0;
        if (B_IDLE == s_c_state) begin
            case (i_cmd)
                CMD_IDLE   :s_c_state <= B_IDLE;
                CMD_START  :s_c_state <= B_START_B;
                CMD_STOP   :s_c_state <= B_STOP_A;
                CMD_WRITE  :s_c_state <= B_WRITE_A;
                CMD_READ   :s_c_state <= B_READ_A;
                CMD_RESTART:s_c_state <= B_RESTART_A;
                default    :s_c_state <= s_c_state;
            endcase
            o_scl_oen <= o_scl_oen;
            o_sda_oen <= o_sda_oen;
            s_sda_chk <= 1'b0;
        end
        else if (s_clk_en) begin
            case (s_c_state)
                B_START_A : begin
                    s_c_state <= B_START_B;
                    o_scl_oen <= o_scl_oen;
                    o_sda_oen <= 1'b1;
                    s_sda_chk <= 1'b0;
                end
                B_START_B : begin
                    s_c_state <= B_START_C;
                    o_scl_oen <= 1'b1;
                    o_sda_oen <= 1'b1;
                    s_sda_chk <= 1'b0;
                end
                B_START_C : begin
                    s_c_state <= B_START_D;
                    o_scl_oen <= 1'b1;
                    o_sda_oen <= 1'b0;
                    s_sda_chk <= 1'b0;
                end
                B_START_D : begin
                    s_c_state <= B_START_E;
                    o_scl_oen <= 1'b1;
                    o_sda_oen <= 1'b0;
                    s_sda_chk <= 1'b0;
                end
                B_START_E : begin
                    s_c_state <= B_IDLE;
                    o_cmd_ack <= 1'b1;
                    o_scl_oen <= 1'b0;
                    o_sda_oen <= 1'b0;
                    s_sda_chk <= 1'b0;
                end

                B_STOP_A  : begin
                    s_c_state <= B_STOP_B;
                    o_scl_oen <= 1'b0;
                    o_sda_oen <= 1'b0;
                    s_sda_chk <= 1'b0;
                end
                B_STOP_B  : begin
                    s_c_state <= B_STOP_C;
                    o_scl_oen <= 1'b1;
                    o_sda_oen <= 1'b0;
                    s_sda_chk <= 1'b0;
                end
                B_STOP_C  : begin
                    s_c_state <= B_STOP_D;
                    o_scl_oen <= 1'b1;
                    o_sda_oen <= 1'b1;
                    s_sda_chk <= 1'b1;
                end
                B_STOP_D  : begin
                    s_c_state <= B_IDLE;
                    o_scl_oen <= 1'b1;
                    o_sda_oen <= 1'b1;
                    o_cmd_ack <= 1'b1;
                    s_sda_chk <= 1'b0;
                end

                B_READ_A  : begin
                    s_c_state <= B_READ_B;
                    o_scl_oen <= 1'b0;
                    o_sda_oen <= 1'b1;
                    s_sda_chk <= 1'b0;
                end
                B_READ_B  : begin
                    s_c_state <= B_READ_C;
                    o_scl_oen <= 1'b1;
                    o_sda_oen <= 1'b1;
                    s_sda_chk <= 1'b0;
                end
                B_READ_C  : begin
                    s_c_state <= B_READ_D;
                    o_scl_oen <= 1'b1;
                    o_sda_oen <= 1'b1;
                    s_sda_chk <= 1'b0;
                end
                B_READ_D  : begin
                    s_c_state <= B_IDLE;
                    o_cmd_ack <= 1'b1;
                    o_scl_oen <= 1'b0;
                    o_sda_oen <= 1'b1;
                    s_sda_chk <= 1'b0;
                end

                B_WRITE_A : begin
                    s_c_state <= B_WRITE_B;
                    o_scl_oen <= 1'b0;
                    o_sda_oen <= i_din;
                    s_sda_chk <= 1'b0;
                end
                B_WRITE_B : begin
                    s_c_state <= B_WRITE_C;
                    o_scl_oen <= 1'b1;
                    o_sda_oen <= i_din;
                    s_sda_chk <= 1'b0;
                end
                B_WRITE_C : begin
                    s_c_state <= B_WRITE_D;
                    o_scl_oen <= 1'b1;
                    o_sda_oen <= i_din;
                    s_sda_chk <= 1'b1;
                end
                B_WRITE_D : begin
                    s_c_state <= B_IDLE;
                    o_cmd_ack <= 1'b1;
                    o_scl_oen <= 1'b0;
                    o_sda_oen <= i_din;
                    s_sda_chk <= 1'b0;
                end

                B_RESTART_A : begin
                    s_c_state <= B_RESTART_B;
                    o_scl_oen <= 1'b0;
                    o_sda_oen <= 1'b1;
                    s_sda_chk <= 1'b0;
                end
                B_RESTART_B : begin
                    s_c_state <= B_RESTART_C;
                    o_scl_oen <= 1'b1;
                    o_sda_oen <= 1'b1;
                    s_sda_chk <= 1'b0;
                end
                B_RESTART_C : begin
                    s_c_state <= B_RESTART_D;
                    o_scl_oen <= 1'b1;
                    o_sda_oen <= 1'b0;
                    s_sda_chk <= 1'b1;
                end
                B_RESTART_D : begin
                    s_c_state <= B_IDLE;
                    o_cmd_ack <= 1'b1;
                    o_scl_oen <= 1'b0;
                    o_sda_oen <= 1'b0;
                    s_sda_chk <= 1'b0;
                end

                default : s_c_state <= B_IDLE;
            endcase
        end /* else if (s_clk_en) */
    end
end

assign o_scl = o_scl_oen;
assign o_sda = o_sda_oen;

assign o_dout = s_sSda;

endmodule

