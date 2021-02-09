@echo off
call ../../../../../../settings64_ghdl.bat

ghdl -a --std=08 ../../../../../../rtl/vhdl/bb/pkg/msp430_pkg.vhd

ghdl -a --std=08 ../../../../../../rtl/vhdl/bb/core/fuse/msp430_sync_cell.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/bb/core/main/msp430_uart.vhd

ghdl -a --std=08 ../../../../../../bench/vhdl/tests/core/wb/mpsoc_uart_testbench.vhd
ghdl -m --std=08 mpsoc_uart_testbench
ghdl -r --std=08 mpsoc_uart_testbench --ieee-asserts=disable-at-0 --disp-tree=inst > mpsoc_uart_testbench.tree
pause
