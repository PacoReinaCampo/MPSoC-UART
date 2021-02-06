call ../../../../../../settings64_vivado.bat

xvlog -i ../../../../../../rtl/verilog/wb/pkg -prj system.prj
xelab wb_uart_tb
xsim -R wb_uart_tb
