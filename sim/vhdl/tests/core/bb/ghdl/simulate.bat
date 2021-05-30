@echo off
call ../../../../../../settings64_ghdl.bat

ghdl -a --std=08 ../../../../../../rtl/vhdl/bb/pkgvhdl_pkg.vhd

ghdl -a --std=08 ../../../../../../rtl/vhdl/bb/core/fuse/peripheral_sync_cell.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/bb/core/main/peripheral_uart_bb.vhd

ghdl -a --std=08 ../../../../../../bench/vhdl/tests/core/wb/peripheral_uart_testbench.vhd
ghdl -m --std=08 peripheral_uart_testbench
ghdl -r --std=08 peripheral_uart_testbench --ieee-asserts=disable-at-0 --disp-tree=inst > peripheral_uart_testbench.tree
pause
