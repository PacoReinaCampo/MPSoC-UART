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
//              AMBA3 APB-Lite Bus Interface                                  //
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

module mpsoc_uart_fifo #(
  parameter DATA_WIDTH = 32,
  parameter BUFFER_DEPTH = 2,
  parameter LOG_BUFFER_DEPTH = $clog2(BUFFER_DEPTH)
)
  (
    input  logic                      clk_i,
    input  logic                      rstn_i,

    input  logic                      clr_i,

    output logic [LOG_BUFFER_DEPTH:0] elements_o,

    output logic [DATA_WIDTH    -1:0] data_o,
    output logic                      valid_o,
    input  logic                      ready_i,

    input  logic                      valid_i,
    input  logic [DATA_WIDTH    -1:0] data_i,
    output logic                      ready_o
  );

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  // Internal data structures
  logic [LOG_BUFFER_DEPTH-1:0]     pointer_in;  // location to which we last wrote
  logic [LOG_BUFFER_DEPTH-1:0]     pointer_out; // location from which we last sent
  logic [LOG_BUFFER_DEPTH  :0]     elements;    // number of elements in the buffer
  logic [DATA_WIDTH      -1:0]     buffer [BUFFER_DEPTH-1:0];

  logic                            full;

  integer                          i;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //

  assign full = (elements == BUFFER_DEPTH);
  assign elements_o = elements;

  always @(posedge clk_i, negedge rstn_i) begin: elements_sequential
    if (rstn_i == 1'b0) begin
      elements <= 0;
    end
    else begin
      if (clr_i) begin
        elements <= 0;
      end
      else begin
        // ------------------
        // Are we filling up?
        // ------------------
        // One out, none in
        if (ready_i && valid_o && (!valid_i || full)) begin
          elements <= elements - 1;
        end
        // None out, one in
        else if ((!valid_o || !ready_i) && valid_i && !full) begin
          elements <= elements + 1;
        end
        // Else, either one out and one in, or none out and none in - stays unchanged
      end
    end
  end

  always @(posedge clk_i, negedge rstn_i) begin: buffers_sequential
    if (rstn_i == 1'b0) begin
      for (i=0; i < BUFFER_DEPTH; i=i+1) begin
        buffer[i] <= 0;
      end
    end
    else begin
      // Update the memory
      if (valid_i && !full) begin
        buffer[pointer_in] <= data_i;
      end
    end
  end

  always @(posedge clk_i, negedge rstn_i) begin: sequential
    if (rstn_i == 1'b0) begin
      pointer_out <= 0;
      pointer_in  <= 0;
    end
    else begin
      if(clr_i) begin
        pointer_out <= 0;
        pointer_in  <= 0;
      end
      else begin
        // ------------------------------------
        // Check what to do with the input side
        // ------------------------------------
        // We have some input, increase by 1 the input pointer
        if (valid_i && !full) begin
          if (pointer_in == $unsigned(BUFFER_DEPTH - 1)) begin
            pointer_in <= 0;
          end
          else begin
            pointer_in <= pointer_in + 1;
          end
        end
        // Else we don't have any input, the input pointer stays the same

        // -------------------------------------
        // Check what to do with the output side
        // -------------------------------------
        // We had pushed one flit out, we can try to go for the next one
        if (ready_i && valid_o) begin
          if (pointer_out == $unsigned(BUFFER_DEPTH - 1)) begin
            pointer_out <= 0;
          end
          else begin
            pointer_out <= pointer_out + 1;
          end
        end
        // Else stay on the same output location
      end
    end
  end

  // Update output ports
  assign data_o  = buffer[pointer_out];
  assign valid_o = (elements != 0);

  assign ready_o = ~full;
endmodule
