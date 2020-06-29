iverilog -o wave spi-clkgen.v spi_tb.v timescale.v
# reg-bit-def.v
# spi_module.v
[ $? -eq 0 ] || exit 1
vvp -n wave -lxt2
[ $? -eq 0 ] || exit 2
gtkwave wave.vcd
