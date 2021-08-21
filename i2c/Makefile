srcs := \
    i2c-master-byte-ctl.v \
    i2c-bit-ctl.v \
    ../divn/divn.v
tb    := tb-i2c.v
tb_mbyte := tb-mbyte.v

.PHONY: default tb-mb

default:
	iverilog -o wave -I . -I ../gpio $(srcs) ../gpio/iobuf.v i2c-top.v $(tb)
	vvp -n wave -lxt2

tb-mb:
	iverilog -o wave -I . -I ../gpio $(srcs) $(tb_mbyte)
	vvp -n wave -lxt2
