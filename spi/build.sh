iverilog -o wave -y ./ *.v
[ $? -eq 0 ] || exit 1
vvp -n wave -lxt2
[ $? -eq 0 ] || exit 2
gtkwave wave.vcd
