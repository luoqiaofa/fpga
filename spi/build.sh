iverilog -o wave spi-clkgen.v \
            spi-tb.v \
            spi-module.v \
            spi-master-model.v \
            spi-slave-model.v \
            spi-top.v \
            spi-slave.v \
            ../gpio/iobuf.v \
            ../edge_detect/edge_detect.v
# reg-bit-def.v
# spi_module.v
[ $? -eq 0 ] || exit 1
vvp -n wave -lxt2
[ $? -eq 0 ] || exit 2
# gtkwave wave.vcd
