`include "timescale.v"

module tb_i2c;
`include "i2c-def.v"
`include "i2c-reg-def.v"
/* 1. All I 2 C registers must be located in a cache-inhibited page.
* 2. Update I2CnFDR[FDR] and select the required division ratio to obtain the SCLn frequency from
* the CSB (platform) clock.
    * 3. Update I2CnADR to define the slave address for this device.
    * 4. Modify I2CnCR to select master/slave mode, transmit/receive mode, and interrupt-enable or
    * disable.
    * 5. Set the I2CnCR[MEN] to enable the I 2 C interface.
    */
   localparam C_SM_IDLE     = 5'h00;
   localparam C_SM_FDR_INIT = 5'h01;
   localparam C_SM_ADR_INIT = 5'h02;
   localparam C_SM_MEN_SET  = 5'h03;
   localparam C_SM_CR_INIT  = 5'h04;
   localparam C_SM_START    = 5'h05;
   localparam C_SM_WR_WADDR = 5'h06;
   localparam C_SM_RD_ACK1  = 5'h07;
   localparam C_SM_WR_DATA  = 5'h08;
   localparam C_SM_RD_ACK2  = 5'h09;
   localparam C_SM_RESTART  = 5'h0a;
   localparam C_SM_WR_RADDR = 5'h0b;
   localparam C_SM_RD_ACK3  = 5'h0c;
   localparam C_SM_RD_DATA1 = 5'h0d;
   localparam C_SM_WR_ACK   = 5'h0e;
   localparam C_SM_RD_DATA2 = 5'h0f;
   localparam C_SM_STOP     = 5'h10;

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
   reg  [8:0]    i2csr;
   reg  [4:0]    next_state; // read date output
   reg  [7:0]    num_bytes;


   localparam SM_ADDR_READ   = 4'd8;
   localparam SM_ADDR_WRITE  = 4'd9;

   assign i_wr_addr = wr_addr;
   assign i_wr_data = wr_data;
   assign i_rd_addr = rd_addr;
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
       next_state <= C_SM_IDLE;
       slave_addr <= 8'h50;
       regval <= 8'h00;
       i_sysclk <= 0;
       i_reset_n <= 0;
       i_wr_ena <= 0;
       i_rd_ena <= 0;

       wr_addr <= 0;
       wr_data <= 0;
       rd_addr <= 0;
       rd_data <= 0;

       #500
       i_reset_n <= 1;
       #500
       // C_SM_FDR_INIT : begin
       next_state <= C_SM_FDR_INIT;
       wr_addr    <= (ADDR_FDR << 2);
       wr_data    <= 8'h07; /*  7: 1024 dividor */
       #105
       i_wr_ena   <= 1;
       #100
       // end
       // C_SM_ADR_INIT : begin
       next_state <= C_SM_ADR_INIT;
       wr_addr    <= (ADDR_ADR << 2);
       wr_data    <= 8'h00;
       #100
       i_wr_ena   <= 1;
       // end
       // C_SM_MEN_SET : begin
       #100
       next_state <= C_SM_MEN_SET;
       wr_addr    <= (ADDR_CR << 2);
       wr_data    <= (1 << CCR_MEN);
       #100
       i_wr_ena   <= 1;
       // end
       // C_SM_CR_INIT : begin
       #500
       next_state <= C_SM_CR_INIT;
       wr_addr    <= (ADDR_CR << 2);
       wr_data    <= (1 << CCR_MEN) | (1 << CCR_MSTA) | (1 << CCR_MTX);
       #100
       i_wr_ena  <= 1;
       // end
       // C_SM_START : begin
       #20
       next_state <= C_SM_START;
       #20
       i_wr_ena  <= 1;
       #20
       next_state <= C_SM_WR_WADDR;
       wr_addr <= (ADDR_DR << 2);
       wr_data <= 8'ha0;
       #10
       i_wr_ena  <= 1;
       // end
       #600000
       wr_data <= 8'h00;
       #10;
       i_wr_ena  <= 0;
       rd_addr <= (ADDR_SR << 2);
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

       i_wr_ena  <= 0;
       if (i_rd_ena) begin
           regval <= o_rd_data;
           i_rd_ena <= 0;
           if (rd_addr == (ADDR_SR << 2)) begin
               i2csr <= o_rd_data;
           end
       end
       else begin
           i_rd_ena <= 1;
       end
       // tmp_data <= tmp_data;
       if (regval[CSR_MBB] & regval[CSR_MCF])
       begin
           case (next_state)
               C_SM_IDLE : begin
               end
               C_SM_FDR_INIT : begin
               end
               C_SM_ADR_INIT : begin
               end
               C_SM_CR_INIT : begin
               end
               C_SM_MEN_SET : begin
               end
               C_SM_START : begin
               end
               C_SM_WR_WADDR : begin
                   wr_addr    <= (ADDR_DR << 2);
                     wr_data  <= 8'ha0;
                   i_wr_ena   <= 1;
                   next_state <= C_SM_RD_ACK1;
               end
               C_SM_RD_ACK1 : begin
                   next_state <= C_SM_WR_DATA;
                     wr_data  <= 8'h55;
                   i_wr_ena   <= 1;
               end
               C_SM_WR_DATA : begin
                   wr_addr    <= (ADDR_DR << 2);
                     wr_data  <= 8'h55;
                   i_wr_ena   <= 1;
                   next_state <= C_SM_RD_ACK2;
               end
               C_SM_RD_ACK2 : begin
                   next_state <= C_SM_RESTART;
               end
               C_SM_RESTART : begin
                   next_state <= C_SM_WR_RADDR;
                   wr_addr    <= (ADDR_CR << 2);
                   wr_data    <= (1 << CCR_MEN) | (1 << CCR_MSTA) | (1 << CCR_MTX) | (1 << CCR_RSTA);
                   i_wr_ena   <= 1;
               end
               C_SM_WR_RADDR : begin
                   next_state <= C_SM_RD_ACK3;
                   wr_addr    <= (ADDR_DR << 2);
                   wr_data    <= 8'ha1;
                   i_wr_ena   <= 1;
               end
               C_SM_RD_ACK3 : begin
                   next_state <= C_SM_RD_DATA1;
                   wr_addr    <= (ADDR_CR << 2);
                   wr_data    <= (1 << CCR_MEN) | (1 << CCR_MSTA);
               end
               C_SM_RD_DATA1 : begin
                   next_state <= C_SM_WR_ACK;
                   rd_addr    <= (ADDR_DR << 2);
                   rd_data    <= 8'h00;
                   #5
                   i_rd_ena   <= 1;
                   #10
                   i_rd_ena   <= 0;
               end
               C_SM_WR_ACK : begin
                   next_state <= C_SM_RD_DATA2;
               end
               C_SM_RD_DATA2 : begin
                   next_state <= C_SM_STOP;
                   rd_addr    <= (ADDR_DR << 2);
                   rd_data    <= 8'h00;
                   #10
                   i_rd_ena   <= 1;
                   #10
                   i_rd_ena   <= 0;
               end
               C_SM_STOP : begin
                   next_state <= C_SM_IDLE;
                   wr_addr    <= (ADDR_CR << 2);
                   wr_data    <= (1 << CCR_MEN);
                   i_wr_ena   <= 1;
               end
               default   :;
           endcase
       end
   end

endmodule

