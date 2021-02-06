call ../../../../../../settings64_iverilog.bat

iverilog -g2012 -o system.vvp -c system.vc -s mpsoc_uart_testbench -I ../../../../../../rtl/verilog/wb/pkg
vvp system.vvp
