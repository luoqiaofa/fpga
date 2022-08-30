localparam REG_WIDTH          = 32;
localparam NBITS_PER_WORD     = 32;
localparam NBITS_PER_BYTE     = 8;
localparam NBYTES_PER_WORD    = (NBITS_PER_WORD / NBITS_PER_BYTE);
localparam NBITS_CHAR_LEN_MAX = 32;
localparam C_ADDR_WIDTH       = 8;
localparam C_DATA_WIDTH       = 32;

// SPI regist addr
localparam ADDR_SPMODE        = 8'h00;
localparam ADDR_SPIE          = 8'h04;
localparam ADDR_SPIM          = 8'h08;
localparam ADDR_SPCOM         = 8'h0c;
localparam ADDR_SPITD         = 8'h10;
localparam ADDR_SPIRD         = 8'h14;
localparam ADDR_REV0          = 8'h18;
localparam ADDR_REV1          = 8'h1c;
localparam ADDR_CSMODE0       = 8'h20;
localparam ADDR_CSMODE1       = 8'h24;
localparam ADDR_CSMODE2       = 8'h28;
localparam ADDR_CSMODE3       = 8'h2c;

// 1. SPMODE
localparam SPMODE_EN          = 31;
localparam SPMODE_LOOP        = 30;
localparam SPMODE_MASTER      = 29;

// 2. SPIE
localparam SPIE_RXCNT_HI      = 29;
localparam SPIE_RXCNT_LO      = 24;
localparam SPIE_DON           = 14;
localparam SPIE_DNR           = 13;
localparam SPIE_OV            = 12;
localparam SPIE_UN            = 11;
localparam SPIE_MME           = 10;
localparam SPIE_RNE           = 9;
localparam SPIE_TNF           = 8;

// 3. SPIM
localparam SPIM_DON           = SPIE_DON;
localparam SPIM_DNR           = SPIE_DNR;
localparam SPIM_OV            = SPIE_OV;
localparam SPIM_UN            = SPIE_UN;
localparam SPIM_MME           = SPIE_MME;
localparam SPIM_RNE           = SPIE_RNE;
localparam SPIM_TNF           = SPIE_TNF;

// 4. SPCOM
localparam SPCOM_CS_HI        = 31;
localparam SPCOM_CS_LO        = 30;
// localparam SPCOM_RXDLY       = 29; // reserved
// localparam SPCOM_DO          = 28; // reserved
localparam SPCOM_TO           = 27; // Transmit only
// localparam SPCOM_RO          = 26; // Receive only
localparam SPCOM_RSKIP_HI     = 23; // number of chars need to be read skip
localparam SPCOM_RSKIP_LO     = 16;
localparam SPCOM_TRANLEN_HI   = 15;
localparam SPCOM_TRANLEN_LO   = 0;

// 5. SPITD

// 6. SPIRD

// 7. SPI_SPMODE0 ~ SPI_SPMODEx ;
localparam CSMODE_CPOL        = 31; /* CI: clock inverted, clock polarity */
localparam CSMODE_CPHA        = 30; /* CP: clock phase */
localparam CSMODE_REV         = 29;
localparam CSMODE_DIV16       = 28;
localparam CSMODE_PM_HI       = 27;
localparam CSMODE_PM_LO       = 24;
// read data from MOSI pin, some spi slave use one pin for rx and tx
// that is sdio pin. at this time, RXSKIP must bigger than 0;
localparam CSMODE_IS3WIRE     = 23;
localparam CSMODE_POL         = 20; /* cs polarity */
localparam CSMODE_LEN_HI      = 19;
localparam CSMODE_LEN_LO      = 16;
localparam CSMODE_CSBEF_HI    = 15;
localparam CSMODE_CSBEF_LO    = 12;
localparam CSMODE_CSAFT_HI    = 11;
localparam CSMODE_CSAFT_LO    = 8;
localparam CSMODE_CSCG_HI     = 7;
localparam CSMODE_CSCG_LO     = 3;

// num bits define
localparam NBITS_CS           = SPCOM_CS_HI - SPCOM_CS_LO + 1;
localparam NBITS_RSKIP        = SPCOM_RSKIP_HI - SPCOM_RSKIP_LO + 1;
localparam NBITS_TRANLEN      = SPCOM_TRANLEN_HI - SPCOM_TRANLEN_LO + 1;
localparam NBITS_PM           = CSMODE_PM_HI    - CSMODE_PM_LO + 1;
localparam NBITS_CHARLEN      = CSMODE_LEN_HI   - CSMODE_LEN_LO + 1;
localparam NBITS_CSBEF        = CSMODE_CSBEF_HI - CSMODE_CSBEF_LO + 1;
localparam NBITS_CSAFT        = CSMODE_CSAFT_HI - CSMODE_CSAFT_LO + 1;
localparam NBITS_CSCG         = CSMODE_CSCG_HI  - CSMODE_CSCG_LO + 1;
localparam NBITS_RXCNT        = SPIE_RXCNT_HI   - SPIE_RXCNT_LO + 1;

// defaut register value
localparam SPMODE_DEF         = 32'h0000_0000;
localparam SPIE_DEF           = 32'h0000_0000;
localparam SPIM_DEF           = 32'h0000_0000;
localparam SPCOM_DEF          = 32'h0000_0000;
localparam SPITD_DEF          = 32'h0000_0000;
localparam SPIRD_DEF          = 32'hffff_ffff;
localparam CSMODE_DEF         = 1 << CSMODE_POL;

