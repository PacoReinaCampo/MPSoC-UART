all: build simulate

build:
	iverilog -g2012 -o system.vvp -c system.vc -s mpsoc_uart_testbench -I ../../../../../rtl/verilog/ahb3/pkg

simulate:
	vvp system.vvp

clean:
	rm -rf system.vvp
