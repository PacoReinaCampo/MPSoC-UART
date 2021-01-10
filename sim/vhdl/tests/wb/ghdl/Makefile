all: build simulate

build:
	ghdl -a --std=08 ../../../../../rtl/vhdl/wb/pkg/mpsoc_uart_wb_pkg.vhd
	ghdl -a --std=08 ../../../../../rtl/vhdl/wb/core/mpsoc_wb_raminfr.vhd
	ghdl -a --std=08 ../../../../../rtl/vhdl/wb/core/mpsoc_wb_uart.vhd
	ghdl -a --std=08 ../../../../../rtl/vhdl/wb/core/mpsoc_wb_uart_peripheral_bridge.vhd
	ghdl -a --std=08 ../../../../../rtl/vhdl/wb/core/mpsoc_wb_uart_receiver.vhd
	ghdl -a --std=08 ../../../../../rtl/vhdl/wb/core/mpsoc_wb_uart_regs.vhd
	ghdl -a --std=08 ../../../../../rtl/vhdl/wb/core/mpsoc_wb_uart_rfifo.vhd
	ghdl -a --std=08 ../../../../../rtl/vhdl/wb/core/mpsoc_wb_uart_sync_flops.vhd
	ghdl -a --std=08 ../../../../../rtl/vhdl/wb/core/mpsoc_wb_uart_tfifo.vhd
	ghdl -a --std=08 ../../../../../rtl/vhdl/wb/core/mpsoc_wb_uart_transmitter.vhd
	ghdl -a --std=08 ../../../../../bench/vhdl/tests/wb/mpsoc_uart_testbench.vhd

simulate:
	ghdl -m --std=08 mpsoc_uart_testbench
	ghdl -r --std=08 mpsoc_uart_testbench --ieee-asserts=disable-at-0 --disp-tree=inst > mpsoc_uart_testbench.tree

clean:
	rm -f *.cf *.tree
