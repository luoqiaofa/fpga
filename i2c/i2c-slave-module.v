`include "timescale.v"

module i2c_slv_module(
    input                i_sysclk,  // system clock input
    input                i_reset_n, // module reset input
    inout                scl_pin,   // scl pad pin
    inout                sda_pin    // sda pad pin
);
`include "i2c-def.v"
`include "i2c-reg-def.v"

wire i_sda;
wire o_sda;
reg s_sda_oen;
wire i_scl;
wire o_scl;
reg s_scl_oen;

reg [3:0] i2c_state;
reg [2:0] bit_cnt;
reg first_byte;
reg [1:0] edge_sda;
reg [1:0] edge_scl;
reg [7:0] rdata;
reg [7:0] wdata;
reg [7:0] slv_addr;
reg [3:0] i2c_cmd;

pullup scl_pu(scl_pin);
pullup sda_pu(sda_pin);

assign o_sda = s_sda_oen;
assign o_scl = s_scl_oen;

iobuf sda(
    .T  (s_sda_oen),
    .IO (sda_pin),
    .I  (o_sda),
    .O  (i_sda)
);

iobuf scl(
    .T  (s_scl_oen),
    .IO (scl_pin),
    .I  (o_scl),
    .O  (i_scl)
);

always @(posedge i_sysclk)
begin
    if (1'b0 == i_reset_n) begin
        s_sda_oen <= 1;
        s_scl_oen <= 1;
        i2c_state <= SM_IDLE;
        bit_cnt   <= 7;
        first_byte <= 1;
        edge_sda <= {i_sda, i_sda};
        edge_scl <= {i_scl, i_scl};
        rdata <= 8'hff;
        wdata <= 8'h7e;
        slv_addr <= 8'h00;
        i2c_cmd  <= CMD_IDLE;
    end
    else begin
        edge_sda <= {edge_sda[0], i_sda};
        edge_scl <= {edge_scl[0], i_scl};
        case(i2c_state)
            SM_IDLE: begin
                first_byte <= 1;
                if (2'b11 == edge_scl && 2'b10 == edge_sda) begin
                    i2c_state <= SM_START;
                end
            end
            SM_START : begin
                if (2'b10 == edge_scl && 2'b00 == edge_sda) begin
                    i2c_state <= SM_READ;
                    bit_cnt   <= 7;
                end
            end
            SM_READ : begin
                if (2'b01 == edge_scl) begin
                    rdata[bit_cnt] <= i_sda;
                end
                if (2'b10 == edge_scl) begin
                    bit_cnt <= bit_cnt - 1;
                    if (0 == bit_cnt) begin
                        if (first_byte) begin 
                            first_byte <= 0;
                            slv_addr <= {1'b0, rdata[7:1]};
                            if (rdata[0]) begin
                                i2c_cmd <= CMD_WRITE;
                            end
                            else begin
                                i2c_cmd <= CMD_READ;
                            end
                            bit_cnt   <= 7;
                            s_sda_oen <= 0;
                            i2c_state <= SM_WR_ACK;
                        end
                    end
                end
            end
            SM_WR_ACK : begin
                if (2'b01 == edge_scl) begin
                    s_sda_oen <= 0;
                end
                if (2'b10 == edge_scl) begin
                    bit_cnt   <= 7;
                    i2c_state <= SM_WRITE;
                end
            end
            SM_WRITE : begin
                if (2'b00 == edge_scl) begin
                    if (wdata[bit_cnt]) begin
                        s_sda_oen <= 1;
                    end
                    else begin
                        s_sda_oen <= 0;
                    end
                end
                else if (2'b10 == edge_scl) begin
                    bit_cnt <= bit_cnt - 1;
                    if (0 == bit_cnt) begin
                        s_sda_oen <= 1;
                        i2c_state <= SM_RD_ACK;
                    end
                end
            end
            SM_RD_ACK : begin
            end
            default : ;
        endcase
    end
end
endmodule

