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

all: build simulate

build:
	ghdl -a --std=08 ../../../../../../../rtl/vhdl/code/pkg/core/vhdl_pkg.vhd
	ghdl -a --std=08 ../../../../../../../rtl/vhdl/code/pkg/core/peripheral_uart_pkg.vhd
	ghdl -a --std=08 ../../../../../../../rtl/vhdl/code/pkg/peripheral/wb/peripheral_wb_pkg.vhd

	ghdl -a --std=08 ../../../../../../../rtl/vhdl/code/peripheral/wb/peripheral_raminfr_wb.vhd
	ghdl -a --std=08 ../../../../../../../rtl/vhdl/code/peripheral/wb/peripheral_uart_wb.vhd
	ghdl -a --std=08 ../../../../../../../rtl/vhdl/code/peripheral/wb/peripheral_uart_peripheral_bridge_wb.vhd
	ghdl -a --std=08 ../../../../../../../rtl/vhdl/code/peripheral/wb/peripheral_uart_receiver_wb.vhd
	ghdl -a --std=08 ../../../../../../../rtl/vhdl/code/peripheral/wb/peripheral_uart_regs_wb.vhd
	ghdl -a --std=08 ../../../../../../../rtl/vhdl/code/peripheral/wb/peripheral_uart_rfifo_wb.vhd
	ghdl -a --std=08 ../../../../../../../rtl/vhdl/code/peripheral/wb/peripheral_uart_sync_flops_wb.vhd
	ghdl -a --std=08 ../../../../../../../rtl/vhdl/code/peripheral/wb/peripheral_uart_tfifo_wb.vhd
	ghdl -a --std=08 ../../../../../../../rtl/vhdl/code/peripheral/wb/peripheral_uart_transmitter_wb.vhd

	ghdl -a --std=08 ../../../../../../../bench/vhdl/code/tests/peripheral/wb/peripheral_uart_testbench.vhd

simulate:
	ghdl -e --std=08 peripheral_uart_testbench
	ghdl -r --std=08 peripheral_uart_testbench --ieee-asserts=disable-at-0 --vcd=peripheral_uart_testbench.vcd --wave=system.ghw --stop-time=1ms

clean:
	rm -f *.cf *.vcd *.ghw
