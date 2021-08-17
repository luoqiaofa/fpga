// iic byte command to bit ctl
localparam CMD_IDLE    = 3'h0;
localparam CMD_START   = 3'h1;
localparam CMD_STOP    = 3'h2;
localparam CMD_WRITE   = 3'h3;
localparam CMD_READ    = 3'h4;
localparam CMD_WR_ACK  = 3'h5;
localparam CMD_RD_ACK  = 3'h6;
localparam CMD_RESTART = 3'h7;

// iic byte state machine
localparam SM_IDLE     = 3'h0;
localparam SM_START    = 3'h1;
localparam SM_STOP     = 3'h2;
localparam SM_WRITE    = 3'h3;
localparam SM_READ     = 3'h4;
localparam SM_WR_ACK   = 3'h5;
localparam SM_RD_ACK   = 3'h6;
localparam SM_RESTART  = 3'h7;

// iic bit control state machine
localparam B_IDLE      = 5'h00;
localparam B_START_A   = 5'h01;
localparam B_START_B   = 5'h02;
localparam B_START_C   = 5'h03;
localparam B_START_D   = 5'h04;
localparam B_START_E   = 5'h05;
localparam B_STOP_A    = 5'h06;
localparam B_STOP_B    = 5'h07;
localparam B_STOP_C    = 5'h08;
localparam B_STOP_D    = 5'h09;
localparam B_WRITE_A   = 5'h0A;
localparam B_WRITE_B   = 5'h0B;
localparam B_WRITE_C   = 5'h0C;
localparam B_WRITE_D   = 5'h0D;
localparam B_READ_A    = 5'h0E;
localparam B_READ_B    = 5'h0F;
localparam B_READ_C    = 5'h10;
localparam B_READ_D    = 5'h11;
localparam B_RESTART_A = 5'h12;
localparam B_RESTART_B = 5'h13;
localparam B_RESTART_C = 5'h14;
localparam B_RESTART_D = 5'h15;

