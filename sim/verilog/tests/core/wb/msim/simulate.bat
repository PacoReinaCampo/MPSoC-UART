@echo off
call ../../../../../../settings64_msim.bat

vlib work
vlog -sv +incdir+../../../../../../rtl/verilog/wb/pkg -f system.vc
vcom -2008 -f system.vhdl.vc
vsim -c -do run.do work.wb_uart_tb
pause
