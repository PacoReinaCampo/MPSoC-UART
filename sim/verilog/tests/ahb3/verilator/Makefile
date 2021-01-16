all: build simulate

build:
	verilator -Wno-lint +incdir+../../../../../rtl/verilog/ahb3/pkg --cc -f system.vc --top-module mpsoc_uart_testbench

simulate:

clean:
	rm -rf obj_dir
