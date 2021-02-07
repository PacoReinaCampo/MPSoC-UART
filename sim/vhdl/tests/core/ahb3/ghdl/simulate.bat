@echo off
call ../../../../../../settings64_ghdl.bat

ghdl -a --std=08 ../../../../../../rtl/vhdl/ahb3/pkg/mpsoc_uart_ahb3_pkg.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/ahb3/core/mpsoc_ahb3_peripheral_bridge.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/ahb3/core/mpsoc_ahb3_uart.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/ahb3/core/mpsoc_uart_fifo.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/ahb3/core/mpsoc_uart_interrupt.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/ahb3/core/mpsoc_uart_rx.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/ahb3/core/mpsoc_uart_tx.vhd
ghdl -a --std=08 ../../../../../../bench/vhdl/tests/core/ahb3/mpsoc_uart_testbench.vhd
ghdl -m --std=08 mpsoc_uart_testbench
ghdl -r --std=08 mpsoc_uart_testbench --ieee-asserts=disable-at-0 --disp-tree=inst > mpsoc_uart_testbench.tree
pause
