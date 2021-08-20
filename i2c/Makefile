srcs := \
    i2c-master-byte-ctl.v \
	i2c-top.v \
    i2c-bit-ctl.v \
    ../gpio/iobuf.v \
    ../divn/divn.v
tb    := tb-i2c.v
tb_mbyte := tb-mbyte.v

.PHONY: default tb-mb

default:
	iverilog -o wave -I . -I ../gpio $(srcs) $(tb)
	vvp -n wave -lxt2

tb-mb:
	iverilog -o wave -I . -I ../gpio $(filter-out i2c-top.v,$(srcs)) $(tb_mbyte)
	vvp -n wave -lxt2
