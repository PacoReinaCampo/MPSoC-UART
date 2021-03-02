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
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

`include "mpsoc_uart_wb_pkg.sv"

module mpsoc_wb_uart_peripheral_bridge (
  input              clk,

  // WISHBONE interface  
  input              wb_rst_i,
  input              wb_we_i,
  input              wb_stb_i,
  input              wb_cyc_i,
  input      [ 3:0]  wb_sel_i,
  input      [ 2:0]  wb_adr_i,  //WISHBONE address line

  input      [ 7:0] wb_dat_i,   //input WISHBONE bus 
  output reg [ 7:0] wb_dat_o,
  output     [ 2:0] wb_adr_int, // internal signal for address bus
  input      [ 7:0] wb_dat8_o,  // internal 8 bit output to be put into wb_dat_o
  output reg [ 7:0] wb_dat8_i,
  input      [31:0] wb_dat32_o, // 32 bit data output (for debug interface)
  output reg        wb_ack_o,
  output            we_o,
  output            re_o
);

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  reg  [7:0] wb_dat_is;
  reg  [2:0] wb_adr_is;
  reg        wb_we_is;
  reg        wb_cyc_is;
  reg        wb_stb_is;

  reg        wre;  // timing control signal for write or read enable

  // wb_ack_o FSM
  reg [1:0] wbstate;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //
  always  @(posedge clk or posedge wb_rst_i)
    if (wb_rst_i) begin
      wb_ack_o <= 1'b0;
      wbstate  <= 0;
      wre      <= 1'b1;
    end else
      case (wbstate)
        0: begin
          if (wb_stb_is & wb_cyc_is) begin
            wre <= 0;
            wbstate  <= 1;
            wb_ack_o <= 1;
          end
          else begin
            wre      <= 1;
            wb_ack_o <= 0;
          end
        end
        1: begin
          wb_ack_o <= 0;
          wbstate  <= 2;
          wre      <= 0;
        end
        2: begin
          wb_ack_o <= 0;
          wbstate  <= 3;
          wre      <= 0;
        end
        3: begin
          wb_ack_o <= 0;
          wbstate  <= 0;
          wre      <= 1;
        end
      endcase

  assign we_o =  wb_we_is & wb_stb_is & wb_cyc_is & wre ; //WE for registers  
  assign re_o = ~wb_we_is & wb_stb_is & wb_cyc_is & wre ; //RE for registers  

  // Sample input signals
  always  @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) begin
      wb_adr_is <= 0;
      wb_we_is  <= 0;
      wb_cyc_is <= 0;
      wb_stb_is <= 0;
      wb_dat_is <= 0;
    end
    else begin
      wb_adr_is <= wb_adr_i;
      wb_we_is  <= wb_we_i;
      wb_cyc_is <= wb_cyc_i;
      wb_stb_is <= wb_stb_i;
      wb_dat_is <= wb_dat_i;
    end
  end

  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i)
      wb_dat_o <= 0;
    else
      wb_dat_o <= wb_dat8_o;
  end

  always @(wb_dat_is) begin
    wb_dat8_i = wb_dat_is;
  end

  assign wb_adr_int = wb_adr_is;
endmodule
