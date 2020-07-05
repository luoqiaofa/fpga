echo "开始编译"
iverilog -o wave -I . -I ../gpio i2c-top.v i2c-master-byte-ctl.v i2c-bit-ctl.v ../gpio/iobuf.v
[ $? -eq 0 ] || exit 1
echo "编译完成"
vvp -n wave -lxt2
[ $? -eq 0 ] || exit 2
echo "生成波形文件"
# cp wave.vcd wave.lxt
# echo "打开波形文件"
# gtkwave wave.vcd
[ $? -eq 0 ] || exit 3
