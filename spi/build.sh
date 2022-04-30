iverilog -o wave spi-clkgen.v \
            spi_tb.v \
            spi_module.v \
            spi_master_model.v \
            spi_slave_model.v \
            spi_top.v \
            spi-slave.v \
            ../gpio/iobuf.v \
            ../edge_detect/edge_detect.v
# reg-bit-def.v
# spi_module.v
[ $? -eq 0 ] || exit 1
vvp -n wave -lxt2
[ $? -eq 0 ] || exit 2
# gtkwave wave.vcd
