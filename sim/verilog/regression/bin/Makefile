all: build

build:
	@if [ ! -e work ]; then vlib work; fi
	@vlog -sv +incdir+../../../../rtl/verilog/pkg -f uart.vc
	vsim -c -do run.do work.mpsoc_uart_testbench
