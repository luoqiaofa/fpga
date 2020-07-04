module tb_gpio;
    reg                  sysclk_i;
    reg                  reset_n_i;
    reg                  wr_ena_i;
    reg [3:0]           wr_addr_i;
    reg [3:0]            wr_byte_sel_i;
    reg [31:0]           wr_data_i;
    reg                  rd_ena_i;
    reg [3:0]            rd_addr_i;
    wire [31:0]           rd_data_o;
    wire [2-1:0]          gpios_io;

    gpio_module #(
        .GPIO_WIDTH(2)
    )
    u1 (
        .sysclk_i      (sysclk_i),
        .reset_n_i     (reset_n_i),
        .wr_ena_i      (wr_ena_i),
        .wr_addr_i     (wr_addr_i),
        .wr_byte_sel_i (wr_byte_sel_i),
        .wr_data_i     (wr_data_i),
        .rd_ena_i      (rd_ena_i),
        .rd_addr_i     (rd_addr_i),
        .rd_data_o     (rd_data_o),
        .gpios_io      (gpios_io)
    );
initial
begin
    $dumpfile("wave.vcd");
    $dumpvars(0);
    sysclk_i <= 0;
    reset_n_i <= 0;
    wr_ena_i <= 0;
    wr_data_i <= 32'h03;
    wr_addr_i <= 1 << 2;
    wr_byte_sel_i <= 4'hf;
    rd_ena_i <= 0;
    rd_addr_i <= 1 << 2;
    #10
    reset_n_i <= 1;
    #10
    wr_ena_i <= 1;
    #10
    wr_ena_i <= 0;
    #10 rd_ena_i <= 1;
    #10 rd_ena_i <= 0;
    #10
    wr_data_i <= 32'h02;
    #10
    wr_ena_i <= 1;
    rd_ena_i <= 1;
    #10
    wr_ena_i <= 0;
    wr_addr_i <= 0;
    #10
    wr_ena_i <= 1;
    #10
    wr_ena_i <= 0;
    #10
    rd_ena_i <= 0;
    #10
    wr_addr_i <= 0;
    wr_data_i <= 32'h00;
    wr_addr_i <= 1 << 2;
    #10
    wr_ena_i <= 1;
    #10
    wr_ena_i <= 0;
    #10
    wr_addr_i <= 0;
    wr_data_i <= 32'h00;
    #10
    wr_ena_i <= 1;
    #10
    wr_ena_i <= 0;

    #100
    $stop;
end
always @(*)
    #5 sysclk_i <= ~sysclk_i;
endmodule
