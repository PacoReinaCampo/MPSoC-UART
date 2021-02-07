@echo off
call ../../../../../../settings64_vivado.bat

xvlog -i ../../../../../../rtl/verilog/ahb3/pkg -prj system.verilog.prj
xvhdl -prj system.vhdl.prj
xelab mpsoc_uart_testbench
xsim -R mpsoc_uart_testbench
pause
