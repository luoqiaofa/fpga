// i2c registers address define
localparam ADDR_ADR    = 6'h00;
localparam ADDR_FDR    = 6'h04;
localparam ADDR_CR     = 6'h08;
localparam ADDR_SR     = 6'h0c;
localparam ADDR_DR     = 6'h10;
localparam ADDR_DFSRR  = 6'h14;

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
localparam CSR_MCF   = 7;
localparam CSR_MAAS  = 6;
localparam CSR_MBB   = 5;
localparam CSR_MAL   = 4;
localparam CSR_BCSTM = 3;
localparam CSR_SRW   = 2;
localparam CSR_MIF   = 1;
localparam CSR_RXAK  = 0;
// I2CDR
// I2CDFSR
localparam BIT_DFSR_HI = 6;
localparam BIT_DFSR_LO = 0;

