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

module mpsoc_wb_uart_rfifo #(
  parameter FIFO_WIDTH     = 8,
  parameter FIFO_DEPTH     = 16,
  parameter FIFO_POINTER_W = 4,
  parameter FIFO_COUNTER_W = 5
)
  (
    input                       clk,
    input                       wb_rst_i,
    input                       push,
    input                       pop,
    input  [FIFO_WIDTH-1:0]     data_in,
    input                       fifo_reset,
    input                       reset_status,

    output     [FIFO_WIDTH    -1:0] data_out,
    output reg                      overrun,
    output reg [FIFO_COUNTER_W-1:0] count,
    output                          error_bit
  );

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  wire [7:0]            data8_out;

  // flags FIFO
  reg [2:0] fifo[FIFO_DEPTH-1:0];

  // FIFO pointers
  reg [FIFO_POINTER_W-1:0] top;
  reg [FIFO_POINTER_W-1:0] bottom;

  wire [FIFO_POINTER_W-1:0] top_plus_1 = top + 4'h1;

  wire  [2:0]  word0;
  wire  [2:0]  word1;
  wire  [2:0]  word2;
  wire  [2:0]  word3;
  wire  [2:0]  word4;
  wire  [2:0]  word5;
  wire  [2:0]  word6;
  wire  [2:0]  word7;

  wire  [2:0]  word8;
  wire  [2:0]  word9;
  wire  [2:0]  word10;
  wire  [2:0]  word11;
  wire  [2:0]  word12;
  wire  [2:0]  word13;
  wire  [2:0]  word14;
  wire  [2:0]  word15;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //
  mpsoc_wb_raminfr #(
    .ADDR_WIDTH (FIFO_POINTER_W),
    .DATA_WIDTH (8),
    .DEPTH      (FIFO_DEPTH)
  ) rfifo (
    .clk  (clk), 
    .we   (push), 
    .a    (top), 
    .dpra (bottom), 
    .di   (data_in[FIFO_WIDTH-1:FIFO_WIDTH-8]), 
    .dpo  (data8_out)
  ); 

  always @(posedge clk or posedge wb_rst_i) begin  // synchronous FIFO
    if (wb_rst_i) begin
      top      <= 0;
      bottom   <= 0;
      count    <= 0;
      fifo[0]  <= 0;
      fifo[1]  <= 0;
      fifo[2]  <= 0;
      fifo[3]  <= 0;
      fifo[4]  <= 0;
      fifo[5]  <= 0;
      fifo[6]  <= 0;
      fifo[7]  <= 0;
      fifo[8]  <= 0;
      fifo[9]  <= 0;
      fifo[10] <= 0;
      fifo[11] <= 0;
      fifo[12] <= 0;
      fifo[13] <= 0;
      fifo[14] <= 0;
      fifo[15] <= 0;
    end
    else if (fifo_reset) begin
      top      <= 0;
      bottom   <= 0;
      count    <= 0;
      fifo[0]  <= 0;
      fifo[1]  <= 0;
      fifo[2]  <= 0;
      fifo[3]  <= 0;
      fifo[4]  <= 0;
      fifo[5]  <= 0;
      fifo[6]  <= 0;
      fifo[7]  <= 0;
      fifo[8]  <= 0;
      fifo[9]  <= 0;
      fifo[10] <= 0;
      fifo[11] <= 0;
      fifo[12] <= 0;
      fifo[13] <= 0;
      fifo[14] <= 0;
      fifo[15] <= 0;
    end
    else begin
      case ({push, pop})
        2'b10 : if (count<FIFO_DEPTH) begin  // overrun condition
          top       <= top_plus_1;
          fifo[top] <= data_in[2:0];
          count     <= count + 5'd1;
        end
        2'b01 : if(count>0) begin
          fifo[bottom] <= 0;
          bottom       <= bottom + 4'd1;
          count        <= count - 5'd1;
        end
        2'b11 : begin
          bottom    <= bottom + 4'd1;
          top       <= top_plus_1;
          fifo[top] <= data_in[2:0];
        end
        default: ;
      endcase
    end
  end   // always

  always @(posedge clk or posedge wb_rst_i) begin  // synchronous FIFO
    if (wb_rst_i)
      overrun   <= 1'b0;
    else if(fifo_reset | reset_status) 
      overrun   <= 1'b0;
    else if(push & ~pop & (count==FIFO_DEPTH))
      overrun   <= 1'b1;
  end   // always

  // please note though that data_out is only valid one clock after pop signal
  assign data_out = {data8_out,fifo[bottom]};

  // Additional logic for detection of error conditions (parity and framing) inside the FIFO
  // for the Line Status Register bit 7

  assign word0 = fifo[0];
  assign word1 = fifo[1];
  assign word2 = fifo[2];
  assign word3 = fifo[3];
  assign word4 = fifo[4];
  assign word5 = fifo[5];
  assign word6 = fifo[6];
  assign word7 = fifo[7];

  assign word8  = fifo[8];
  assign word9  = fifo[9];
  assign word10 = fifo[10];
  assign word11 = fifo[11];
  assign word12 = fifo[12];
  assign word13 = fifo[13];
  assign word14 = fifo[14];
  assign word15 = fifo[15];

  // a 1 is returned if any of the error bits in the fifo is 1
  assign  error_bit = |(word0[2:0]  | word1[2:0]  | word2[2:0]  | word3[2:0]  |
                        word4[2:0]  | word5[2:0]  | word6[2:0]  | word7[2:0]  |
                        word8[2:0]  | word9[2:0]  | word10[2:0] | word11[2:0] |
                        word12[2:0] | word13[2:0] | word14[2:0] | word15[2:0] );
endmodule
