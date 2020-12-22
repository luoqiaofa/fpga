`include "timescale.v"

module spi_tb;
    localparam C_DIVIDER_WIDTH = 8;
    localparam CHAR_NBITS = 8;
    reg sysclk;            // system clock input
    reg rst_n;             // module reset
    reg enable;            // module enable
    reg go;                // start transmit
    reg CPOL;              // clock polarity
    reg CPHA;              // clock phase
    reg LOOP;              // loop mode test
    reg last_clk;          // last clock 
    reg [C_DIVIDER_WIDTH-1:0] divider_i; // divider;
    wire clk_out;          // clock output
    wire pos_edge;         // positive edge flag
    wire neg_edge;         // negtive edge flag
    reg [4:0] bit_cnt;
    wire [1:0] spi_mode;
    reg [CHAR_NBITS - 1: 0] data_out;
    reg [CHAR_NBITS - 1: 0] data_in;
    reg [4: 0] shift_cnt;
    reg [CHAR_NBITS:0] shift_tx;
    reg [CHAR_NBITS:0] shift_rx;
    reg dout;
    wire mosi;
    wire miso;
    wire pos_edge_rx;         // positive edge flag
    wire neg_edge_rx;         // positive edge flag

pullup pullup_miso (miso);
// assign mosi = dout;
assign spi_mode = {CPHA, CPOL};
assign pos_edge_rx = clk_out;
assign neg_edge_rx = clk_out;

// always @(negedge neg_edge or negedge rst_n)
// begin
//     if (!rst_n || !enable)
//         ;
//     else 
//     begin
//         case (spi_mode)
//             2'b00:
//             begin
//                 if (last_clk & go) 
//                 begin
//                     go <= 0;
//                     last_clk <= 0;
//                 end
//             end
//             2'b01:
//             begin
//                 bit_cnt <= bit_cnt - 5'h1;
//                 if (bit_cnt == 5'h0) 
//                 begin
//                     last_clk <= 1;
//                     bit_cnt <= (CHAR_NBITS - 1);
//                 end
//             end
//             2'b10:
//             begin
//                 if (last_clk & go) 
//                 begin
//                     go <= 0;
//                     last_clk <= 0;
//                 end
//             end
//             2'b11:
//             begin
//                 bit_cnt <= bit_cnt - 5'h1;
//                 if (bit_cnt == 5'h0) 
//                 begin
//                     last_clk <= 1;
//                     bit_cnt <= (CHAR_NBITS - 1);
//                 end
//             end
//         endcase
//     end
// end
// 
// always @(negedge pos_edge or negedge rst_n)
// begin
//     if (!rst_n || !enable)
//         bit_cnt <= (CHAR_NBITS - 1);
//     else 
//     begin
//         case (spi_mode)
//             2'b00:
//             begin
//                 bit_cnt <= bit_cnt - 5'h1;
//                 if (bit_cnt == 5'h0) 
//                 begin
//                     last_clk <= 1;
//                     bit_cnt <= (CHAR_NBITS - 1);
//                 end
//             end
//             2'b01:
//             begin
//                 if (last_clk & go) 
//                 begin
//                     go <= 0;
//                     last_clk <= 0;
//                 end
//             end
//             2'b10:
//             begin
//                 bit_cnt <= bit_cnt - 5'h1;
//                 if (bit_cnt == 5'h0) 
//                 begin
//                     last_clk <= 1;
//                     bit_cnt <= (CHAR_NBITS - 1);
//                 end
//             end
//             2'b11:
//             begin
//                 if (last_clk & go) 
//                 begin
//                     go <= 0;
//                     last_clk <= 0;
//                 end
//             end
//         endcase
//     end
// end

initial
begin            
    $dumpfile("wave.vcd");        //生成的vcd文件名称
    $dumpvars(0, spi_tb);    //tb模块名称
end

//spi_clk_gen # (.C_DIVIDER_WIDTH(8)) clk_gen (
//    .sysclk(sysclk),       // system clock input
//    .rst_n(rst_n),         // module reset
//    .enable(enable),       // module enable
//    .go(go),               // start transmit
//    .CPOL(CPOL),           // clock polarity
//    .last_clk(last_clk),   // last clock 
//    .divider_i(divider_i), // divider;
//    .clk_out(clk_out),     // clock output
//    .pos_edge(pos_edge),   // positive edge flag
//    .neg_edge(neg_edge)    // negtive edge flag
//);
wire s_done;
wire  [15:0] rdata;
spi_trx_one_char #(.CHAR_LEN_MAX(16))
inst_spi_trx_ch
(
    .S_SYSCLK(sysclk),  // platform clock
    .S_RESETN(rst_n),  // reset
    .S_ENABLE(enable),  // enable
    .S_CPOL(CPOL),    // clock polary
    .S_CPHA(CPHA),    // clock phase, the first edge or second
    .S_TX_ONLY(1'b0), // transmit only
    .S_LOOP(LOOP),    // internal loopback mode
    .S_REV(1'b0),     // msb first or lsb first
    .S_CHAR_LEN(4'h7),// characters in bits length
    .S_NDIVIDER(divider_i),// clock divider
    .S_SPI_SCK(clk_out),
    .S_SPI_MISO(miso),
    .S_SPI_MOSI(mosi),
    .S_CHAR_GO(go),
    .S_CHAR_DONE(s_done),
    .S_WCHAR(16'h55aa),   // output character
    .S_RCHAR(rdata)    // input character
);

always @(posedge s_done)
begin
    go <= 0;
end

// 100 MHz axi clock input
always @(sysclk)
    #5 sysclk <= !sysclk;

// always @(posedge pos_edge_rx or negedge rst_n)
// begin
//     if (!rst_n || !enable)
//     begin
//         data_in  <= {CHAR_NBITS{1'b1}};
//     end
//     else
//     begin
//         if (enable)
//         begin
//         case (spi_mode)
//             2'b00:
//             begin
//                 if (LOOP)
//                 begin
//                     shift_rx[shift_cnt] <= dout;
//                 end
//                 if (0 == shift_cnt)
//                 begin
//                     data_in  <= {shift_rx[CHAR_NBITS-1:1], dout};
//                 end
//             end
//             2'b01:
//             begin
//                 shift_cnt <= shift_cnt - 1;
//                 if (0 == shift_cnt)
//                 begin
//                     shift_cnt <= CHAR_NBITS - 1;
//                 end
//             end
//             2'b10:
//             begin
//                 shift_cnt <= shift_cnt - 1;
//                 if (0 == shift_cnt)
//                 begin
//                     shift_cnt <= CHAR_NBITS;
//                 end
//             end
//             2'b11:
//             begin
//                 if (LOOP)
//                 begin
//                     shift_rx[shift_cnt] <= dout;
//                 end
//                 if (0 == shift_cnt)
//                 begin
//                     data_in  <= {shift_rx[CHAR_NBITS-1:1], dout};
//                 end
//             end
//         endcase
//         end
//     end
// end
// 
// always @(negedge neg_edge_rx or negedge rst_n)
// begin
//     if (!rst_n || !enable)
//     begin
//     end
//     else
//     begin
//         if (enable)
//         begin
//         case (spi_mode)
//             2'b00:
//             begin
//                 shift_cnt <= shift_cnt - 1;
//                 if (0 == shift_cnt)
//                 begin
//                     shift_cnt <= CHAR_NBITS - 1;
//                 end
//             end
//             2'b01:
//             begin
//                 if (LOOP)
//                 begin
//                     shift_rx[shift_cnt] <= dout;
//                 end
//                 if (0 == shift_cnt)
//                 begin
//                     data_in  <= {shift_rx[CHAR_NBITS-1:1], dout};
//                 end
//             end
//             2'b10:
//             begin
//                 if (LOOP)
//                 begin
//                     shift_rx[shift_cnt] <= dout;
//                 end
//                 if (0 == shift_cnt)
//                 begin
//                     data_in  <= {shift_rx[CHAR_NBITS-1:1], dout};
//                 end
//             end
//             2'b11:
//             begin
//                 shift_cnt <= shift_cnt - 1;
//                 if (0 == shift_cnt)
//                 begin
//                     shift_cnt <= CHAR_NBITS;
//                 end
//                 if (LOOP)
//                 begin
//                     shift_rx[shift_cnt] <= dout;
//                 end
//             end
//         endcase
//         end
//     end
// end
// 
// always @(posedge sysclk or negedge rst_n)
// begin
//     if (!rst_n || !enable)
//     begin
//         dout <= 1'b0;
//         shift_rx <= {1'b1, {CHAR_NBITS{1'b1}}};
//         shift_tx <= {1'b0, data_out};
//         case (spi_mode)
//             2'b00:
//             begin
//                 shift_cnt <= CHAR_NBITS - 1;
//             end
//             2'b01:
//             begin
//                 shift_cnt <= CHAR_NBITS - 1;
//             end
//             2'b10:
//             begin
//                 shift_cnt <= CHAR_NBITS;
//             end
//             2'b11:
//             begin
//                 shift_cnt <= CHAR_NBITS;
//             end
//         endcase
//     end
//     else
//     begin
//         if (enable)
//         begin
//             // last_clk <= last_clk;
//             // go <= go;
//             dout <= shift_tx[shift_cnt];
//             shift_rx <= shift_rx;
//             shift_cnt <= shift_cnt;
//         end
//     end
// end

initial
begin            
    data_in    <= 8'hff;
    data_out   <= 8'h5a;
    bit_cnt    <= 5'h7;
    sysclk     <= 0;      // system clock input
    rst_n      <= 0;      // module reset
    enable     <= 0;      // module enable
    go         <= 0;      // start transmit
    CPOL       <= 0;      // clock polarity
    CPHA       <= 1;      // clock phase
    LOOP       <= 1;
    last_clk   <= 0;      // last clock 
    divider_i  <= 0;      // divider;
    #100
    rst_n    <= 1;        // module reset
    #10
    divider_i  <= 8'h04;  // divider; sys clk % 10 prescaler
    #30
    enable       <= 1;    // module enable
    #30
    go       <= 1;        // start transmit
    #(1000 * CHAR_NBITS / 8)
    data_in  <= {CHAR_NBITS{1'b1}};
    case (spi_mode)
        2'b00:
        begin
            shift_cnt <= CHAR_NBITS - 1;
        end
        2'b01:
        begin
            shift_cnt <= CHAR_NBITS - 1;
        end
        2'b10:
        begin
            shift_cnt <= CHAR_NBITS;
        end
        2'b11:
        begin
            shift_cnt <= CHAR_NBITS;
        end
    endcase
    go       <= 1;        // start transmit
    #(1000 * CHAR_NBITS / 8)
    // #50
    enable       <= 0;   // module enable

    #1000
    $stop;
end


endmodule

