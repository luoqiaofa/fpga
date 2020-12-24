`include "timescale.v"
module spi_intface # (parameter NCS = 4)
(
    input  wire S_SYSCLK,  // platform clock
    input  wire S_RESETN,  // reset
    input  wire [7:0] S_AWADDR,
    input  wire [31: 0] S_WDATA,
    input  wire [3 : 0] S_WSTRB,
    input  wire S_WVALID,
    input  wire S_AWVALID,
    output wire S_WREADY,
    output wire S_AWREADY,
    input  wire S_ARVALID,
    output wire S_ARREADY,
    input  wire [7 : 0] S_ARADDR,
    output wire [31 : 0] S_RDATA,
    output wire S_RVALID,
    input  wire S_RREADY,
    input  wire S_BREADY,
    output wire S_BVALID,
    output wire [1 : 0] S_BRESP,
    output wire [1 : 0] S_RRESP,
    output wire S_SPI_SCK,
    input  wire S_SPI_MISO,
    output wire S_SPI_MOSI,
    output wire [NCS-1:0] S_SPI_CS_B
);
`include "reg-bit-def.v"

reg [REG_WIDTH-1: 0] SPMODE;
reg [REG_WIDTH-1: 0] SPIE;
reg [REG_WIDTH-1: 0] SPIM;
reg [REG_WIDTH-1: 0] SPCOM;
reg [REG_WIDTH-1: 0] SPITF;
reg [REG_WIDTH-1: 0] SPIRF;
reg [REG_WIDTH-1: 0] SPIREV1;
reg [REG_WIDTH-1: 0] SPIREV2;
reg [REG_WIDTH-1: 0] SPMODE0;
reg [REG_WIDTH-1: 0] SPMODE1;
reg [REG_WIDTH-1: 0] SPMODE2;
reg [REG_WIDTH-1: 0] SPMODE3;

reg [REG_WIDTH-1: 0] CSMODE;

reg wready;
reg awready;
reg rrvalid;
reg arready;
reg	aw_en;
reg bvalid;
reg rvalid;
reg [1:0] rresp;
reg [1 : 0] bresp;
reg [31:0] rdata;
reg [31:0] reg_data_out;
reg [C_ADDR_WIDTH-1 : 0] awaddr;
reg [NCS-1:0] spi_cs_b;

reg chr_go;
reg frame_go;
reg [SPCOM_TRANLEN_HI:SPCOM_TRANLEN_LO] chars_count;  
wire chr_done;
reg [CHAR_LEN_MAX-1:0] data_tx;
wire [CHAR_LEN_MAX-1:0] data_rx;

integer byte_index;

wire slv_reg_rden;
wire slv_reg_wren;

assign S_AWREADY = awready;
assign S_WREADY  = wready;
assign S_BRESP   = bresp;
assign S_BVALID  = bvalid;
assign S_ARREADY = arready;
assign S_RDATA   = rdata;
assign S_RRESP   = rresp;
assign S_RVALID  = rvalid;

assign S_SPI_CS_B = spi_cs_b;

assign slv_reg_wren = wready && S_WVALID && awready && S_AWVALID;
assign slv_reg_rden = arready & S_ARVALID & ~rvalid;


