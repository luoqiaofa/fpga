srcs := $(wildcard *.v) ../pwm/ax_pwm.v
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
