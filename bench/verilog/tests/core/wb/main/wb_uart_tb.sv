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
 *   Olof Kindgren <olof.kindgren@gmail.com>
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

module wb_uart_tb;
  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //

  localparam MEMORY_SIZE = 1024;

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  reg wbm_rst = 1'b1;

  reg wb_clk = 1'b1;
  reg wb_rst = 1'b1;

  wire [31:0] wb_adr;
  wire [31:0] wb_dat;
  wire [ 3:0] wb_sel;
  wire        wb_we;
  wire        wb_cyc;
  wire        wb_stb;
  wire [ 2:0] wb_cti;
  wire [ 1:0] wb_bte;
  wire [31:0] wb_rdt;
  wire        wb_ack;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //
  vlog_tb_utils vlog_tb_utils0();

  initial #1800 wbm_rst <= 1'b0;

  initial #200 wb_rst <= 1'b0;
  always #100 wb_clk <= !wb_clk;

  mpsoc_msi_wb_bfm_transactor #(
    .MEM_HIGH (MEMORY_SIZE-1),
    .VERBOSE  (0)
  )
  master (
    .wb_clk_i (wb_clk),
    .wb_rst_i (wbm_rst),
    .wb_adr_o (wb_adr),
    .wb_dat_o (wb_dat),
    .wb_sel_o (wb_sel),
    .wb_we_o  (wb_we), 
    .wb_cyc_o (wb_cyc),
    .wb_stb_o (wb_stb),
    .wb_cti_o (wb_cti),
    .wb_bte_o (wb_bte),
    .wb_dat_i (wb_rdt),
    .wb_ack_i (wb_ack),
    .wb_err_i (1'b0),
    .wb_rty_i (1'b0),
    //Test Control
    .done(done)
  );

  always @(done) begin
    if(done === 1) begin
      $display("All tests passed!");
      $finish;
    end
  end

  mpsoc_wb_uart #(
    .SIM   (1),
    .DEBUG (0)
  )
  dut (
    .wb_clk_i (wb_clk),
    .wb_rst_i (wb_rst),

    // WISHBONE interface
    .wb_adr_i (wb_adr),
    .wb_dat_i (wb_dat),
    .wb_dat_o (wb_rdt),
    .wb_we_i  (wb_we),
    .wb_stb_i (wb_stb),
    .wb_cyc_i (wb_cyc),
    .wb_sel_i (wb_sel),
    .wb_ack_o (wb_ack),

    .int_o (),

    // UART  signals
    .srx_pad_i (),
    .stx_pad_o (),
    .rts_pad_o (),
    .cts_pad_i (),
    .dtr_pad_o (),
    .dsr_pad_i (),
    .ri_pad_i  (),
    .dcd_pad_i (),

    // optional baudrate output
    .baud_o ()
  );
endmodule
