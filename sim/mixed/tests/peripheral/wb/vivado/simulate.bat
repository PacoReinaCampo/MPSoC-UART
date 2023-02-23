@echo off
call ../../../../../../settings64_vivado.bat

xvlog -i ../../../../../../rtl/verilog/pkg/peripheral/ahb3 -prj system.verilog.prj
xvhdl -prj system.vhdl.prj
xelab peripheral_uart_testbench
xsim -R peripheral_uart_testbench
pause