always @(posedge S_SYSCLK or negedge S_RESETN)
begin
    if (!S_RESETN)
    begin
        rrvalid <= 0;
        arready <= 0;
        rresp   <= 2'b00;
        reg_data_out <= 0;
        spi_cs_b <= {{NCS{1'b0}}};
    end
    else begin
        chars_count <= SPCOM[SPCOM_TRANLEN_HI:SPCOM_TRANLEN_LO]; 
        CSMODE <= cur_cs_mode(SPCOM, SPMODE0, SPMODE1, SPMODE2, SPMODE3);
    end
end

always @( posedge S_SYSCLK )
begin
    if (S_RESETN == 1'b0 )
    begin
        byte_index <= 0;
        SPMODE  <= 32'h0000_100F;
        SPIE    <= 32'h0020_0000;
        SPIM    <= 32'h0000_0000;
        SPCOM   <= 32'h0000_0000;
        SPITF   <= 32'h0000_0000;
        SPIRF   <= 32'h0000_0000;
        SPIREV1 <= 32'h0000_0000;
        SPIREV2 <= 32'h0000_0000;
        SPMODE0 <= 32'h0010_0000;
        SPMODE1 <= 32'h0010_0000;
        SPMODE2 <= 32'h0010_0000;
        SPMODE3 <= 32'h0010_0000;
        CSMODE  <= 32'h0010_0000;
    end
    else begin
        if (slv_reg_wren) begin
            case (awaddr[7:2])
               ADDR_SPMODE[7:2] :
                    for (byte_index = 0; byte_index <= (C_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                    begin
                        if ( S_WSTRB[byte_index] == 1 ) begin
                            // Respective byte enables are asserted as per write strobes
                            // Slave register 0
                            SPMODE[(byte_index*8) +: 8] <= S_WDATA[(byte_index*8) +: 8];
                        end
                    end
                ADDR_SPIE[7:2]:
                    for ( byte_index = 0; byte_index <= (C_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                        if ( S_WSTRB[byte_index] == 1 ) begin
                            // Respective byte enables are asserted as per write strobes
                            // Slave register 1
                            SPIE[(byte_index*8) +: 8] <= S_WDATA[(byte_index*8) +: 8];
                        end
                ADDR_SPIM[7:2]:
                    for ( byte_index = 0; byte_index <= (C_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                        if ( S_WSTRB[byte_index] == 1 ) begin
                            // Respective byte enables are asserted as per write strobes
                            // Slave register 2
                            SPIM[(byte_index*8) +: 8] <= S_WDATA[(byte_index*8) +: 8];
                        end
                ADDR_SPCOM[7:2]:
                    for (byte_index = 0; byte_index <= (C_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                        if (S_WSTRB[byte_index] == 1 ) begin
                            // Respective byte enables are asserted as per write strobes
                            // Slave register 3
                            SPCOM[(byte_index*8) +: 8] <= S_WDATA[(byte_index*8) +: 8];
                        end
                ADDR_SPITF[7:2]:
                    for (byte_index = 0; byte_index <= (C_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                        if (S_WSTRB[byte_index] == 1 ) begin
                            // Respective byte enables are asserted as per write strobes
                            // Slave register 3
                            SPITF[(byte_index*8) +: 8] <= S_WDATA[(byte_index*8) +: 8];
                        end
                ADDR_SPIRF[7:2]:
                    for (byte_index = 0; byte_index <= (C_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                        if (S_WSTRB[byte_index] == 1 ) begin
                            // Respective byte enables are asserted as per write strobes
                            // Slave register 3
                            SPIRF[(byte_index*8) +: 8] <= S_WDATA[(byte_index*8) +: 8];
                        end
                ADDR_SPMODE0[7:2]:
                begin
                    for (byte_index = 0; byte_index <= (C_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                    begin
                        if (S_WSTRB[byte_index] == 1 ) begin
                            // Respective byte enables are asserted as per write strobes
                            // Slave register 3
                            SPMODE0[(byte_index*8) +: 8] <= S_WDATA[(byte_index*8) +: 8];
                        end
                    end
                end
                ADDR_SPMODE1[7:2]:
                begin
                    for (byte_index = 0; byte_index <= (C_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                    begin
                        if (S_WSTRB[byte_index] == 1 ) begin
                            // Respective byte enables are asserted as per write strobes
                            // Slave register 3
                            SPMODE1[(byte_index*8) +: 8] <= S_WDATA[(byte_index*8) +: 8];
                        end
                    end
                end
                ADDR_SPMODE2[7:2]:
                begin
                    for (byte_index = 0; byte_index <= (C_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                    begin
                        if (S_WSTRB[byte_index] == 1 ) begin
                            // Respective byte enables are asserted as per write strobes
                            // Slave register 3
                            SPMODE2[(byte_index*8) +: 8] <= S_WDATA[(byte_index*8) +: 8];
                        end
                    end
                end
                ADDR_SPMODE3[7:2]:
                begin
                    for (byte_index = 0; byte_index <= (C_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                    begin
                        if (S_WSTRB[byte_index] == 1 ) begin
                            // Respective byte enables are asserted as per write strobes
                            // Slave register 3
                            SPMODE3[(byte_index*8) +: 8] <= S_WDATA[(byte_index*8) +: 8];
                        end
                    end
                end
                default : begin
                end
            endcase
        end
    end
end

always @( posedge S_SYSCLK )
begin
    if (S_RESETN == 1'b0 )
    begin
        awaddr <= 0;
        aw_en  <= 1;
    end
    else begin
        if (~awready && S_AWVALID && S_WVALID && aw_en)
        begin
            // Write Address latching
            awaddr <= S_AWADDR;
        end
    end
end

always @( posedge S_SYSCLK)
begin
    if (S_RESETN == 1'b0 )
    begin
        wready <= 1'b1;
    end
    else begin
        if (~wready && S_WVALID && S_AWVALID && aw_en)
        begin
            // slave is ready to accept write data when
            // there is a valid write address and write data
            // on the write address and data bus. This design
            // expects no outstanding transactions.
            wready <= 1'b1;
        end
        else begin
            wready <= 1'b0;
        end
    end
end

always @( posedge S_SYSCLK )
begin
    if (S_RESETN == 1'b0 )
    begin
        awready <= 1'b0;
        aw_en <= 1'b1;
    end
    else begin
        if (~awready && S_AWVALID && S_WVALID && aw_en)
        begin
            // slave is ready to accept write address when
            // there is a valid write address and write data
            // on the write address and data bus. This design
            // expects no outstanding transactions.
            awready <= 1'b1;
            aw_en <= 1'b0;
        end
        else if (S_BREADY && bvalid)
        begin
            aw_en <= 1'b1;
            awready <= 1'b0;
        end
        else begin
            awready <= 1'b0;
        end
    end
end

always @( posedge S_SYSCLK)
begin
    if (S_RESETN == 1'b0 )
    begin
        bvalid  <= 0;
        bresp   <= 2'b0;
    end
    else
    begin
    if (awready && S_AWVALID && ~bvalid && wready && S_WVALID)
    begin
        // indicates a valid write response is available
        bvalid <= 1'b1;
        bresp  <= 2'b0; // 'OKAY' response
    end                   // work error responses in future
    else
    begin
        if (S_BREADY && bvalid)
            //check if bready is asserted while bvalid is high)
                //(there is a possibility that bready is always asserted high)
            begin
                bvalid <= 1'b0;
            end
        end
    end
end

always @( posedge S_SYSCLK)
begin
    if ( S_RESETN == 1'b0)
    begin
        rvalid <= 0;
        rresp  <= 0;
    end
    else begin
        if (arready && S_ARVALID && ~rvalid)
        begin
            // Valid read data is available at the read data bus
            rvalid <= 1'b1;
            rresp  <= 2'b0; // 'OKAY' response
        end
        else if (rvalid && S_RREADY)
        begin
            // Read data is accepted by the master
            rvalid <= 1'b0;
        end
    end
end

// Output register or memory read data
always @( posedge S_SYSCLK )
begin
    if (S_RESETN == 1'b0 )
    begin
        rdata  <= 0;
    end
    else
    begin
        // When there is a valid read address (S_ARVALID) with
        // acceptance of read address by the slave (arready),
        // output the read dada
        if (slv_reg_rden)
        begin
            rdata <= reg_data_out;     // register read data
        end
    end
end

function [REG_WIDTH-1: 0] cur_cs_mode(
    input [REG_WIDTH-1: 0] spcom,
    input [REG_WIDTH-1: 0] spmode0,
    input [REG_WIDTH-1: 0] spmode1,
    input [REG_WIDTH-1: 0] spmode2,
    input [REG_WIDTH-1: 0] spmode3
);
begin
    case (spcom[SPCOM_CS_HI:SPCOM_CS_LO])
        2'b00:
        begin
           cur_cs_mode = spmode0;
        end
        2'b01:
        begin
            cur_cs_mode = spmode1;
        end
        2'b10:
        begin
            cur_cs_mode = spmode2;
        end
        2'b11:
        begin
            cur_cs_mode = spmode3;
        end
    endcase
end
endfunction

// /*
spi_trx_one_char #(.CHAR_NBITS(CHAR_LEN_MAX))
inst_spi_trx_ch
(
    .S_SYSCLK(S_SYSCLK),  // platform clock
    .S_RESETN(S_RESETN),  // reset
    .S_ENABLE(SPMODE[SPMODE_EN]),  // enable
    .S_CPOL(CSMODE[CSMODE_CPOL]),    // clock polary
    .S_CPHA(CSMODE[CSMODE_CPOL]),    // clock phase, the first edge or second
    .S_TX_ONLY(SPCOM[SPCOM_TO]), // transmit only
    .S_LOOP(SPMODE[SPMODE_LOOP]),    // internal loopback mode
    .S_REV(CSMODE[CSMODE_REV]),     // msb first or lsb first
    .S_CHAR_LEN(CSMODE[CSMODE_LEN_HI:CSMODE_LEN_LO]),// characters in bits length
    .S_NDIVIDER({{4{1'b0}},CSMODE[CSMODE_PM_HI:CSMODE_PM_LO]}),// clock divider
    .S_SPI_SCK(SPI_SCK),
    .S_SPI_MISO(SPI_MISO),
    .S_SPI_MOSI(SPI_MOSI),
    .S_CHAR_GO(chr_go),
    .S_CHAR_DONE(chr_done),
    .S_WCHAR(data_tx),   // output character
    .S_RCHAR(data_rx)    // input character
);
// */

endmodule
