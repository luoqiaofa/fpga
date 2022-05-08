`timescale 1 ns / 1 ps

module common_module
#(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    // Width of S_AXI address bus
    parameter integer C_S_AXI_ADDR_WIDTH = 12
)
(
    input  wire  S_AXI_ACLK,
    input  wire  S_AXI_ARESETN,
    input  wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    input  wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    input  wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    
    input  wire common_reg_wren,
    input  wire common_reg_rden,
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] common_reg_data
);

`include "../spi/reg-bit-def.v"
`include "reg_ranges_def.v"
`include "version.v"

reg [C_S_AXI_DATA_WIDTH-1 : 0] reg_out;
reg [C_S_AXI_DATA_WIDTH-1 : 0] reg_test1;
reg [C_S_AXI_DATA_WIDTH-1 : 0] reg_test2;

assign common_reg_data = reg_out;

always @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN)
begin
    if (1'b0 == S_AXI_ARESETN) begin
        reg_test1 <= 0;
        reg_test2 <= 0;
    end
    else begin
        if (common_reg_wren) begin
            case (S_AXI_AWADDR[7:2])
                6'h02   : reg_test1 <= S_AXI_WDATA;
                6'h03   : reg_test2 <= S_AXI_WDATA;
                default : ;
            endcase
        end
    end
end

always @(*)
// always @(posedge common_reg_rden)
begin
    if (S_AXI_ARADDR[11:8] == C_COMMON_BASE) begin
        case (S_AXI_ARADDR[7:2])
            6'h00   : reg_out <= `COMPILE_DATE;
            6'h01   : reg_out <= `COMPILE_TIME;
            6'h02   : reg_out <= reg_test1;
            6'h03   : reg_out <= ~reg_test2;
            default : reg_out <= 0;
        endcase
    end
end

endmodule

