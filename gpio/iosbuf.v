module iosbuf #(parameter integer NUM_IO = 2)
(
    input       [NUM_IO-1:0] Ts,
    inout  wire [NUM_IO-1:0] IOs,
    input  wire [NUM_IO-1:0] Is,
    output wire [NUM_IO-1:0] Os
);
genvar ii;
generate 
for (ii = 0; ii < NUM_IO; ii = ii + 1)
begin : my_iosbus_gen
    assign IOs[ii] = Ts[ii] ? 1'bz : Is[ii];
    assign Os[ii] = IOs[ii];
end
endgenerate

endmodule

