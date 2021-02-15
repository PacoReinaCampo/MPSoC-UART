all: build simulate

build:
	verilator -Wno-lint --cc -f system.vc --top-module mpsoc_uart_testbench

simulate:

clean:
	rm -rf obj_dir
