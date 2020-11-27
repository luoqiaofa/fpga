echo "开始编译"
iverilog -o wave tb-gpio.v gpio-module.v iobuf.v iosbuf.v
[ $? -eq 0 ] || exit 1
echo "编译完成"
vvp -n wave -lxt2
[ $? -eq 0 ] || exit 2
echo "生成波形文件"
# cp wave.vcd wave.lxt
# echo "打开波形文件"
gtkwave wave.vcd
[ $? -eq 0 ] || exit 3
