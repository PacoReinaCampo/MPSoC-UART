call ../../../../../../settings64_msim.bat

vlib work
vlog +incdir+../../../../../../rtl/verilog/wb/pkg -f system.verilog.vc
vcom -f system.vhdl.vc
vsim -c -do run.do work.mpsoc_uart_testbench
