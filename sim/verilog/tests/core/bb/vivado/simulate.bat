@echo off
call ../../../../../../settings64_vivado.bat

xvlog -i ../../../../../../rtl/verilog/wb/pkg -prj system.prj
xelab mpsoc_uart_testbench
xsim -R mpsoc_uart_testbench
pause
