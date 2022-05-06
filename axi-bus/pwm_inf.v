module pwm_inf
#(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    // Width of S_AXI address bus
    parameter integer C_S_AXI_ADDR_WIDTH = 12
)
(
    output wire pwm_out,
    input  wire  S_AXI_ACLK,
    input  wire  S_AXI_ARESETN,
    input  wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    input  wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    input  wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    
    input  wire pwm_reg_wren,
    input  wire pwm_reg_rden,
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] pwm_reg_data
);

reg [31:0] PWM_MODE;
reg [31:0] PWM_DIVIDER;
reg [31:0] PWM_DUTY;
reg [31:0] PWM_BRIGHTNESS;
reg [C_S_AXI_DATA_WIDTH-1 : 0] reg_out;

assign pwm_reg_data = reg_out;

always @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN)
begin
    if (1'b0 == S_AXI_ARESETN) begin
        reg_out <= 0;
        PWM_MODE       <= 0;
        // default 1 KHz
        PWM_DIVIDER    <= 32'h000186a0;
        PWM_DUTY       <= 32'h0000c350;
        PWM_BRIGHTNESS <= 128;
    end
end

always @(posedge pwm_reg_rden)
begin
    case (S_AXI_ARADDR[7:2])
        0 : reg_out <= PWM_MODE;
        1 : reg_out <= PWM_DIVIDER;
        2 : reg_out <= PWM_DUTY;
        3 : reg_out <= PWM_BRIGHTNESS;
        default : reg_out <= 0;
    endcase
end

always @(posedge pwm_reg_wren)
begin
    case (S_AXI_AWADDR[7:2])
        0 : PWM_MODE       <= S_AXI_WDATA;
        1 : PWM_DIVIDER    <= S_AXI_WDATA;
        2 : PWM_DUTY       <= S_AXI_WDATA;
        3 : PWM_BRIGHTNESS <= S_AXI_WDATA;
        default : ;
    endcase
end

pwm_module
#(
	.C_DATA_WIDTH(C_S_AXI_DATA_WIDTH) //pwm bit width
)
pwm_inst
(
    .i_sysclk(S_AXI_ACLK),
    .i_resetn(S_AXI_ARESETN),
    .i_enable(PWM_MODE[0]),
    .i_polar(PWM_MODE[1]),
    .i_freq_cnt(PWM_DIVIDER),
    .i_duty_cnt(PWM_DUTY),
    .i_brightness(PWM_BRIGHTNESS[7:0]),
    .o_pwm_out(pwm_out)
    );

endmodule

