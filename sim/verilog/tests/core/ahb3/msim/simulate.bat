@echo off
call ../../../../../../settings64_msim.bat

vlib work
vlog -sv +incdir+../../../../../../rtl/verilog/ahb3/pkg -f system.vc
vsim -c -do run.do work.mpsoc_uart_testbench
pause
