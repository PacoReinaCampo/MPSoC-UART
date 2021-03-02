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
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

//Following is the Verilog code for a dual-port RAM with asynchronous read. 
module mpsoc_wb_raminfr #(
  parameter ADDR_WIDTH = 4,
  parameter DATA_WIDTH = 8,
  parameter DEPTH      = 16
)
  (
    input                   clk,
    input                   we,
    input  [ADDR_WIDTH-1:0] a,
    input  [ADDR_WIDTH-1:0] dpra,
    input  [DATA_WIDTH-1:0] di,
    output [DATA_WIDTH-1:0] dpo
    //output [DATA_WIDTH-1:0] spo,
  );

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  reg   [DATA_WIDTH-1:0] ram [DEPTH-1:0];

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //
  always @(posedge clk) begin
    if (we) begin
      ram[a] <= di;
    end     
  end   
  //  assign spo = ram[a];   
  assign dpo = ram[dpra];   
endmodule
