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
##              Peripheral for MPSoC                                             ##
##              Multi-Processor System on Chip                                   ##
##                                                                               ##
###################################################################################

###################################################################################
##                                                                               ##
## Copyright (c) 2015-2016 by the author(s)                                      ##
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
##   Paco Reina Campo <pacoreinacampo@queenfield.tech>                           ##
##                                                                               ##
###################################################################################

../../../../../../../rtl/verilog/code/pkg/core/peripheral_uart_pkg.sv
../../../../../../../rtl/verilog/code/pkg/peripheral/wb/peripheral_wb_pkg.sv

../../../../../../../rtl/verilog/code/peripheral/wb/peripheral_raminfr_wb.sv
../../../../../../../rtl/verilog/code/peripheral/wb/peripheral_uart_wb.sv
../../../../../../../rtl/verilog/code/peripheral/wb/peripheral_uart_bridge_wb.sv
../../../../../../../rtl/verilog/code/peripheral/wb/peripheral_uart_receiver_wb.sv
../../../../../../../rtl/verilog/code/peripheral/wb/peripheral_uart_regs_wb.sv
../../../../../../../rtl/verilog/code/peripheral/wb/peripheral_uart_rfifo_wb.sv
../../../../../../../rtl/verilog/code/peripheral/wb/peripheral_uart_sync_flops_wb.sv
../../../../../../../rtl/verilog/code/peripheral/wb/peripheral_uart_tfifo_wb.sv
../../../../../../../rtl/verilog/code/peripheral/wb/peripheral_uart_transmitter_wb.sv

../../../../../../../verification/tasks/library/peripheral/wb/bus/peripheral_bfm_master_wb.sv
../../../../../../../verification/tasks/library/peripheral/wb/bus/peripheral_bfm_memory_wb.sv
../../../../../../../verification/tasks/library/peripheral/wb/bus/peripheral_bfm_slave_wb.sv
../../../../../../../verification/tasks/library/peripheral/wb/bus/peripheral_bfm_transactor_wb.sv
../../../../../../../verification/tasks/library/peripheral/wb/main/peripheral_tap_generator.sv
../../../../../../../verification/tasks/library/peripheral/wb/main/peripheral_utils_testbench.sv
../../../../../../../verification/tasks/library/peripheral/wb/main/peripheral_uart_testbench.sv
