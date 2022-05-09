`timescale 1 ns / 1 ps

module i2c_inf
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
    
    input  wire i2c_reg_wren,
    input  wire i2c_reg_rden,
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] i2c_reg_data
);

`include "reg_ranges_def.v"
`include "../i2c/i2c-reg-def.v"

reg [7:0] I2CADR;
reg [7:0] I2CFDR;
reg [7:0] I2CCR;
reg [7:0] I2CSR;
reg [7:0] I2CDR;
reg [7:0] I2CDFSRR;

reg [C_S_AXI_DATA_WIDTH-1 : 0] reg_out;

assign i2c_reg_data = reg_out;

always @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN)
begin
    if (1'b0 == S_AXI_ARESETN) begin
        I2CADR   <= 8'h00;
        I2CFDR   <= 8'h00;
        I2CCR    <= 8'h00;
        I2CSR    <= 8'h81;
        I2CDR    <= 8'h00;
        I2CDFSRR <= 8'h10;
    end
    else begin
        if (i2c_reg_wren)
        begin
            case (S_AXI_AWADDR[7:2])
                ADDR_ADR  : I2CADR   <= S_AXI_WDATA[7:0];
                ADDR_FDR  : I2CFDR   <= S_AXI_WDATA[7:0];
                ADDR_CR   : I2CCR    <= S_AXI_WDATA[7:0];
                ADDR_SR   : I2CSR    <= S_AXI_WDATA[7:0];
                ADDR_DR   : I2CDR    <= S_AXI_WDATA[7:0];
                ADDR_DFSRR: I2CDFSRR <= S_AXI_WDATA[7:0];
                default : ;
            endcase
        end
    end
end

always @(*)
// always @(posedge i2c_reg_rden)
begin
    if (S_AXI_ARADDR[11:8] == C_I2C_BASE) begin
        case (S_AXI_ARADDR[7:2])
            ADDR_ADR  : reg_out <= {{24{1'b0}}, I2CADR};
            ADDR_FDR  : reg_out <= {{24{1'b0}}, I2CFDR};
            ADDR_CR   : reg_out <= {{24{1'b0}}, I2CCR};
            ADDR_SR   : reg_out <= {{24{1'b0}}, I2CSR};
            ADDR_DR   : reg_out <= {{24{1'b0}}, I2CDR};
            ADDR_DFSRR: reg_out <= {{24{1'b0}}, I2CDFSRR};
            default : reg_out <= 0;
        endcase
    end
end

endmodule

