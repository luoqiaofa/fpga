// i2c registers address define
localparam ADDR_ADR    = 3'd0;
localparam ADDR_FDR    = 3'd1;
localparam ADDR_CR     = 3'd2;
localparam ADDR_SR     = 3'd3;
localparam ADDR_DR     = 3'd4;
localparam ADDR_DFSRR  = 3'd5;

// I2CADR
localparam BIT_ADDR_HI = 7;
localparam BIT_ADDR_LO = 1;
localparam BIT_ADDR_RW = 0;

// I2CFDR
localparam BIT_FDR_HI  = 6;
localparam BIT_FDR_LO  = 0;

// I2CCR
localparam BIT_MEN  = 7;
localparam BIT_MIEN = 6;
localparam BIT_MSTA = 5;
localparam BIT_MTX  = 4;
localparam BIT_TXAK = 3;
localparam BIT_RSTA = 2;
localparam BIT_BCST = 0;

// I2CSR
localparam BIT_MCF   = 7;
localparam BIT_MAAS  = 6;
localparam BIT_MBB   = 5;
localparam BIT_MAL   = 4;
localparam BIT_BCSTM = 3;
localparam BIT_SRW   = 2;
localparam BIT_MIF   = 1;
localparam BIT_RXAK  = 0;
// I2CDR
// I2CDFSR
localparam BIT_DFSR_HI = 6;
localparam BIT_DFSR_LO = 0;

