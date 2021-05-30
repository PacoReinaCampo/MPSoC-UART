@echo off
call ../../../../../../settings64_vivado.bat

xvlog -i ../../../../../../rtl/verilog/ahb3/pkg -prj system.prj
xelab peripheral_uart_testbench
xsim -R peripheral_uart_testbench
pause
