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
##              MPSoC-UART CPU                                                   ##
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

read_vhdl -vhdl2008 ../../../../rtl/vhdl/code/pkg/core/peripheral_uart_pkg.vhd
read_vhdl -vhdl2008 ../../../../rtl/vhdl/code/pkg/core/vhdl_pkg.vhd
read_vhdl -vhdl2008 ../../../../rtl/vhdl/code/pkg/peripheral/tl/peripheral_biu_pkg.vhd

read_vhdl -vhdl2008 ../../../../rtl/vhdl/code/peripheral/tl/peripheral_apb2ahb.vhd
read_vhdl -vhdl2008 ../../../../rtl/vhdl/code/peripheral/tl/peripheral_uart_tl.vhd
read_vhdl -vhdl2008 ../../../../rtl/vhdl/code/peripheral/tl/peripheral_uart_fifo.vhd
read_vhdl -vhdl2008 ../../../../rtl/vhdl/code/peripheral/tl/peripheral_uart_interrupt.vhd
read_vhdl -vhdl2008 ../../../../rtl/vhdl/code/peripheral/tl/peripheral_uart_rx.vhd
read_vhdl -vhdl2008 ../../../../rtl/vhdl/code/peripheral/tl/peripheral_uart_tx.vhd

read_vhdl -vhdl2008 peripheral_uart_synthesis.vhd

read_xdc system.xdc

synth_design -part xc7z020-clg484-1 -top peripheral_uart_synthesis

opt_design
place_design
route_design

report_utilization
report_timing

write_edif -force system.edif
write_bitstream -force system.bit
