all: build simulate

build:
	ghdl -a --std=08 ../../../../../../rtl/vhdl/ahb3/pkg/peripheral_uart_ahb3_pkg.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/ahb3/core/peripheral_apb2ahb.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/ahb3/core/peripheral_uart_apb4.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/ahb3/core/peripheral_uart_fifo.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/ahb3/core/peripheral_uart_interrupt.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/ahb3/core/peripheral_uart_rx.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/ahb3/core/peripheral_uart_tx.vhd
	ghdl -a --std=08 ../../../../../../bench/vhdl/tests/core/ahb3/peripheral_uart_testbench.vhd

simulate:
	ghdl -m --std=08 peripheral_uart_testbench
	ghdl -r --std=08 peripheral_uart_testbench --ieee-asserts=disable-at-0 --disp-tree=inst > peripheral_uart_testbench.tree

clean:
	rm -f *.cf *.tree
