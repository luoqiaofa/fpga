`include "timescale.v"

module tb_i2c;
`include "i2c-def.v"
`include "i2c-reg-def.v"

reg           sysclk_i;  // system clock input
reg           reset_n_i; // module reset input
reg           wr_ena_i;  // write enable
wire [4:0]    wr_addr_i; // write address
wire [7:0]    wr_data_i; // write date input
reg           rd_ena_i;  // read enable input
wire [4:0]    rd_addr_i; // read address input
wire [7:0]    rd_data_o; // read date output
wire          scl_pin;   // scl pad pin
wire          sda_pin;    // sda pad pin

reg  [4:0]    wr_addr;
reg  [7:0]    wr_data;
reg  [4:0]    rd_addr;
reg  [7:0]    rd_data;
reg  [7:0]    regval; // read date output
reg  [7:0]    slave_addr;
reg  [8:0]    tmp_data;
reg  [4:0]    state; // read date output
reg  [4:0]    next_state; // read date output

// localparam SM_IDLE     = 3'd0;
// localparam SM_START    = 3'd1;
// localparam SM_STOP     = 3'd2;
// localparam SM_WRITE    = 3'd3;
// localparam SM_READ     = 3'd4;
// localparam SM_WR_ACK   = 3'd5;
// localparam SM_RD_ACK   = 3'd6;
// localparam SM_RESTART  = 3'd7;
localparam SM_ADDR_READ   = 4'd8;
localparam SM_ADDR_WRITE  = 4'd9;

assign wr_addr_i = wr_addr;
assign wr_data_i = wr_data;
assign rd_addr_i = rd_addr;
assign rd_data_i = rd_data;

i2c_top_module i2c_master_u1(
    .sysclk_i(sysclk_i),   // system clock input
    .reset_n_i(reset_n_i), // module reset input
    .wr_ena_i(wr_ena_i),   // write enable
    .wr_addr_i(wr_addr_i), // write address
    .wr_data_i(wr_data_i), // write date input
    .rd_ena_i(rd_ena_i),   // read enable input
    .rd_addr_i(rd_addr_i), // read address input
    .rd_data_o(rd_data_o), // read date output
    .scl_pin(scl_pin),     // scl pad pin
    .sda_pin(sda_pin)      // sda pad pin
);

initial
begin            
$dumpfile("wave.vcd");    //生成的vcd文件名称
$dumpvars(0);   //tb模块名称
end 

initial
begin
    state <= SM_IDLE;
    next_state <= SM_IDLE;
    slave_addr <= 8'h50;
    tmp_data <= 8'h50;
    regval <= 8'h00;
    sysclk_i <= 0;
    reset_n_i <= 0;
    wr_ena_i <= 0;
    rd_ena_i <= 0;

    wr_addr <= 0;
    wr_data <= 0;
    rd_addr <= 0;
    rd_data <= 0;

    #20
    reset_n_i <= 1;
    #10
    wr_addr <= (ADDR_FDR << 2);
    wr_ena_i  <= 1;
    wr_data   <= 8'h07;
    #10;
    wr_ena_i  <= 0;
    #100
    wr_data   <= 8'hb0;
    wr_addr <= (ADDR_CR << 2);
    wr_ena_i  <= 1;
    #10;
    wr_ena_i  <= 0;
    wr_addr <= (ADDR_CR << 2);
    wr_ena_i <= (1 << CCR_MEN); 
    wr_ena_i  <= 1;
    #10;
    wr_ena_i <= 0;
    next_state <= SM_START;
    // [BIT_MIEN] & I2CCR[BIT_MSTA]
    #500000
    wr_ena_i  <= 1;
    wr_data <= 8'h00;
    #10;
    wr_ena_i  <= 0;
    $stop;
    $finish;
end

always #5 sysclk_i = ~sysclk_i;

always @(posedge sysclk_i)
begin
    rd_ena_i <= 0;
    #10
    rd_addr <= (ADDR_SR << 2);
    rd_ena_i <= 1;
    #10
    rd_ena_i <= 0;
    #10
    regval <= rd_data_o;
    state <= next_state;
    // tmp_data <= tmp_data;
    if (rd_data_o[CSR_MBB] & rd_data_o[CSR_MCF])
    begin
        case (state)
            SM_IDLE     :;
            SM_START    :
            begin
                wr_ena_i <= 0;
                #10;
                wr_addr <= (ADDR_CR << 2);
                wr_data <= (1 << CCR_MEN) | (1 << CCR_MSTA) | (1 << CCR_MTX);
                #10;
                wr_ena_i  <= 1;
                #10;
                wr_ena_i <= 0;
                // regval[CSR_MIF]
                next_state <= SM_ADDR_WRITE;
            end
            SM_STOP     :
            begin
                #10;
                wr_ena_i <= 0;
                wr_addr <= (ADDR_CR << 2);
                wr_data <= (1 << CCR_MEN);
                #10;
                wr_ena_i  <= 1;
                #10;
                wr_ena_i  <= 0;
                #10;
            end
            SM_ADDR_READ :
            begin
                wr_ena_i <= 0;
                #10;
                wr_addr <= (ADDR_DR << 2);
                wr_data <= {slave_addr[6:0], 1'b1};
                #10;
                wr_ena_i  <= 1;
                #10;
                wr_ena_i  <= 0;
                #10;
                next_state <= SM_READ;
                tmp_data <= tmp_data + 1;
            end
            SM_ADDR_WRITE :
            begin
                wr_ena_i <= 0;
                #10;
                wr_addr <= (ADDR_DR << 2);
                wr_data <= {slave_addr[6:0], 1'b0};
                #10;
                wr_ena_i  <= 1;
                #10;
                wr_ena_i  <= 0;
                #10;
                next_state <= SM_WRITE;
                tmp_data <= tmp_data + 1;
            end
            SM_WRITE    :
            begin
                if (regval[CSR_MIF])
                begin
                    wr_ena_i <= 0;
                    #10;
                    wr_addr <= (ADDR_SR << 2);
                    wr_data <= 8'h81;
                    wr_ena_i <= 1;
                    #10;
                    wr_ena_i <= 0;
                    #10;
                    wr_ena_i <= 0;
                    #10;
                    wr_addr <= (ADDR_DR << 2);
                    wr_data <= tmp_data;
                    #10;
                    wr_ena_i  <= 1;
                    #10;
                    wr_ena_i <= 0;
                    next_state <= SM_WRITE;
                    tmp_data <= tmp_data + 1;
                    if (tmp_data == 8'h51)
                    begin
                        next_state <= SM_RESTART;
                    end
                end
            end
            SM_READ     :
            begin
                rd_ena_i <= 0;
                #10
                rd_addr <= (ADDR_DR << 2);
                #10
                rd_ena_i <= 1;
                #10
                rd_ena_i <= 0;
                next_state <= SM_READ;
                regval <= rd_data_o;
                next_state <= SM_READ;
            end
            SM_RESTART  :
            begin
                if (regval[CSR_MIF])
                begin
                    wr_ena_i <= 0;
                    #10;
                    wr_addr <= (ADDR_SR << 2);
                    wr_data <= 8'h81;
                    wr_ena_i <= 1;
                    #10;
                    wr_ena_i <= 0;
                    #10;
                    wr_addr <= (ADDR_CR << 2);
                    wr_data <= (1 << CCR_RSTA) | (1 << CCR_MEN) | (1 << CCR_MSTA) | (1 << CCR_MTX);
                    #10;
                    wr_ena_i  <= 1;
                    #10;
                    wr_ena_i <= 0;
                    #10000;
                    next_state <= SM_ADDR_READ;
                end
            end
            default   :;
        endcase
    end
end

endmodule
