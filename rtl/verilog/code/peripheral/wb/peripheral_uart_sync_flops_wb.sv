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
//              Peripheral-UART for MPSoC                                     //
//              Universal Asynchronous Receiver-Transmitter for MPSoC         //
//              WishBone Bus Interface                                        //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2018-2019 by the author(s)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
////////////////////////////////////////////////////////////////////////////////
// Author(s):
//   Andrej Erzen <andreje@flextronics.si>
//   Tadej Markovic <tadejm@flextronics.si>
//   Paco Reina Campo <pacoreinacampo@queenfield.tech>

module peripheral_uart_sync_flops_wb #(
  parameter WIDTH      = 1,
  parameter INIT_VALUE = 1'b0
) (
  input                  rst_i,            // reset input
  input                  clk_i,            // clock input
  input                  stage1_rst_i,     // synchronous reset for stage 1 FF
  input                  stage1_clk_en_i,  // synchronous clock enable for stage 1 FF
  input      [WIDTH-1:0] async_dat_i,      // asynchronous data input
  output reg [WIDTH-1:0] sync_dat_o        // synchronous data output
);

  //////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////

  // Internal signal declarations
  reg [WIDTH-1:0] flop_0;

  //////////////////////////////////////////////////////////////////////////////
  // Body
  //////////////////////////////////////////////////////////////////////////////

  // first stage
  always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      flop_0 <= {WIDTH{INIT_VALUE}};
    end else begin
      flop_0 <= async_dat_i;
    end
  end

  // second stage
  always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      sync_dat_o <= {WIDTH{INIT_VALUE}};
    end else if (stage1_rst_i) begin
      sync_dat_o <= {WIDTH{INIT_VALUE}};
    end else if (stage1_clk_en_i) begin
      sync_dat_o <= flop_0;
    end
  end
endmodule
