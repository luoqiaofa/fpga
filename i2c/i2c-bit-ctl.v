`include "timescale.v"

module i2c_bit_ctl(
    input          i_sysclk,   // system clock input
    input          i_nReset,   // sync reset
    input          i_enable,   // iic i_enable

    input [15:0]   i_prescale, // clock i_prescale s_
    input [5:0]    i_dfsr,     // sample clk cnt

    input [3:0]    i_cmd,
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

(* keep = "true" *) reg [3:0] s_bit_cmd;
(* keep = "true" *) reg [4:0] s_c_state;
(* keep = "true" *) reg [4:0] s_c_state_pre;
(* keep = "true" *) reg s_clk_en;
reg s_sda_chk;
reg s_dSCL;
reg s_dSDA;
reg s_sda_chk_al;
reg s_sta_sto_sda_al;
reg s_sta_sto_scl_al;

reg [1:0] s_cSCL, s_cSDA;
reg [2:0] s_fSCL, s_fSDA;      // SCL and SDA filter inputs

(* keep = "true" *) wire s_clk_div4;
reg [1:0] div4_clk_edge;
clk_divn #(.CLK_DIVN_WIDTH(16))
clk_divn_inst2 (
    .i_clk(i_sysclk),
    .i_resetn(i_nReset & i_enable),
    .i_divn({2'b0, i_prescale[15:2]}),
    .o_clk(s_clk_div4)
);

always @(posedge i_sysclk)
begin
    if (!i_nReset) begin
        s_fSCL   <= 3'b111;
        s_fSDA   <= 3'b111;
        s_cSCL   <= 2'b00;
        s_cSDA   <= 2'b00;
    end
    else begin
        if (s_clk_en) begin
            s_cSCL   <= {s_cSCL[0], i_scl};
            s_cSDA   <= {s_cSDA[0], i_sda};
            s_fSCL <= {s_fSCL[1:0],  i_scl};
            s_fSDA <= {s_fSDA[1:0],  i_sda};
        end
    end
end

always @(posedge i_sysclk)
begin
    if (!i_nReset) begin
        o_busy    <= 1'b0;
        o_arblost <= 1'b0;
        s_dSCL   <= 1'b1;
        s_dSDA   <= 1'b1;

        s_sda_chk_al     <= 0;
        s_sta_sto_sda_al <= 0;
        s_sta_sto_scl_al <= 0;
    end
    else  begin
        s_dSCL = (&s_cSCL) & i_scl;
        if (~s_cSCL[1] & s_cSCL[0]) begin
            s_dSDA = (&s_cSDA) & i_sda;
        end
        o_busy <= ~((&s_fSCL) & (&s_fSDA) & (i_sda & i_scl));
        o_arblost <= s_sda_chk_al | s_sta_sto_sda_al | s_sta_sto_scl_al;
        if (s_sda_chk & o_sda_oen) begin
            s_sda_chk_al <= (~i_sda);
        end
        else begin
            if ((CMD_START == s_bit_cmd) ||
                (CMD_RESTART == s_bit_cmd) ||
                (CMD_STOP == s_bit_cmd)) begin
                if (o_sda_oen) begin
                    s_sta_sto_sda_al <= (~i_sda);
                end
                if (o_scl_oen) begin
                    s_sta_sto_scl_al <= (~i_scl);
                end
            end
        end
    end
end

// always @(posedge )
always @(posedge i_sysclk)
begin
    if (!i_nReset) begin
        s_clk_en <= 1'b0;
        div4_clk_edge <= {s_clk_div4,  s_clk_div4};
    end
    else begin
        div4_clk_edge <= {div4_clk_edge[0], s_clk_div4};
        if (i_enable) begin
            if (2'b01 == div4_clk_edge) begin
                s_clk_en <= 1;
            end
        end
        else begin
            s_clk_en <= 1'b0;
        end
        if (s_clk_en) begin
            s_clk_en <= 1'b0;
        end
    end
end

always @(posedge i_sysclk)
begin
    if (!i_nReset) begin
        o_scl_oen <= 1'b1;
        o_sda_oen <= 1'b1;
        s_sda_chk <= 1'b0;
        o_cmd_ack <= 1'b0;
        s_c_state <= B_IDLE;
        s_c_state_pre <= B_IDLE;
        s_bit_cmd <= CMD_IDLE;
    end
    else if (!i_enable) begin
        o_scl_oen <= 1'b1;
        o_sda_oen <= 1'b1;
        s_sda_chk <= 1'b0;
        o_cmd_ack <= 1'b0;
        s_c_state <= B_IDLE;
        s_c_state_pre <= B_IDLE;
        s_bit_cmd <= CMD_IDLE;
    end
    else begin
        o_cmd_ack <= 1'b0;
        s_c_state_pre <= s_c_state;
        if (B_IDLE == s_c_state_pre) begin
            s_bit_cmd <= i_cmd;
            case (i_cmd)
                CMD_IDLE   :s_c_state <= B_IDLE;
                CMD_START  :s_c_state <= B_START_A;
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

assign o_dout = s_dSDA;

endmodule

