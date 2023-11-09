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
//              AMBA4 APB-Lite Bus Interface                                  //
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

module peripheral_uart_interrupt #(
  parameter TX_FIFO_DEPTH = 32,
  parameter RX_FIFO_DEPTH = 32
) (
  input logic clk_i,
  input logic rstn_i,

  // registers
  input logic [2:0] IER_i,  // interrupt enable register
  input logic       RDA_i,  // receiver data available
  input logic       CTI_i,  // character timeout indication

  // control logic
  input logic                           error_i,
  input logic [$clog2(RX_FIFO_DEPTH):0] rx_elements_i,
  input logic [$clog2(TX_FIFO_DEPTH):0] tx_elements_i,
  input logic [                    1:0] trigger_level_i,

  input logic [3:0] clr_int_i,  // one hot

  output logic       interrupt_o,
  output logic [3:0] IIR_o
);

  //////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////

  logic [3:0] iir_n, iir_q;
  logic trigger_level_reached;

  //////////////////////////////////////////////////////////////////////////////
  // Module Body
  //////////////////////////////////////////////////////////////////////////////

  always @(*) begin
    trigger_level_reached = 1'b0;
    case (trigger_level_i)
      2'b00: begin
        if ($unsigned(rx_elements_i) == 1) begin
          trigger_level_reached = 1'b1;
        end
      end
      2'b01: begin
        if ($unsigned(rx_elements_i) == 4) begin
          trigger_level_reached = 1'b1;
        end
      end
      2'b10: begin
        if ($unsigned(rx_elements_i) == 8) begin
          trigger_level_reached = 1'b1;
        end
      end
      2'b11: begin
        if ($unsigned(rx_elements_i) == 14) begin
          trigger_level_reached = 1'b1;
        end
      end
      default: begin
      end
    endcase
  end

  always @(*) begin
    if (clr_int_i == 4'b0) begin
      iir_n = iir_q;
    end else begin
      iir_n = iir_q & ~(clr_int_i);
    end
    // Receiver line status interrupt on: Overrun error, parity error, framing error or break interrupt
    if (IER_i[2] & error_i) begin
      iir_n = 4'b1100;
    end  // Received data available or trigger level reached in FIFO mode
    else if (IER_i[0] & (trigger_level_reached | RDA_i)) begin
      iir_n = 4'b1000;
    end  // Character timeout indication
    else if (IER_i[0] & CTI_i) begin
      iir_n = 4'b1000;
    end  // Transmitter holding register empty
    else if (IER_i[1] & tx_elements_i == 0) begin
      iir_n = 4'b0100;
    end
  end

  always @(posedge clk_i, negedge rstn_i) begin
    if (~rstn_i) begin
      iir_q <= 4'b0001;
    end else begin
      iir_q <= iir_n;
    end
  end

  assign IIR_o       = iir_q;
  assign interrupt_o = ~iir_q[0];
endmodule
