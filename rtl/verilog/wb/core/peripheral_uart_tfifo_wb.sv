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

module mpsoc_wb_uart_tfifo #(
  parameter FIFO_WIDTH     = 8,
  parameter FIFO_DEPTH     = 16,
  parameter FIFO_POINTER_W = 4,
  parameter FIFO_COUNTER_W = 5
)
  (
    input                           clk,
    input                           wb_rst_i,
    input                           push,
    input                           pop,
    input      [FIFO_WIDTH-1:0]     data_in,
    input                           fifo_reset,
    input                           reset_status,

    output     [FIFO_WIDTH-1:0]     data_out,
    output reg                      overrun,
    output reg [FIFO_COUNTER_W-1:0] count
  );

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  // FIFO pointers
  reg  [FIFO_POINTER_W-1:0] top;
  reg  [FIFO_POINTER_W-1:0] bottom;

  wire [FIFO_POINTER_W-1:0] top_plus_1 = top + 4'd1;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //
  mpsoc_wb_raminfr #(
    .ADDR_WIDTH (FIFO_POINTER_W),
    .DATA_WIDTH (FIFO_WIDTH),
    .DEPTH      (FIFO_DEPTH)
  )
  tfifo ( 
    .clk(clk), 
    .we(push), 
    .a(top), 
    .dpra(bottom), 
    .di(data_in), 
    .dpo(data_out)
  ); 

  always @(posedge clk or posedge wb_rst_i) begin  // synchronous FIFO
    if (wb_rst_i) begin
      top    <= 0;
      bottom <= 0;
      count  <= 0;
    end
    else if (fifo_reset) begin
      top    <= 0;
      bottom <= 0;
      count  <= 0;
    end
    else begin
      case ({push, pop})
        2'b10 : if (count<FIFO_DEPTH) begin  // overrun condition
          top   <= top_plus_1;
          count <= count + 5'd1;
        end
        2'b01 : if(count>0) begin
          bottom <= bottom + 4'd1;
          count  <= count - 5'd1;
        end
        2'b11 : begin
          bottom <= bottom + 4'd1;
          top    <= top_plus_1;
        end
        default: ;
      endcase
    end
  end  // always

  always @(posedge clk or posedge wb_rst_i) begin  // synchronous FIFO
    if (wb_rst_i)
      overrun   <= 1'b0;
    else if(fifo_reset | reset_status) 
      overrun   <= 1'b0;
    else if(push & (count==FIFO_DEPTH))
      overrun   <= 1'b1;
  end  // always
endmodule
