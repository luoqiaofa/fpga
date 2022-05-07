module cpu_inf_common
#(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    // Width of S_AXI address bus
    parameter integer C_S_AXI_ADDR_WIDTH = 12
)
(
    // Global Clock Signal
    input wire  S_AXI_ACLK,
    // Global Reset Signal. This Signal is Active LOW
    input wire  S_AXI_ARESETN,

    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    // Write strobes. This signal indicates which byte lanes hold
        // valid data. There is one write strobe bit for each eight
        // bits of the write data bus.
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    input  wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    
    input  wire slv_reg_wren,
    input  wire slv_reg_rden,

    output wire common_reg_wren,
    output wire common_reg_rden,
    input  wire [C_S_AXI_DATA_WIDTH-1 : 0] common_reg_data,

    output wire gpio_reg_wren,
    output wire gpio_reg_rden,
    input  wire [C_S_AXI_DATA_WIDTH-1 : 0] gpio_reg_data,

    output wire pwm_reg_wren,
    output wire pwm_reg_rden,
    input  wire [C_S_AXI_DATA_WIDTH-1 : 0] pwm_reg_data,

    output wire i2c_reg_wren,
    output wire i2c_reg_rden,
    input  wire [C_S_AXI_DATA_WIDTH-1 : 0] i2c_reg_data,

    output wire spi_reg_wren,
    output wire spi_reg_rden,
    input  wire [C_S_AXI_DATA_WIDTH-1 : 0] spi_reg_data
);
`include "reg_ranges_def.v"
`include "../spi/reg-bit-def.v"
`include "version.v"

assign common_reg_wren = S_AXI_AWADDR[11:8] == C_COMMON_BASE ?  slv_reg_wren : 0;
assign common_reg_rden = S_AXI_ARADDR[11:8] == C_COMMON_BASE ?  slv_reg_rden : 0;
assign gpio_reg_wren   = S_AXI_AWADDR[11:8] == C_GPIO_BASE   ?  slv_reg_wren : 0;
assign gpio_reg_rden   = S_AXI_ARADDR[11:8] == C_GPIO_BASE   ?  slv_reg_rden : 0;
assign pwm_reg_wren    = S_AXI_AWADDR[11:8] == C_PWM_BASE    ?  slv_reg_wren : 0;
assign pwm_reg_rden    = S_AXI_ARADDR[11:8] == C_PWM_BASE    ?  slv_reg_rden : 0;
assign i2c_reg_wren    = S_AXI_AWADDR[11:8] == C_I2C_BASE    ?  slv_reg_wren : 0;
assign i2c_reg_rden    = S_AXI_ARADDR[11:8] == C_I2C_BASE    ?  slv_reg_rden : 0;
assign spi_reg_wren    = S_AXI_AWADDR[11:8] == C_SPI_BASE    ?  slv_reg_wren : 0;
assign spi_reg_rden    = S_AXI_ARADDR[11:8] == C_SPI_BASE    ?  slv_reg_rden : 0;

reg [C_S_AXI_DATA_WIDTH-1 : 0] reg_out;
assign S_AXI_RDATA = reg_out;

always @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN)
begin
    if (1'b0 == S_AXI_ARESETN) begin
        reg_out <= 0;
    end
    else begin
        if (slv_reg_rden) begin
            case (S_AXI_ARADDR[11:8])
                C_COMMON_BASE: reg_out <= common_reg_data;
                C_GPIO_BASE  : reg_out <= gpio_reg_data;
                C_PWM_BASE   : reg_out <= pwm_reg_data;
                C_I2C_BASE   : reg_out <= i2c_reg_data;
                C_SPI_BASE   : reg_out <= spi_reg_data;
                default      : reg_out <= 0;
            endcase
        end
    end
end

endmodule

