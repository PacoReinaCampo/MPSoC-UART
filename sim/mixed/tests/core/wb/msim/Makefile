all: build simulate

build:
	if [ ! -e work ]; then vlib work; fi
	vlog +incdir+../../../../../../rtl/verilog/pkg -f system.verilog.vc
	vcom -f system.vhdl.vc

simulate:
	vsim -c -do run.do work.mpsoc_uart_testbench

clean:
	rm -rf work transcript
