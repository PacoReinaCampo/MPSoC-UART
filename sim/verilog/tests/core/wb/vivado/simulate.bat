@echo off
call ../../../../../../settings64_vivado.bat

xvlog -i ../../../../../../rtl/verilog/wb/pkg -prj system.prj
xelab peripheral_uart_testbench
xsim -R peripheral_uart_testbench
pause
