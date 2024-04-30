###################################################################################
##                                            __ _      _     _                  ##
##                                           / _(_)    | |   | |                 ##
##                __ _ _   _  ___  ___ _ __ | |_ _  ___| | __| |                 ##
##               / _` | | | |/ _ \/ _ \ '_ \|  _| |/ _ \ |/ _` |                 ##
##              | (_| | |_| |  __/  __/ | | | | | |  __/ | (_| |                 ##
##               \__, |\__,_|\___|\___|_| |_|_| |_|\___|_|\__,_|                 ##
##                  | |                                                          ##
##                  |_|                                                          ##
##                                                                               ##
##                                                                               ##
##              MPSoC-UARRT CPU                                                  ##
##              Synthesis Test Makefile                                          ##
##                                                                               ##
###################################################################################

###################################################################################
##                                                                               ##
## Copyright (c) 2018-2019 by the author(s)                                      ##
##                                                                               ##
## Permission is hereby granted, free of charge, to any person obtaining a copy  ##
## of this software and associated documentation files (the "Software"), to deal ##
## in the Software without restriction, including without limitation the rights  ##
## to use, copy, modify, merge, publish, distribute, sublicense, and/or sell     ##
## copies of the Software, and to permit persons to whom the Software is         ##
## furnished to do so, subject to the following conditions:                      ##
##                                                                               ##
## The above copyright notice and this permission notice shall be included in    ##
## all copies or substantial portions of the Software.                           ##
##                                                                               ##
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR    ##
## IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,      ##
## FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE   ##
## AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER        ##
## LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, ##
## OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN     ##
## THE SOFTWARE.                                                                 ##
##                                                                               ##
## ============================================================================= ##
## Author(s):                                                                    ##
##   Francisco Javier Reina Campo <pacoreinacampo@queenfield.tech>               ##
##                                                                               ##
###################################################################################

read_verilog -sv ../../../../rtl/verilog/code/pkg/core/peripheral_uart_pkg.sv
read_verilog -sv ../../../../rtl/verilog/code/pkg/peripheral/biu/peripheral_biu_pkg.sv

read_verilog -sv ../../../../rtl/verilog/code/peripheral/biu/peripheral_apb2ahb.sv
read_verilog -sv ../../../../rtl/verilog/code/peripheral/biu/peripheral_uart_biu.sv
read_verilog -sv ../../../../rtl/verilog/code/peripheral/biu/peripheral_uart_fifo.sv
read_verilog -sv ../../../../rtl/verilog/code/peripheral/biu/peripheral_uart_interrupt.sv
read_verilog -sv ../../../../rtl/verilog/code/peripheral/biu/peripheral_uart_rx.sv
read_verilog -sv ../../../../rtl/verilog/code/peripheral/biu/peripheral_uart_tx.sv

read_verilog -sv peripheral_uart_synthesis.sv

read_xdc system.xdc

synth_design -part xc7z020-clg484-1 -top peripheral_uart_synthesis

opt_design
place_design
route_design

report_utilization
report_timing

write_edif -force system.edif
write_bitstream -force system.bit
