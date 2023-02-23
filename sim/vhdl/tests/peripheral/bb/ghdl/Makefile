all: build simulate

build:
	ghdl -a --std=08 ../../../../../../rtl/vhdl/pkg/peripheral/bb/vhdl_pkg.vhd

	ghdl -a --std=08 ../../../../../../rtl/vhdl/peripheral/bb/fuse/peripheral_sync_cell.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/peripheral/bb/main/peripheral_uart_bb.vhd

	ghdl -a --std=08 ../../../../../../bench/vhdl/tests/peripheral/wb/peripheral_uart_testbench.vhd

simulate:
	ghdl -m --std=08 peripheral_uart_testbench
	ghdl -r --std=08 peripheral_uart_testbench --ieee-asserts=disable-at-0 --disp-tree=inst > peripheral_uart_testbench.tree

clean:
	rm -f *.cf *.tree
