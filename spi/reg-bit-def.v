// ESPI regist addr
localparam ADDR_SPMODE       = 8'h00;
localparam ADDR_SPIE         = 8'h04;
localparam ADDR_SPIM         = 8'h08;
localparam ADDR_SPCOM        = 8'h0c;
localparam ADDR_SPITF        = 8'h10;
localparam ADDR_SPIRF        = 8'h14;
localparam ADDR_REV0         = 8'h18;
localparam ADDR_REV1         = 8'h1c;
localparam ADDR_SPMODE0      = 8'h20;
localparam ADDR_SPMODE1      = 8'h24;
localparam ADDR_SPMODE2      = 8'h28;
localparam ADDR_SPMODE3      = 8'h2c;

// 1. SPMODE
localparam SPMODE_EN         = 31;
localparam SPMODE_LOOP       = 30;
localparam SPMODE_HO_ADJ_HI  = 18;
localparam SPMODE_HO_ADJ_LO  = 16;
localparam SPMODE_TXTHR_HI   = 13;
localparam SPMODE_TXTHR_LO   = 8;
localparam SPMODE_RXTHR_HI   = 4;
localparam SPMODE_RXTHR_LO   = 0;

// 2. SPIE
localparam SPIE_RXCNT_HI     = 29;
localparam SPIE_RXCNT_LO     = 24;
localparam SPIE_TXCNT_HI     = 21;
localparam SPIE_TXCNT_LO     = 16;
localparam SPIE_TXE          = 15;
localparam SPIE_DON          = 14;
localparam SPIE_RXT          = 13;
localparam SPIE_RXF          = 12;
localparam SPIE_TXT          = 11;
localparam SPIE_RNE          = 9;
localparam SPIE_TNF          = 8;

// 3. SPIM
localparam SPIM_TXE          = 15;
localparam SPIM_DON          = 14;
localparam SPIM_RXT          = 13;
localparam SPIM_RXF          = 12;
localparam SPIM_TXT          = 11;
localparam SPIM_22           = 10;
localparam SPIM_RNE          = 9;
localparam SPIM_TNF          = 8;

// 4. SPCOM
localparam SPCOM_CS_HI       = 31;
localparam SPCOM_CS_LO       = 30;
localparam SPCOM_RxDELAY     = 29;
localparam SPCOM_DO          = 28;
localparam SPCOM_HLD         = 26;
localparam SPCOM_TO          = 27;
localparam SPCOM_RxSKIP_HI   = 23;
localparam SPCOM_RxSKIP_LO   = 16;
localparam SPCOM_TRANLEN_HI  = 15;
localparam SPCOM_TRANLEN_LO  = 0;

// 5. SPITF

// 6. SPIRF

// 7. ESPI_SPMODE0;
localparam SPMODEx_CI        = 31;
localparam SPMODEx_CP        = 30;
localparam SPMODEx_REV       = 29;
localparam SPMODEx_DIV16     = 28;
localparam SPMODEx_PM_HI     = 27;
localparam SPMODEx_PM_LO     = 24;
localparam SPMODEx_ODD       = 23;
localparam SPMODEx_POL       = 20;
localparam SPMODEx_LEN_HI    = 19;
localparam SPMODEx_LEN_LO    = 16;
localparam SPMODEx_CSBEF_HI  = 15;
localparam SPMODEx_CSBEF_LO  = 12;
localparam SPMODEx_CSAFT_HI  = 11;
localparam SPMODEx_CSAFT_LO  = 8;
localparam SPMODEx_CSCG_HI   = 7;
localparam SPMODEx_CSCG_LO   = 3;

