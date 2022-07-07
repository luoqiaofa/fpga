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
   reg           i_sysclk;  // system clock input
   reg           i_reset_n; // module reset input
   wire [5:0]    s_awaddr;
   wire [7:0]    s_wdata;
   wire          s_wen; 
   wire          s_rden; 
   wire [5:0]    s_araddr; // read date output
   wire [7:0]    s_rdata; // read date output
   wire          s_scl_pin;   // scl pad pin
   wire          s_sda_pin;    // sda pad pin
   wire          s_i2c_irq;

   reg [7:0] i2cadr;
   reg [7:0] i2cfdr;
   reg [7:0] i2ccr;
   reg [7:0] i2csr;
   reg [7:0] i2cdr;
   reg [7:0] i2cdfsrr;

   i2c_top_module i2c_master_u1(
       .i_sysclk(i_sysclk),   // system clock input
       .i_reset_n(i_reset_n), // module reset input
       .i_wr_ena(s_wen),   // write enable
       .i_wr_addr(s_awaddr), // write address
       .i_wr_data(s_wdata), // write date input
       .i_rd_ena(s_rden),   // read enable input
       .i_rd_addr(s_araddr), // read address input
       .o_rd_data(s_rdata), // read date output
       .o_interrupt(s_i2c_irq),
       .scl_pin(s_scl_pin),     // scl pad pin
       .sda_pin(s_sda_pin)      // sda pad pin
   );

i2c_slv_module slv_dev(
    .i_sysclk(i_sysclk),   // system clock input
    .i_reset_n(i_reset_n), // module reset input
    .scl_pin(s_scl_pin),     // scl pad pin
    .sda_pin(s_sda_pin)      // sda pad pin
);

initial
begin
    $dumpfile("wave.vcd");    //生成的vcd文件名称
    $dumpvars(0);   //tb模块名称
    #600000
    i_reset_n <= 0;
    #1000
    $stop;
    $finish;
end

localparam CCR_VAL_WR       = (1 << CCR_MIEN) | (1 << CCR_MEN) | (1 << CCR_MSTA) | (1 << CCR_MTX);
localparam CCR_VAL_RD_1BYTE = (1 << CCR_MIEN) | (1 << CCR_MEN) | (1 << CCR_MSTA) | (1 << CCR_TXAK);

initial
begin
    i_reset_n <= 0;
    i_sysclk <= 0;

    i2cadr <= 0;
    i2cfdr <= 0;
    i2ccr <= 0;
    i2csr <= 0;
    i2cdr <= 0;
    i2cdfsrr <= 0;
    #100
    i_reset_n <= 1;
    #100
    i2cbus.regread(ADDR_ADR, i2cadr, 0);
    i2cbus.regread(ADDR_FDR, i2cfdr, 0);
    i2cbus.regread(ADDR_CR, i2ccr, 0);
    i2cbus.regread(ADDR_SR, i2csr, 0);
    i2cbus.regread(ADDR_DR, i2cdr, 0);
    i2cbus.regread(ADDR_DFSRR, i2cdfsrr, 0);
    i2cbus.regwrite(ADDR_FDR, 8'h07, 0);
    i2cbus.regread(ADDR_FDR, i2cfdr, 0);
    #100
    /* case#1 */
    $display("[%t]case#1 addres then read one byte", $time);
    /* mpc_i2c_start */
    $display("[%t] mpc_i2c_start... ", $time);
    /* Clear arbitration */
    i2cbus.regwrite(ADDR_SR, 8'h00, 0);
    /* Start with MEN */
    i2cbus.regwrite(ADDR_CR, 8'h80, 0);
    /* mpc_i2c_start */
    $display("[%t] mpc_i2c_start done. ", $time);
    /* wait i2c bus is not idle */
    i2cbus.regread(ADDR_SR, i2csr, 0);
    $display("[%t] check i2c bus is busy or not, CSR_MBB=%d", $time, i2csr[CSR_MBB]);
    while (1'b1 == i2csr[CSR_MBB]) begin
        #100
        i2cbus.regread(ADDR_SR, i2csr, 0);
    end
    /* start i2c start condition */
    i2cbus.regwrite(ADDR_SR, 0, 0);
    $display("[%t] init ccr=0x%02h", $time, CCR_VAL_WR);
    i2cbus.regwrite(ADDR_CR, CCR_VAL_WR, 0);
    /* Write target address byte - this time with the read flag set */
    i2cbus.regwrite(ADDR_DR, 8'ha1, 0); /* slave addr 0x50, read op */
    /* i2c_wait CSR_MIF to be set */
    i2cbus.regread(ADDR_SR, i2csr, 0);
    $display("[%t] i2c_wait CSR_MIF=%d", $time, i2csr[CSR_MIF]);
    while (1'b0 == i2csr[CSR_MIF]) begin
        #100
        i2cbus.regread(ADDR_SR, i2csr, 0);
    end
    i2cbus.regwrite(ADDR_SR, 0, 0);
    $display("[%t] i2c_wait done. CSR_MIF=%d", $time, i2csr[CSR_MIF]);
    /* read only one bytes */
    $display("[%t] init ccr=0x%02h, read one byte, and na-ack", $time, CCR_VAL_RD_1BYTE);
    i2cbus.regwrite(ADDR_CR, CCR_VAL_RD_1BYTE, 0);
    /* Dummy read to trigger i2c read circle */
    $display("[%t] Dummy read I2CDR to trigg i2c read operaion", $time);
    i2cbus.regread(ADDR_DR, i2cdr, 0);
    /* i2c_wait CSR_MIF to be set */
    i2cbus.regread(ADDR_SR, i2csr, 0);
    $display("[%t] CSR_MIF=%d i2c_wait ... ", $time, i2csr[CSR_MIF]);
    while (1'b0 == i2csr[CSR_MIF]) begin
        #100
        i2cbus.regread(ADDR_SR, i2csr, 0);
    end
    i2cbus.regwrite(ADDR_SR, 0, 0);
    $display("[%t] CSR_MIF=%d i2c_wait done.", $time, i2csr[CSR_MIF]);
    /* Do not generate stop on last byte */
    $display("[%t] init ccr=0x%02h", $time, CCR_VAL_WR);
    i2cbus.regwrite(ADDR_CR, CCR_VAL_WR, 0);

    /* read i2c data */
    i2cbus.regread(ADDR_DR, i2cdr, 0);

    /* mpc_i2c_stop---Initiate STOP */
    $display("[%t] mpc_i2c_stop. init ccr=0x80", $time);
    i2cbus.regwrite(ADDR_CR, 8'h80, 0);
    $display("[%t] mpc_i2c_stop done", $time);
    /* mpc_i2c_stop */
    /* Wait until STOP is seen, allow up to 1 s */
    i2cbus.regwrite(ADDR_SR, 0, 0);
    i2cbus.regread(ADDR_SR, i2csr, 0);
    while (1'b1 == i2csr[CSR_MBB]) begin
        #100
        i2cbus.regread(ADDR_SR, i2csr, 0);
    end
    /* case#1 */

end

always #5 i_sysclk = ~i_sysclk;

i2c_reg_module i2cbus(
    .i_sysclk(i_sysclk),  // system clock input
    .i_reset_n(i_reset_n), // module reset input
    .o_wr_ena(s_wen),  // write enable
    .o_wr_addr(s_awaddr), // write address
    .o_wr_data(s_wdata), // write date input
    .o_rd_ena(s_rden),  // read enable input
    .o_rd_addr(s_araddr), // read address input
    .i_rd_data(s_rdata)  // read date output
);
endmodule

