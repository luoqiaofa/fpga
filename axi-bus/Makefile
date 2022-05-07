# srcs := $(wildcard *.v) ../pwm/pwm.v
srcs := \
    axi_master_model.v \
	axi-slave.v \
	common.v \
	cpu_inf_common.v \
	pwm_inf.v \
	spi_inf.v \
	i2c_inf.v \
	tb-axi.v \
	../pwm/pwm.v

$(info srcs:=$(srcs))
default:
	echo "开始编译"
	-iverilog -o wave $(srcs)
	echo "编译完成"
	-vvp -n wave -lxt2
	# echo "生成波形文件"
	# cp wave.vcd wave.lxt
	# echo "打开波形文件"
	# gtkwave wave.vcd
	# [ $? -eq 0 ] || exit 3
