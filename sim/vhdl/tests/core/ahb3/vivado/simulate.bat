call ../../../../../../settings64_vivado.bat

xvhdl -prj system.prj
xelab mpsoc_uart_testbench
xsim -R mpsoc_uart_testbench
