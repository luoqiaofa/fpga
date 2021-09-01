`include "timescale.v"
module tb_msbyte();
`include "i2c-def.v"
`include "i2c-reg-def.v"
    reg s_sysclk;
    reg s_nReset;
    reg s_enable;
    reg [15:0] s_prescale;
    reg [5:0]  s_dfsr;
    reg        s_cmd_trig;
    reg [3:0]  s_cmd;
    wire       s_cmd_ack;
    wire       s_i2c_ack;
    wire       s_i2c_al;
    wire       s_i2c_busy;
    reg  [7:0] s_data_in;
    wire [7:0] s_data_out;
    reg        s_scl_i;
    wire       s_scl_o;
    wire       s_scl_oen;
    reg        s_sda_i;
    wire       s_sda_o;
    wire       s_sda_oen;
    

localparam C_SM_IDLE     = 4'h0;
localparam C_SM_START    = 4'h1;
localparam C_SM_WR_WADDR = 4'h2;
localparam C_SM_RD_ACK1  = 4'h3;
localparam C_SM_WR_DATA  = 4'h4;
localparam C_SM_RD_ACK2  = 4'h5;
localparam C_SM_RESTART  = 4'h6;
localparam C_SM_WR_RADDR = 4'h7;
localparam C_SM_RD_ACK3  = 4'h8;
localparam C_SM_RD_DATA1 = 4'h9;
localparam C_SM_WR_ACK   = 4'ha;
localparam C_SM_RD_DATA2 = 4'hb;
localparam C_SM_STOP     = 4'hc;

reg [3:0] s_xfer_state;

initial
begin
$dumpfile("wave.vcd");    //生成的vcd文件名称
$dumpvars(0);   //tb模块名称
end

initial
begin
    s_xfer_state <= C_SM_IDLE;
    s_sysclk <= 0;
    s_nReset <= 0;
    s_enable <= 0;
    s_prescale <= 16'd1024;
    s_dfsr     <= 6'h10;
    s_cmd_trig <= 0;
    s_cmd      <= CMD_IDLE;
    s_data_in  <= 8'ha0;
    s_scl_i    <= 1;
    s_sda_i    <= 1;
    #35;
    s_nReset <= 1;
    #20;
    s_enable <= 1;
    s_cmd        <= CMD_START;
    s_xfer_state <= C_SM_START;
    #1005;
    s_cmd_trig <= 1;
    #550000;
    s_enable <= 0;
    #100000;
    s_nReset <= 0;
    #100000;
    $stop;
    $finish;
end

always @(posedge s_sysclk or negedge s_nReset)
begin
    if (!s_nReset) begin
        s_cmd_trig <= 0;
    end
    else begin
        if (s_cmd_trig) begin
            s_cmd_trig <= 0;
        end
    end
end

always @(posedge s_cmd_ack)
begin
    s_cmd_trig <= 1;
    case (s_xfer_state) 
        C_SM_START    : begin
            s_data_in    <= 8'ha0;
            s_cmd        <= CMD_WRITE;
            s_xfer_state <= C_SM_WR_WADDR;
        end
        C_SM_WR_WADDR : begin
            s_cmd        <= CMD_RD_ACK ;
            s_xfer_state <= C_SM_RD_ACK1;
        end
        C_SM_RD_ACK1  : begin
            s_data_in    <= 8'h55;
            s_cmd        <= CMD_WRITE ;
            s_xfer_state <= C_SM_WR_DATA;
        end
        C_SM_WR_DATA  : begin
            s_cmd        <= CMD_RD_ACK;
            s_xfer_state <= C_SM_RD_ACK2;
        end
        C_SM_RD_ACK2  : begin
            s_cmd        <= CMD_RESTART;
            s_xfer_state <= C_SM_RESTART;
        end
        C_SM_RESTART  : begin
            s_data_in    <= 8'ha1;
            s_cmd        <= CMD_WRITE;
            s_xfer_state <= C_SM_WR_RADDR;
        end
        C_SM_WR_RADDR : begin
            s_cmd        <= CMD_RD_ACK;
            s_xfer_state <= C_SM_RD_ACK3;
        end
        C_SM_RD_ACK3  : begin
            s_cmd        <= CMD_READ;
            s_xfer_state <= C_SM_RD_DATA1;
        end
        C_SM_RD_DATA1 : begin
            s_cmd        <= CMD_WR_ACK;
            s_xfer_state <= C_SM_WR_ACK;
        end
        C_SM_WR_ACK   : begin
            s_cmd        <= CMD_READ;
            s_xfer_state <= C_SM_RD_DATA2 ;
        end
        C_SM_RD_DATA2 : begin
            s_cmd        <= CMD_STOP;
            s_xfer_state <= C_SM_STOP ;
        end
        C_SM_STOP     : begin
            s_cmd        <= CMD_IDLE;
            s_xfer_state <= C_SM_IDLE ;
        end
        default : s_cmd <= CMD_IDLE;
    endcase
end

always #5 s_sysclk = ~s_sysclk;

i2c_master_byte_ctl ms_byte_inst(
    .i_sysclk(s_sysclk),
    .i_nReset(s_nReset),   // .sync() .reset()
    .i_enable(s_enable),   // .iic() .enable()
    .i_prescale(s_prescale), // .clock() .prescale() .cnt()
    .i_dfsr(s_dfsr),
    .i_cmd_trig(s_cmd_trig),
    .i_cmd(s_cmd),
    .o_cmd_ack(s_cmd_ack),
    .o_i2c_ack(s_i2c_ack),
    .o_i2c_al(s_i2c_al),   // .arbitration() .lost() .output()
    .o_i2c_busy(s_i2c_busy), // .i2c() .bus() .busy() .output()
    .i_data(s_data_in),
    .o_data(s_data_out),
    .i_scl(s_scl_i),
    .o_scl(s_scl_o),
    .o_scl_oen(s_scl_oen),
    .i_sda(s_sda_i),
    .o_sda(s_sda_o),
    .o_sda_oen(s_sda_oen)
);
endmodule

