////////////////////////////////////////////////////////////////////////////////
//                                            __ _      _     _               //
//                                           / _(_)    | |   | |              //
//                __ _ _   _  ___  ___ _ __ | |_ _  ___| | __| |              //
//               / _` | | | |/ _ \/ _ \ '_ \|  _| |/ _ \ |/ _` |              //
//              | (_| | |_| |  __/  __/ | | | | | |  __/ | (_| |              //
//               \__, |\__,_|\___|\___|_| |_|_| |_|\___|_|\__,_|              //
//                  | |                                                       //
//                  |_|                                                       //
//                                                                            //
//                                                                            //
//              MPSoC-RISCV CPU                                               //
//              Universal Asynchronous Receiver-Transmitter                   //
//              Wishbone Bus Interface                                        //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

/* Copyright (c) 2018-2019 by the author(s)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * =============================================================================
 * Author(s):
 *   Jacob Gorban <gorban@opencores.org>
 *   Igor Mohor <igorm@opencores.org>
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

`include "mpsoc_uart_wb_pkg.sv"

module mpsoc_wb_uart  #(
  parameter SIM   = 0,
  parameter DEBUG = 0
)
  (
    input                  wb_clk_i,

    // WISHBONE interface
    input                  wb_rst_i,
    input  [2:0]           wb_adr_i,
    input  [7:0]           wb_dat_i,
    output [7:0]           wb_dat_o,
    input                  wb_we_i,
    input                  wb_stb_i,
    input                  wb_cyc_i,
    input  [3:0]           wb_sel_i,
    output                 wb_ack_o,
    output                 int_o,

    // UART  signals
    input                  srx_pad_i,
    output                 stx_pad_o,
    output                 rts_pad_o,
    input                  cts_pad_i,
    output                 dtr_pad_o,
    input                  dsr_pad_i,
    input                  ri_pad_i,
    input                  dcd_pad_i,

    // optional baudrate output
    output baud_o
  );

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  wire [ 7:0] wb_dat8_i;  // 8-bit internal data input
  wire [ 7:0] wb_dat8_o;  // 8-bit internal data output
  wire [31:0] wb_dat32_o; // debug interface 32-bit output
  wire [ 2:0] wb_adr_int;
  wire        we_o;  // Write enable for registers
  wire        re_o;  // Read enable for registers

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //

  ////  WISHBONE interface module
  mpsoc_wb_uart_peripheral_bridge wb_interface (
    .clk        ( wb_clk_i   ),
    .wb_rst_i   ( wb_rst_i   ),
    .wb_dat_i   ( wb_dat_i   ),
    .wb_dat_o   ( wb_dat_o   ),
    .wb_dat8_i  ( wb_dat8_i  ),
    .wb_dat8_o  ( wb_dat8_o  ),
    .wb_dat32_o ( 32'b0      ),                 
    .wb_sel_i   ( 4'b0       ),
    .wb_we_i    ( wb_we_i    ),
    .wb_stb_i   ( wb_stb_i   ),
    .wb_cyc_i   ( wb_cyc_i   ),
    .wb_ack_o   ( wb_ack_o   ),
    .wb_adr_i   ( wb_adr_i   ),
    .wb_adr_int ( wb_adr_int ),
    .we_o       ( we_o       ),
    .re_o       ( re_o       )
  );

  // Registers
  mpsoc_wb_uart_regs #(
    .SIM (SIM)
  ) regs (
    .clk          ( wb_clk_i   ),
    .wb_rst_i     ( wb_rst_i   ),
    .wb_addr_i    ( wb_adr_int ),
    .wb_dat_i     ( wb_dat8_i  ),
    .wb_dat_o     ( wb_dat8_o  ),
    .wb_we_i      ( we_o       ),
    .wb_re_i      ( re_o       ),
    .modem_inputs ( {cts_pad_i, dsr_pad_i, ri_pad_i, dcd_pad_i} ),
    .stx_pad_o    ( stx_pad_o ),
    .srx_pad_i    ( srx_pad_i ),
    .rts_pad_o    ( rts_pad_o ),
    .dtr_pad_o    ( dtr_pad_o ),
    .int_o        ( int_o     ),
    .baud_o       ( baud_o    )
  );

  initial begin
    if(DEBUG) begin
      `ifdef UART_HAS_BAUDRATE_OUTPUT
      $display("(%m) UART INFO: Has baudrate output\n");
      `else
      $display("(%m) UART INFO: Doesn't have baudrate output\n");
      `endif
    end
  end
endmodule
