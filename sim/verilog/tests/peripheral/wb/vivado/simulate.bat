@echo off
call ../../../../../../settings64_vivado.bat

xvlog -i ../../../../../../rtl/verilog/pkg/peripheral/wb -prj system.prj
xelab peripheral_uart_testbench
xsim -R peripheral_uart_testbench
pause
