all: build

build:
	@if [ ! -e work ]; then vlib work; fi
	@vcom -2008 -f uart.vc
	vsim -c -do run.do work.mpsoc_uart_testbench
