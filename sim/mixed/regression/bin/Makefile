all: build

build:
	@if [ ! -e work ]; then vlib work; fi
	@vlog -sv +incdir+../../../../rtl/verilog/pkg -f uart_verilog.vc
	@vcom -2008 -f uart_vhdl.vc
	vsim -c -do run.do work.mpsoc_uart_testbench
