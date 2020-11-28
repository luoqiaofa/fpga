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
localparam CCR_MEN  = 7;
localparam CCR_MIEN = 6;
localparam CCR_MSTA = 5;
localparam CCR_MTX  = 4;
localparam CCR_TXAK = 3;
localparam CCR_RSTA = 2;
localparam CCR_BCST = 0;

// I2CSR
localparam SR_MCF   = 7;
localparam SR_MAAS  = 6;
localparam SR_MBB   = 5;
localparam SR_MAL   = 4;
localparam SR_BCSTM = 3;
localparam SR_SRW   = 2;
localparam SR_MIF   = 1;
localparam SR_RXAK  = 0;
// I2CDR
// I2CDFSR
localparam BIT_DFSR_HI = 6;
localparam BIT_DFSR_LO = 0;

