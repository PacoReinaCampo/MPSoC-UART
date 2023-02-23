all: build simulate

build:
	ghdl -a --std=08 ../../../../../../rtl/vhdl/pkg/peripheral/wb/peripheral_uart_wb_pkg.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/peripheral/wb/peripheral_raminfr_wb.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/peripheral/wb/peripheral_uart_wb.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/peripheral/wb/peripheral_uart_peripheral_bridge_wb.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/peripheral/wb/peripheral_uart_receiver_wb.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/peripheral/wb/peripheral_uart_regs_wb.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/peripheral/wb/peripheral_uart_rfifo_wb.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/peripheral/wb/peripheral_uart_sync_flops.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/peripheral/wb/peripheral_uart_tfifo_wb.vhd_wb
	ghdl -a --std=08 ../../../../../../rtl/vhdl/peripheral/wb/peripheral_uart_transmitter_wb.vhd
	ghdl -a --std=08 ../../../../../../bench/vhdl/tests/peripheral/wb/peripheral_uart_testbench.vhd

simulate:
	ghdl -m --std=08 peripheral_uart_testbench
	ghdl -r --std=08 peripheral_uart_testbench --ieee-asserts=disable-at-0 --disp-tree=inst > peripheral_uart_testbench.tree

clean:
	rm -f *.cf *.tree
