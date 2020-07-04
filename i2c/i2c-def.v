// i2c registers address define
localparam ADDR_ADR    = 3'd0;
localparam ADDR_FDR    = 3'd1;
localparam ADDR_CR     = 3'd2;
localparam ADDR_SR     = 3'd3;
localparam ADDR_DR     = 3'd4;
localparam ADDR_DFSRR  = 3'd5;

// iic byte command to bit ctl
localparam CMD_IDLE   = 3'd0;
localparam CMD_START  = 3'd1;
localparam CMD_STOP   = 3'd2;
localparam CMD_WRITE  = 3'd3;
localparam CMD_READ   = 3'd4;
localparam CMD_WR_ACK = 3'd5;
localparam CMD_RD_ACK = 3'd6;

// iic byte state machine
localparam SM_IDLE    = 3'd0;
localparam SM_START   = 3'd1;
localparam SM_STOP    = 3'd2;
localparam SM_WRITE   = 3'd3;
localparam SM_READ    = 3'd4;
localparam SM_WR_ACK  = 3'd5;
localparam SM_RD_ACK  = 3'd6;

// iic bit state machine
localparam B_IDLE    = 5'd0;
localparam B_START_A = 5'd1;
localparam B_START_B = 5'd2;
localparam B_START_C = 5'd3;
localparam B_START_D = 5'd4;
localparam B_START_E = 5'd5;
localparam B_STOP_A  = 5'd6;
localparam B_STOP_B  = 5'd7;
localparam B_STOP_C  = 5'd8;
localparam B_STOP_D  = 5'd9;
localparam B_WRITE_A = 5'd10;
localparam B_WRITE_B = 5'd11;
localparam B_WRITE_C = 5'd12;
localparam B_WRITE_D = 5'd13;
localparam B_READ_A  = 5'd14;
localparam B_READ_B  = 5'd15;
localparam B_READ_C  = 5'd16;
localparam B_READ_D  = 5'd17;
localparam B_W_ACK_A = 5'd18;
localparam B_W_ACK_B = 5'd19;
localparam B_W_ACK_C = 5'd20;
localparam B_W_ACK_D = 5'd21;
localparam B_R_ACK_A = 5'd22;
localparam B_R_ACK_B = 5'd23;
localparam B_R_ACK_C = 5'd24;
localparam B_R_ACK_D = 5'd25;

