module gpio_module #(
    parameter NUM_GPIOS = 2
)
(
    input  wire                  sysclk_i,
    input  wire                  reset_n_i,
    input  wire                  wr_ena_i,
    input  wire [3:0]            wr_addr_i,
    input  wire [3:0]            wr_byte_sel_i,
    input  wire [31:0]           wr_data_i,
    input  wire                  rd_ena_i,
    input  wire [3:0]            rd_addr_i,
    output wire [31:0]           rd_data_o,
    inout  wire [NUM_GPIOS-1:0]  gpios_io
);

localparam ADDR_DATA  = 4'h0; // gpio data register
localparam ADDR_DIRS  = 4'h1; // gpio input/output 3-state control regester 

reg [31:0] GPIO_DATA;
reg [31:0] GPIO_DIRS;
reg [31:0] rd_data;
wire [NUM_GPIOS-1:0] io_t;
wire [NUM_GPIOS-1:0] io_i;
wire [NUM_GPIOS-1:0] io_o;

iosbuf #(.NUM_IO(NUM_GPIOS)) 
        iosbuf_u1 (
            .Ts  (io_t),
            .IOs (gpios_io),
            .Is  (io_o),
            .Os  (io_i)
        );

assign rd_data_o = rd_data;
integer pin, byte_idx;

genvar idx;
generate
for (idx = 0; idx < NUM_GPIOS; idx = idx + 1)
begin : dir_tris_ctl
    assign io_t[idx] = GPIO_DIRS[idx];
    assign io_o[idx] = GPIO_DATA[idx];
end
endgenerate

always @(posedge sysclk_i or negedge reset_n_i)
begin
    if (!reset_n_i) 
    begin
        rd_data   <= {{32{1'b0}}};
        GPIO_DATA <= {{32{1'b0}}}; // all pin output low;
        GPIO_DIRS <= {{32{1'b0}}}; // reset as all output;
    end
    else
    begin
        if (wr_ena_i)
        begin
            case (wr_addr_i[3:2])
                ADDR_DATA: 
                    for (byte_idx = 0; byte_idx < 4; byte_idx = byte_idx + 1)
                    begin
                        if (wr_byte_sel_i[byte_idx])
                            GPIO_DATA[(byte_idx*8) +: 8] <= wr_data_i[(byte_idx*8) +: 8];
                    end
                ADDR_DIRS: 
                    for (byte_idx = 0; byte_idx < 4; byte_idx = byte_idx + 1)
                    begin
                        if (wr_byte_sel_i[byte_idx])
                            GPIO_DIRS[(byte_idx*8) +: 8] <= wr_data_i[(byte_idx*8) +: 8];
                    end
                default  GPIO_DATA <= GPIO_DATA;
            endcase
        end
        if (rd_ena_i)
        begin
            case (rd_addr_i[3:2])
                ADDR_DATA : rd_data <= GPIO_DATA;
                ADDR_DIRS : rd_data <= GPIO_DIRS;
                default   : rd_data <= GPIO_DATA;
            endcase
        end
        for (pin = 0; pin < NUM_GPIOS; pin = pin + 1)
        begin
            if (GPIO_DIRS[pin])
                GPIO_DATA[pin] <= io_i[pin];
        end
    end
end

endmodule

