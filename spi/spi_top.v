`include "timescale.v"
/*
 * this spi module will compatible to Fresscale powerpc ESPI
 * ESPI normal operation, exclude RapidS
 * ESPI_SPMODE
 * ESPI_SPIE
 * ESPI_SPIM
 * ESPI_SPCOM
 * ESPI_SPITF
 * ESPI_SPIRF
 * ESPI_SPMODE0
 * ESPI_SPMODE1
 * ESPI_SPMODE2
 * ESPI_SPMODE3
 */
/*
 * ***************************************************************************
 * I_SPI_MODE
 * 31   RST
 * 30:8 reserved
 * 7
 * 6
 * 5
 * 4
 * 3 tx_start one risine puls to triger start
 * 2 : 1  chip seledt 0 1 2 3 for 4 cs
 * 0  EN
 * ***************************************************************************
 */
module spi_module # (
    parameter NCS = 4
)
localparam REG_WIDTH = 32;

reg [REG_WIDTH - 1: 0] SPMODE;
reg [REG_WIDTH - 1: 0] SPIE;
reg [REG_WIDTH - 1: 0] SPIM;
reg [REG_WIDTH - 1: 0] SPCOM;
reg [REG_WIDTH - 1: 0] SPITF;
reg [REG_WIDTH - 1: 0] SPIRF;
reg [REG_WIDTH - 1: 0] SPIREV1;
reg [REG_WIDTH - 1: 0] SPIREV2;
reg [REG_WIDTH - 1: 0] SPMODE0;
reg [REG_WIDTH - 1: 0] SPMODE1;
reg [REG_WIDTH - 1: 0] SPMODE2;
reg [REG_WIDTH - 1: 0] SPMODE3;

