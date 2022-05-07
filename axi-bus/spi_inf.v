module spi_inf
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
    
    input  wire spi_reg_wren,
    input  wire spi_reg_rden,
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] spi_reg_data
);

`include "../spi/reg-bit-def.v"
`include "./reg_ranges_def.v"
`include "version.v"

reg [31: 0] SPMODE;
reg [31: 0] SPIE;
reg [31: 0] SPIM;
reg [31: 0] SPCOM;
reg [31: 0] SPITF;
reg [31: 0] SPIRF;

reg [C_S_AXI_DATA_WIDTH-1 : 0] reg_out;

assign spi_reg_data = reg_out;

always @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN)
begin
    if (1'b0 == S_AXI_ARESETN) begin
        reg_out <= 0;
        SPMODE  <= SPMODE_DEF;
        SPIE    <= SPIE_DEF;
        SPIM    <= SPIM_DEF;
        SPCOM   <= SPCOM_DEF;
        SPITF   <= SPITF_DEF;
        SPIRF   <= SPIRF_DEF;
    end
    else begin
        if (spi_reg_wren) begin
            case (S_AXI_AWADDR[7:2])
                ADDR_SPMODE[7:2] : SPMODE <= S_AXI_WDATA;
                ADDR_SPIE[7:2]   : SPIE   <= S_AXI_WDATA;
                ADDR_SPIM[7:2]   : SPIM   <= S_AXI_WDATA;
                ADDR_SPCOM[7:2]  : SPCOM  <= S_AXI_WDATA;
                ADDR_SPITF[7:2]  : SPITF  <= S_AXI_WDATA;
                default : ;
            endcase
        end
    end
end

always @(*)
begin
    if (S_AXI_ARADDR[11:8] == C_SPI_BASE)
    begin
        case (S_AXI_ARADDR[7:2])
            ADDR_SPMODE[7:2] : reg_out <= SPMODE;
            ADDR_SPIE[7:2]   : reg_out <= SPIE;
            ADDR_SPIM[7:2]   : reg_out <= SPIM;
            ADDR_SPCOM[7:2]  : reg_out <= SPCOM;
            ADDR_SPITF[7:2]  : reg_out <= SPITF;
            ADDR_SPIRF[7:2]  : reg_out <= SPIRF;
            default : reg_out <= 0;
        endcase
    end
end


endmodule

