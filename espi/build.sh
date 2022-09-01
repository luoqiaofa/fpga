iverilog -o wave espi-clkgen.v \
            espi-tb.v \
            espi-module.v \
            espi-master-model.v \
            espi-slave-model.v \
            espi-top.v \
            espi-slave.v \
            ../gpio/iobuf.v \
            ../edge_detect/edge_detect.v
# reg-bit-def.v
# spi_module.v
[ $? -eq 0 ] || exit 1
vvp -n wave -lxt2
[ $? -eq 0 ] || exit 2
# gtkwave wave.vcd
