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

module mpsoc_wb_uart_transmitter #(
  parameter SIM = 0
)
  (
    input                             clk,
    input                             wb_rst_i,
    input                       [7:0] lcr,
    input                             tf_push,
    input                       [7:0] wb_dat_i,
    input                             enable,
    input                             tx_reset,
    input                             lsr_mask,  //reset of fifo
    output                            stx_pad_o,
    output reg                  [2:0] tstate,
    output [`UART_FIFO_COUNTER_W-1:0] tf_count
  );

  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //

  // TRANSMITTER FINAL STATE MACHINE
  localparam s_idle        = 3'd0;
  localparam s_send_start  = 3'd1;
  localparam s_send_byte   = 3'd2;
  localparam s_send_parity = 3'd3;
  localparam s_send_stop   = 3'd4;
  localparam s_pop_byte    = 3'd5;

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  reg [4:0] counter;
  reg [2:0] bit_counter;  // counts the bits to be sent
  reg [6:0] shift_out;  // output shift register
  reg       stx_o_tmp;
  reg       parity_xor;  // parity of the word
  reg       tf_pop;
  reg       bit_out;

  // TX FIFO instance

  // Transmitter FIFO signals
  wire [`UART_FIFO_WIDTH-1:0]     tf_data_in;
  wire [`UART_FIFO_WIDTH-1:0]     tf_data_out;
  wire                            tf_overrun;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //
  assign tf_data_in = wb_dat_i;

  mpsoc_wb_uart_tfifo #(
    .FIFO_WIDTH     (8),
    .FIFO_DEPTH     (16),
    .FIFO_POINTER_W (4),
    .FIFO_COUNTER_W (5)
  )
  fifo_tx (  // error bit signal is not used in transmitter FIFO
    .clk          ( clk         ), 
    .wb_rst_i     ( wb_rst_i    ),
    .data_in      ( tf_data_in  ),
    .data_out     ( tf_data_out ),
    .push         ( tf_push     ),
    .pop          ( tf_pop      ),
    .overrun      ( tf_overrun  ),
    .count        ( tf_count    ),
    .fifo_reset   ( tx_reset    ),
    .reset_status ( lsr_mask    )
  );

  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) begin
      tstate      <= s_idle;
      stx_o_tmp   <= 1'b1;
      counter     <= 5'b0;
      shift_out   <= 7'b0;
      bit_out     <= 1'b0;
      parity_xor  <= 1'b0;
      tf_pop      <= 1'b0;
      bit_counter <= 3'b0;
    end
    else if (enable | SIM) begin
      case (tstate)
        s_idle : if (~|tf_count) begin  // if tf_count==0
          tstate    <= s_idle;
          stx_o_tmp <= 1'b1;
        end
        else begin
          tf_pop     <= 1'b0;
          stx_o_tmp  <= 1'b1;
          tstate     <= s_pop_byte;
        end
        s_pop_byte : begin
          tf_pop <= 1'b1;
          case (lcr[/*`UART_LC_BITS*/1:0])  // number of bits in a word
            2'b00 : begin
              bit_counter <= 3'b100;
              parity_xor  <= ^tf_data_out[4:0];
            end
            2'b01 : begin
              bit_counter <= 3'b101;
              parity_xor  <= ^tf_data_out[5:0];
            end
            2'b10 : begin
              bit_counter <= 3'b110;
              parity_xor  <= ^tf_data_out[6:0];
            end
            2'b11 : begin
              bit_counter <= 3'b111;
              parity_xor  <= ^tf_data_out[7:0];
            end
          endcase
          {shift_out[6:0], bit_out} <= tf_data_out;
          tstate <= s_send_start;
        end
        s_send_start : begin
          tf_pop <= 1'b0;
          if (~|counter)
            counter <= 5'b01111;
          else if (counter == 5'b00001) begin
            counter <= 0;
            tstate <= s_send_byte;
          end
          else
            counter <= counter - 5'd1;
          stx_o_tmp <= 1'b0;
          if (SIM) begin
            tstate <= s_idle;
            $write("%c", tf_data_out);
            $fflush(32'h80000001);
          end
        end
        s_send_byte : begin
          if (~|counter)
            counter <= 5'b01111;
          else if (counter == 5'b00001) begin
            if (bit_counter > 3'b0) begin
              bit_counter <= bit_counter - 3'd1;
              {shift_out[5:0],bit_out  } <= {shift_out[6:1], shift_out[0]};
              tstate <= s_send_byte;
            end
            else if (~lcr[`UART_LC_PE]) begin  // end of byte
              tstate <= s_send_stop;
            end
            else begin
              case ({lcr[`UART_LC_EP],lcr[`UART_LC_SP]})
                2'b00:  bit_out <= ~parity_xor;
                2'b01:  bit_out <= 1'b1;
                2'b10:  bit_out <= parity_xor;
                2'b11:  bit_out <= 1'b0;
              endcase
              tstate <= s_send_parity;
            end
            counter <= 0;
          end
          else
            counter <= counter - 5'd1;
          stx_o_tmp <= bit_out; // set output pin
        end
        s_send_parity : begin
          if (~|counter)
            counter <= 5'b01111;
          else if (counter == 5'b00001) begin
            counter <= 5'd0;
            tstate <= s_send_stop;
          end
          else
            counter <= counter - 5'd1;
          stx_o_tmp <= bit_out;
        end
        s_send_stop : begin
          if (~|counter) begin
            casez ({lcr[`UART_LC_SB],lcr[`UART_LC_BITS]})
              3'b0??:  counter <= 5'b01101;  // 1 stop bit ok igor
              3'b100:  counter <= 5'b10101;  // 1.5 stop bit
              default: counter <= 5'b11101;  // 2 stop bits
            endcase
          end
          else if (counter == 5'b00001) begin
            counter <= 0;
            tstate  <= s_idle;
          end
          else
            counter <= counter - 5'd1;
          stx_o_tmp <= 1'b1;
        end
        default : // should never get here
          tstate <= s_idle;
      endcase
    end // end if enable
    else
      tf_pop <= 1'b0;  // tf_pop must be 1 cycle width
  end // transmitter logic

  assign stx_pad_o = lcr[`UART_LC_BC] ? 1'b0 : stx_o_tmp;    // Break condition
endmodule
