`include "timescale.v"

module tb_i2c;
`include "i2c-def.v"
`include "i2c-reg-def.v"

reg           i_sysclk;  // system clock input
reg           i_reset_n; // module reset input
reg           i_wr_ena;  // write enable
wire [4:0]    i_wr_addr; // write address
wire [7:0]    i_wr_data; // write date input
reg           i_rd_ena;  // read enable input
wire [4:0]    i_rd_addr; // read address input
wire [7:0]    o_rd_data; // read date output
wire          scl_pin;   // scl pad pin
wire          sda_pin;    // sda pad pin
wire          read_valid;
wire          write_valid;

reg  [4:0]    wr_addr;
reg  [7:0]    wr_data;
reg  [4:0]    rd_addr;
reg  [7:0]    rd_data;
reg  [7:0]    regval; // read date output
reg  [7:0]    slave_addr;
reg  [8:0]    tmp_data;
reg  [4:0]    state; // read date output
reg  [4:0]    next_state; // read date output
reg  [7:0]    num_bytes;

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

assign i_wr_addr = wr_addr;
assign i_wr_data = wr_data;
assign i_rd_addr = rd_addr;
assign i_rd_data = rd_data;
wire   s_i2c_irq;

i2c_top_module i2c_master_u1(
    .i_sysclk(i_sysclk),   // system clock input
    .i_reset_n(i_reset_n), // module reset input
    .i_wr_ena(i_wr_ena),   // write enable
    .i_wr_addr(i_wr_addr), // write address
    .i_wr_data(i_wr_data), // write date input
    .i_rd_ena(i_rd_ena),   // read enable input
    .i_rd_addr(i_rd_addr), // read address input
    .o_rd_data(o_rd_data), // read date output
    .o_read_ready (read_valid),      // data ready to read
    .o_write_ready(write_valid),      // data ready to read
    .o_interrupt(s_i2c_irq),
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
    num_bytes <= 0;
    state <= SM_IDLE;
    next_state <= SM_IDLE;
    slave_addr <= 8'h50;
    tmp_data <= 8'h50;
    regval <= 8'h00;
    i_sysclk <= 0;
    i_reset_n <= 0;
    i_wr_ena <= 0;
    i_rd_ena <= 0;

    wr_addr <= 0;
    wr_data <= 0;
    rd_addr <= 0;
    rd_data <= 0;

    #20
    i_reset_n <= 1;
    #10
    wr_addr <= (ADDR_FDR << 2);
    i_wr_ena  <= 1;
    wr_data   <= 8'h07;
    #10;
    i_wr_ena  <= 0;
    #100
    wr_data   <= 8'hb0;
    wr_addr <= (ADDR_CR << 2);
    i_wr_ena  <= 1;
    #10;
    i_wr_ena  <= 0;
    wr_addr <= (ADDR_CR << 2);
    i_wr_ena <= (1 << CCR_MEN);
    i_wr_ena  <= 1;
    #10;
    i_wr_ena <= 0;
    next_state <= SM_START;
    // [BIT_MIEN] & I2CCR[BIT_MSTA]
    #600000
    i_wr_ena  <= 1;
    wr_data <= 8'h00;
    #10;
    i_wr_ena  <= 0;
    $stop;
    $finish;
end

always #5 i_sysclk = ~i_sysclk;

always @(posedge i_sysclk)
begin
    i_rd_ena <= 0;
    #10
    rd_addr <= (ADDR_SR << 2);
    i_rd_ena <= 1;
    #10
    i_rd_ena <= 0;
    #10
    regval <= o_rd_data;
    state <= next_state;
    // tmp_data <= tmp_data;
    if (o_rd_data[CSR_MBB] & o_rd_data[CSR_MCF])
    begin
        case (state)
            SM_IDLE     :;
            SM_START    :
            begin
                i_wr_ena <= 0;
                #10;
                wr_addr <= (ADDR_CR << 2);
                wr_data <= (1 << CCR_MEN) | (1 << CCR_MSTA) | (1 << CCR_MTX);
                #10;
                i_wr_ena  <= 1;
                #10;
                i_wr_ena <= 0;
                // regval[CSR_MIF]
                next_state <= SM_ADDR_WRITE;
            end
            SM_STOP     :
            begin
                #10;
                i_wr_ena <= 0;
                wr_addr <= (ADDR_CR << 2);
                wr_data <= (1 << CCR_MEN);
                #10;
                i_wr_ena  <= 1;
                #10;
                i_wr_ena  <= 0;
                #10;
            end
            SM_ADDR_READ :
            begin
                i_wr_ena <= 0;
                #10;
                wr_addr <= (ADDR_DR << 2);
                wr_data <= {slave_addr[6:0], 1'b1};
                #10;
                i_wr_ena  <= 1;
                #10;
                i_wr_ena  <= 0;
                #10;
                next_state <= SM_READ;
                tmp_data <= tmp_data + 1;
            end
            SM_ADDR_WRITE :
            begin
                i_wr_ena <= 0;
                #10;
                wr_addr <= (ADDR_DR << 2);
                wr_data <= {slave_addr[6:0], 1'b0};
                #10;
                i_wr_ena  <= 1;
                #10;
                i_wr_ena  <= 0;
                #10;
                next_state <= SM_WRITE;
                tmp_data <= tmp_data + 1;
            end
            SM_WRITE    :
            begin
                if (regval[CSR_MIF])
                begin
                    i_wr_ena <= 0;
                    #10;
                    wr_addr <= (ADDR_SR << 2);
                    wr_data <= 8'h81;
                    i_wr_ena <= 1;
                    #10;
                    i_wr_ena <= 0;
                    #10;
                    i_wr_ena <= 0;
                    #10;
                    wr_addr <= (ADDR_DR << 2);
                    wr_data <= tmp_data;
                    #10;
                    i_wr_ena  <= 1;
                    #10;
                    i_wr_ena <= 0;
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
                if (regval[CSR_MIF])
                begin
                    num_bytes = num_bytes + 1;
                    regval <= o_rd_data;
                    i_wr_ena <= 0;
                    #10;
                    wr_addr <= (ADDR_SR << 2);
                    wr_data <= 8'h81;
                    i_wr_ena <= 1;
                    #10;
                    i_wr_ena <= 0;
                    #10;
                    i_rd_ena <= 0;
                    #10
                    rd_addr <= (ADDR_DR << 2);
                    #10
                    i_rd_ena <= 1;
                    #10
                    i_rd_ena <= 0;
                    if (num_bytes == 2)
                    begin
                        next_state <= SM_STOP;
                    end
                end
            end
            SM_RESTART  :
            begin
                if (regval[CSR_MIF])
                begin
                    i_wr_ena <= 0;
                    #10;
                    wr_addr <= (ADDR_SR << 2);
                    wr_data <= 8'h81;
                    i_wr_ena <= 1;
                    #10;
                    i_wr_ena <= 0;
                    #10;
                    wr_addr <= (ADDR_CR << 2);
                    wr_data <= (1 << CCR_RSTA) | (1 << CCR_MEN) | (1 << CCR_MSTA) | (1 << CCR_MTX);
                    #10;
                    i_wr_ena  <= 1;
                    #10;
                    i_wr_ena <= 0;
                    #10000;
                    next_state <= SM_ADDR_READ;
                end
            end
            default   :;
        endcase
    end
end

endmodule
