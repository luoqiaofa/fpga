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
   localparam C_SM_IDLE      = 5'h00;
   localparam C_SM_FDR_INIT  = 5'h01;
   localparam C_SM_ADR_INIT  = 5'h02;
   localparam C_SM_MEN_SET   = 5'h03;
   localparam C_SM_WAIT_SR1  = 5'h04;
   localparam C_SM_CR_INIT   = 5'h05;
   localparam C_SM_WAIT_SR2  = 5'h06;
   localparam C_SM_START     = 5'h07;
   localparam C_SM_WAIT_SR3  = 5'h08;
   localparam C_SM_WR_WADDR  = 5'h09;
   localparam C_SM_RD_ACK1   = 5'h0a;
   localparam C_SM_WAIT_SR4  = 5'h0b;
   localparam C_SM_WR_DATA   = 5'h0c;
   localparam C_SM_WAIT_SR5  = 5'h0d;
   localparam C_SM_RD_ACK2   = 5'h0e;
   localparam C_SM_WAIT_SR6  = 5'h0f;
   localparam C_SM_RESTART   = 5'h10;
   localparam C_SM_WAIT_SR8  = 5'h11;
   localparam C_SM_WR_RADDR  = 5'h12;
   localparam C_SM_WAIT_SR9  = 5'h13;
   localparam C_SM_RD_ACK3   = 5'h14;
   localparam C_SM_XFER_READ = 5'h15;
   localparam C_SM_RD_DATA1  = 5'h16;
   localparam C_SM_WAIT_SR10 = 5'h17;
   localparam C_SM_WR_ACK    = 5'h18;
   localparam C_SM_SET_TXNAK = 5'h19;
   localparam C_SM_RD_DATA2  = 5'h1a;
   localparam C_SM_WAIT_SR11 = 5'h1b;
   localparam C_SM_RESET_MTX = 5'h1c;
   localparam C_SM_STOP      = 5'h1d;

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
   reg  [7:0]    slave_addr;
   reg  [7:0]    i2csr;
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
       i2csr <= 0;
       next_state <= C_SM_IDLE;
       slave_addr <= 8'h50;
       i_sysclk <= 0;
       i_reset_n <= 0;
       i_wr_ena <= 0;
       i_rd_ena <= 0;

       wr_addr <= 0;
       wr_data <= 0;
       rd_addr <= (ADDR_SR << 2);
       rd_data <= 0;

       #100
       i_reset_n <= 1;
       i_wr_ena <= 0;
       #100
       // C_SM_FDR_INIT : begin
       next_state <= C_SM_FDR_INIT;
       wr_addr    <= (ADDR_FDR << 2);
       wr_data    <= 8'h07; /*  7: 1024 dividor */
       #105
       i_wr_ena   <= 1;
       #40
       next_state <= C_SM_ADR_INIT;
       i_wr_ena   <= 0;
       // end
       // C_SM_ADR_INIT : begin
       wr_addr    <= (ADDR_ADR << 2);
       wr_data    <= 8'h00;
       #100
       i_wr_ena   <= 1;
       // end
       // C_SM_MEN_SET : begin
       #100
       i_wr_ena   <= 0;
       next_state <= C_SM_MEN_SET;
       wr_addr    <= (ADDR_CR << 2);
       wr_data    <= (1 << CCR_MEN);
       #100
       i_wr_ena   <= 1;
       // end
       // C_SM_CR_INIT : begin
       #50000
       i_wr_ena   <= 0;
       #40
       next_state <= C_SM_WAIT_SR1;
       i_wr_ena   <= 0;
       // end
       // C_SM_START : begin
       // end
       #600000
       $stop;
       $finish;
   end

   always #5 i_sysclk = ~i_sysclk;

   always @(posedge i_sysclk or negedge i_reset_n)
   begin
       if (i_reset_n) begin
           if (read_valid) begin
               if (i_rd_ena) begin
                   if (rd_addr == (ADDR_SR << 2)) begin
                       i2csr <= o_rd_data;
                   end
                   else begin
                       i2csr <= 0;
                   end
                   i_rd_ena <= 0;
                   case (next_state)
                       C_SM_WAIT_SR1: begin
                           i_wr_ena   <= 0;
                           wr_addr    <= (ADDR_CR << 2);
                           wr_data    <= (1 << CCR_MEN) | (1 << CCR_MSTA) | (1 << CCR_MTX);
                           next_state <= C_SM_CR_INIT;
                       end
                       C_SM_RD_ACK1 : begin
                           next_state <= C_SM_WAIT_SR4;
                       end
                       C_SM_WAIT_SR4 : begin
                           if (rd_addr == (ADDR_SR << 2)) begin
                               if (o_rd_data[CSR_MCF]) begin
                                   i_wr_ena   <= 0;
                                   wr_addr <= (ADDR_DR << 2);
                                   wr_data <= 8'h55;
                                   next_state <= C_SM_WR_DATA;
                               end
                           end
                       end
                       C_SM_WAIT_SR5 : begin
                           next_state <= C_SM_RD_ACK2;
                       end
                       C_SM_RD_ACK2 : begin
                           if (rd_addr == (ADDR_SR << 2)) begin
                               if (o_rd_data[CSR_MCF]) begin
                                   i_wr_ena   <= 0;
                                   wr_addr    <= (ADDR_CR << 2);
                                   wr_data    <= (1 << CCR_MEN) | (1 << CCR_MSTA) | (1 << CCR_MTX) | (1 << CCR_RSTA);
                                   next_state <= C_SM_RESTART;
                               end
                           end
                       end
                       C_SM_WAIT_SR9  : begin
                           next_state <= C_SM_RD_ACK3;
                       end
                       C_SM_RD_ACK3   : begin
                           if (rd_addr == (ADDR_SR << 2)) begin
                               if (o_rd_data[CSR_MCF]) begin
                                   rd_addr <= (ADDR_DR << 2);
                                   i_wr_ena   <= 0;
                                   wr_addr <= (ADDR_CR << 2);
                                   wr_data    <= (1 << CCR_MEN) | (1 << CCR_MSTA);
                                   next_state <= C_SM_XFER_READ;
                               end
                           end
                       end
                       C_SM_RD_DATA1  : begin
                           rd_addr <= (ADDR_SR << 2);
                           next_state <= C_SM_WAIT_SR10;
                       end
                       C_SM_WAIT_SR10 : begin
                           if (rd_addr == (ADDR_SR << 2)) begin
                               if (o_rd_data[CSR_MCF]) begin
                                   rd_addr <= (ADDR_SR << 2);
                                   i_wr_ena   <= 0;
                                   wr_addr <= (ADDR_CR << 2);
                                   wr_data    <= (1 << CCR_MEN) | (1 << CCR_MSTA) | (1 << CCR_TXAK);
                                   next_state <= C_SM_SET_TXNAK;
                               end
                           end
                       end
                       C_SM_RD_DATA2  : begin
                           rd_addr <= (ADDR_SR << 2);
                           next_state <= C_SM_WAIT_SR11;
                       end
                       C_SM_WAIT_SR11 : begin
                           if (rd_addr == (ADDR_SR << 2)) begin
                               if (o_rd_data[CSR_MCF]) begin
                                   i_wr_ena   <= 0;
                                   rd_addr <= (ADDR_SR << 2);
                                   wr_addr    <= (ADDR_CR << 2);
                                   wr_data    <= (1 << CCR_MEN) | (1 << CCR_MSTA) | (1 << CCR_MTX);
                                   next_state <= C_SM_RESET_MTX;
                               end
                           end
                       end
                       default : begin
                           rd_addr <= (ADDR_SR << 2);
                       end
                   endcase

                   if (i_wr_ena) begin
                       if (i2csr[CSR_MCF])
                       begin
                           case (next_state)
                               C_SM_IDLE : begin
                               end
                               C_SM_FDR_INIT : begin
                               end
                               C_SM_ADR_INIT : begin
                               end
                               C_SM_MEN_SET : begin
                               end
                               C_SM_WAIT_SR1 : begin
                               end
                               C_SM_CR_INIT : begin
                                   i_wr_ena   <= 0;
                                   wr_addr    <= (ADDR_CR << 2);
                                   wr_data    <= (1 << CCR_MEN) | (1 << CCR_MSTA) | (1 << CCR_MTX);
                               end
                               C_SM_WAIT_SR2 : begin
                               end
                               C_SM_START : begin
                               end
                               C_SM_WAIT_SR3 : begin
                               end
                               C_SM_WR_WADDR : begin
                                   i_wr_ena   <= 0;
                                   wr_addr <= (ADDR_DR << 2);
                                   wr_data <= 8'ha0;
                               end
                               C_SM_WAIT_SR4 : begin
                               end
                               C_SM_RD_ACK1 : begin
                               end
                               C_SM_WR_DATA : begin
                               end
                               C_SM_WAIT_SR5 : begin
                               end
                               C_SM_RD_ACK2 : begin
                               end
                               C_SM_WAIT_SR6 : begin
                               end
                               C_SM_RESTART : begin
                                   i_wr_ena   <= 0;
                                   wr_addr <= (ADDR_DR << 2);
                                   wr_data <= 8'ha1;
                                   next_state <= C_SM_WR_RADDR;
                               end
                               C_SM_WAIT_SR8 : begin
                               end
                               C_SM_WR_RADDR : begin
                                   wr_addr <= (ADDR_DR << 2);
                                   wr_data <= 8'ha1;
                               end
                               C_SM_WAIT_SR9 : begin
                               end
                               C_SM_RD_ACK3 : begin
                               end
                               C_SM_XFER_READ : begin
                                   wr_addr <= (ADDR_CR << 2);
                                   wr_data    <= (1 << CCR_MEN) | (1 << CCR_MSTA);
                               end
                               C_SM_RD_DATA1 : begin
                               end
                               C_SM_WAIT_SR10 : begin
                               end
                               C_SM_WR_ACK : begin
                                   i_wr_ena  <= 1;
                               end
                               C_SM_SET_TXNAK: begin
                                   // i_wr_ena   <= 0;
                                   rd_addr <= (ADDR_DR << 2);
                                   next_state <= C_SM_RD_DATA2;
                               end
                               C_SM_RD_DATA2 : begin
                               end
                               C_SM_WAIT_SR11 : begin
                               end
                               C_SM_RESET_MTX : begin
                                   i_wr_ena  <= 0;
                                   wr_addr    <= (ADDR_CR << 2);
                                   wr_data    <= (1 << CCR_MEN);
                                   next_state <= C_SM_STOP;
                               end
                               C_SM_STOP : begin
                                   i_wr_ena  <= 1;
                               end
                               default : begin
                                   i_wr_ena  <= 0;
                               end
                           endcase
                       end
                   end
                   else begin
                       case (next_state)
                           C_SM_IDLE : begin
                           end
                           C_SM_FDR_INIT : begin
                           end
                           C_SM_ADR_INIT : begin
                           end
                           C_SM_MEN_SET : begin
                           end
                           C_SM_WAIT_SR1 : begin
                           end
                           C_SM_CR_INIT : begin
                               next_state <= C_SM_WR_WADDR;
                               i_wr_ena  <= 1;
                           end
                           C_SM_WAIT_SR2 : begin
                           end
                           C_SM_START : begin
                               i_wr_ena  <= 1;
                           end
                           C_SM_WAIT_SR3 : begin
                           end
                           C_SM_WR_WADDR : begin
                               i_rd_ena <= 0;
                               i_wr_ena  <= 1;
                               next_state <= C_SM_RD_ACK1;
                           end
                           C_SM_WAIT_SR4 : begin
                           end
                           C_SM_RD_ACK1 : begin
                           end
                           C_SM_WR_DATA : begin
                               i_wr_ena  <= 1;
                               next_state <= C_SM_WAIT_SR5;
                           end
                           C_SM_WAIT_SR5 : begin
                           end
                           C_SM_RD_ACK2 : begin
                           end
                           C_SM_WAIT_SR6 : begin
                           end
                           C_SM_RESTART : begin
                               i_wr_ena  <= 1;
                           end
                           C_SM_WAIT_SR8 : begin
                           end
                           C_SM_WR_RADDR : begin
                               i_wr_ena  <= 1;
                               next_state <= C_SM_WAIT_SR9;
                           end
                           C_SM_WAIT_SR9 : begin
                           end
                           C_SM_RD_ACK3 : begin
                           end
                           C_SM_XFER_READ : begin
                               i_wr_ena  <= 1;
                               i_rd_ena <= 0;
                               rd_addr <= (ADDR_DR << 2);
                               next_state <= C_SM_RD_DATA1;
                           end
                           C_SM_RD_DATA1 : begin
                           end
                           C_SM_WAIT_SR10 : begin
                           end
                           C_SM_WR_ACK : begin
                               i_wr_ena  <= 1;
                           end
                           C_SM_SET_TXNAK: begin
                               i_wr_ena   <= 1;
                               rd_addr <= (ADDR_SR << 2);
                           end
                           C_SM_RD_DATA2 : begin
                           end
                           C_SM_WAIT_SR11 : begin
                           end
                           C_SM_RESET_MTX : begin
                               i_wr_ena  <= 1;
                           end
                           C_SM_STOP : begin
                               i_wr_ena  <= 1;
                           end
                           default : begin
                               i_wr_ena  <= 0;
                               next_state <= C_SM_IDLE;
                           end
                       endcase
                   end
               end
               else begin
                   i_rd_ena <= 1;
               end
           end

       end
   end

   endmodule

