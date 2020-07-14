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

module mpsoc_wb_uart_receiver (
  input         clk,
  input         wb_rst_i,
  input  [7:0]  lcr,
  input         rf_pop,
  input         srx_pad_i,
  input         enable,
  input         rx_reset,
  input         lsr_mask,

  output reg [                     9:0] counter_t,
  output     [`UART_FIFO_COUNTER_W-1:0] rf_count,
  output     [`UART_FIFO_REC_WIDTH-1:0] rf_data_out,
  output                                rf_overrun,
  output                                rf_error_bit,
  output reg [                     3:0] rstate,
  output                                rf_push_pulse
);

  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //
  parameter  sr_idle         = 4'd0;
  parameter  sr_rec_start    = 4'd1;
  parameter  sr_rec_bit      = 4'd2;
  parameter  sr_rec_parity   = 4'd3;
  parameter  sr_rec_stop     = 4'd4;
  parameter  sr_check_parity = 4'd5;
  parameter  sr_rec_prepare  = 4'd6;
  parameter  sr_end_bit      = 4'd7;
  parameter  sr_ca_lc_parity = 4'd8;
  parameter  sr_wait1        = 4'd9;
  parameter  sr_push         = 4'd10;

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  reg  [3:0]  rcounter16;
  reg  [2:0]  rbit_counter;
  reg  [7:0]  rshift;  // receiver shift register
  reg         rparity;  // received parity
  reg         rparity_error;
  reg         rframing_error;  // framing error flag
  reg         rparity_xor;
  reg  [7:0]  counter_b;  // counts the 0 (low) signals
  reg         rf_push_q;

  // RX FIFO signals
  reg   [`UART_FIFO_REC_WIDTH-1:0] rf_data_in;
  reg                              rf_push;

  wire break_error = (counter_b == 0);

  wire rcounter16_eq_7 = (rcounter16 == 4'd7);
  wire rcounter16_eq_0 = (rcounter16 == 4'd0);

  wire [3:0] rcounter16_minus_1 = rcounter16 - 3'd1;

  // value to be set to timeout counter
  reg   [9:0]  toc_value;

  // value to be set to break counter
  wire [7:0]   brc_value;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //

  // RX FIFO instance
  mpsoc_wb_uart_rfifo #(
    .FIFO_WIDTH     (`UART_FIFO_REC_WIDTH),
    .FIFO_DEPTH     (16),
    .FIFO_POINTER_W (4),
    .FIFO_COUNTER_W (5)
  )
  fifo_rx (
    .clk          (clk), 
    .wb_rst_i     (wb_rst_i),
    .data_in      (rf_data_in),
    .data_out     (rf_data_out),
    .push         (rf_push_pulse),
    .pop          (rf_pop),
    .overrun      (rf_overrun),
    .count        (rf_count),
    .error_bit    (rf_error_bit),
    .fifo_reset   (rx_reset),
    .reset_status (lsr_mask)
  );

  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) begin
      rstate         <= sr_idle;
      rcounter16     <= 0;
      rbit_counter   <= 0;
      rparity_xor    <= 1'b0;
      rframing_error <= 1'b0;
      rparity_error  <= 1'b0;
      rparity        <= 1'b0;
      rshift         <= 0;
      rf_push        <= 1'b0;
      rf_data_in     <= 0;
    end
    else if (enable) begin
      case (rstate)
        sr_idle : begin
          rf_push    <= 1'b0;
          rf_data_in <= 0;
          rcounter16 <= 4'b1110;
          if (srx_pad_i==1'b0 & ~break_error) begin  // detected a pulse (start bit?)
            rstate <= sr_rec_start;
          end
        end
        sr_rec_start : begin
          rf_push         <= 1'b0;
          if (rcounter16_eq_7)    // check the pulse
            if (srx_pad_i==1'b1)   // no start bit
              rstate <= sr_idle;
          else            // start bit detected
            rstate   <= sr_rec_prepare;
          rcounter16 <= rcounter16_minus_1;
        end
        sr_rec_prepare: begin
          case (lcr[/*`UART_LC_BITS*/1:0])  // number of bits in a word
            2'b00 : rbit_counter <= 3'b100;
            2'b01 : rbit_counter <= 3'b101;
            2'b10 : rbit_counter <= 3'b110;
            2'b11 : rbit_counter <= 3'b111;
          endcase
          if (rcounter16_eq_0) begin
            rstate     <= sr_rec_bit;
            rcounter16 <= 4'b1110;
            rshift     <= 0;
          end
          else
            rstate   <= sr_rec_prepare;
          rcounter16 <= rcounter16_minus_1;
        end
        sr_rec_bit : begin
          if (rcounter16_eq_0)
            rstate <= sr_end_bit;
          if (rcounter16_eq_7) // read the bit
            case (lcr[/*`UART_LC_BITS*/1:0])  // number of bits in a word
              2'b00 : rshift[4:0]  <= {srx_pad_i, rshift[4:1]};
              2'b01 : rshift[5:0]  <= {srx_pad_i, rshift[5:1]};
              2'b10 : rshift[6:0]  <= {srx_pad_i, rshift[6:1]};
              2'b11 : rshift[7:0]  <= {srx_pad_i, rshift[7:1]};
            endcase
          rcounter16 <= rcounter16_minus_1;
        end
        sr_end_bit : begin
          if (rbit_counter==3'b0) // no more bits in word
            if (lcr[`UART_LC_PE]) // choose state based on parity
              rstate <= sr_rec_parity;
          else begin
            rstate        <= sr_rec_stop;
            rparity_error <= 1'b0;  // no parity - no error :)
          end
          else begin  // else we have more bits to read
            rstate       <= sr_rec_bit;
            rbit_counter <= rbit_counter - 3'd1;
          end
          rcounter16 <= 4'b1110;
        end
        sr_rec_parity: begin
          if (rcounter16_eq_7) begin  // read the parity
            rparity <= srx_pad_i;
            rstate  <= sr_ca_lc_parity;
          end
          rcounter16 <= rcounter16_minus_1;
        end
        sr_ca_lc_parity : begin  // rcounter equals 6
          rcounter16  <= rcounter16_minus_1;
          rparity_xor <= ^{rshift,rparity}; // calculate parity on all incoming data
          rstate      <= sr_check_parity;
        end
        sr_check_parity : begin  // rcounter equals 5
          case ({lcr[`UART_LC_EP],lcr[`UART_LC_SP]})
            2'b00: rparity_error <=  rparity_xor == 0;  // no error if parity 1
            2'b01: rparity_error <= ~rparity;  // parity should sticked to 1
            2'b10: rparity_error <=  rparity_xor == 1;  // error if parity is odd
            2'b11: rparity_error <=  rparity;  // parity should be sticked to 0
          endcase
          rcounter16 <= rcounter16_minus_1;
          rstate    <= sr_wait1;
        end
        sr_wait1 : if (rcounter16_eq_0) begin
          rstate     <= sr_rec_stop;
          rcounter16 <= 4'b1110;
        end
        else
          rcounter16 <= rcounter16_minus_1;
        sr_rec_stop : begin
          if (rcounter16_eq_7) begin  // read the parity
            rframing_error <= !srx_pad_i;  // no framing error if input is 1 (stop bit)
            rstate <= sr_push;
          end
          rcounter16 <= rcounter16_minus_1;
        end
        sr_push : begin
          //$display($time, ": received: %b", rf_data_in);
          if(srx_pad_i | break_error) begin
            if(break_error)
              rf_data_in <= {8'b0, 3'b100}; // break input (empty character) to receiver FIFO
            else
              rf_data_in <= {rshift, 1'b0, rparity_error, rframing_error};
            rf_push      <= 1'b1;
            rstate       <= sr_idle;
          end
          else if(~rframing_error) begin  // There's always a framing before break_error -> wait for break or srx_pad_i
            rf_data_in <= {rshift, 1'b0, rparity_error, rframing_error};
            rf_push    <= 1'b1;
            rcounter16 <= 4'b1110;
            rstate     <= sr_rec_start;
          end
        end
        default : rstate <= sr_idle;
      endcase
    end  // if (enable)
  end  // always of receiver

  always @ (posedge clk or posedge wb_rst_i) begin
    if(wb_rst_i)
      rf_push_q <= 0;
    else
      rf_push_q <= rf_push;
  end

  assign rf_push_pulse = rf_push & ~rf_push_q;

  // Break condition detection.
  // Works in conjuction with the receiver state machine
  always @(lcr)
    case (lcr[3:0])
      4'b0000                            : toc_value = 447; // 7 bits
      4'b0100                            : toc_value = 479; // 7.5 bits
      4'b0001,  4'b1000                  : toc_value = 511; // 8 bits
      4'b1100                            : toc_value = 543; // 8.5 bits
      4'b0010, 4'b0101, 4'b1001          : toc_value = 575; // 9 bits
      4'b0011, 4'b0110, 4'b1010, 4'b1101 : toc_value = 639; // 10 bits
      4'b0111, 4'b1011, 4'b1110          : toc_value = 703; // 11 bits
      4'b1111                            : toc_value = 767; // 12 bits
    endcase // case(lcr[3:0])
  assign     brc_value = toc_value[9:2]; // the same as timeout but 1 insead of 4 character times

  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i)
      counter_b <= 8'd159;
    else if (srx_pad_i)
      counter_b <= brc_value; // character time length - 1
    else if(enable & counter_b != 8'b0)            // only work on enable times  break not reached.
      counter_b <= counter_b - 8'd1;  // decrement break counter
  end  // always of break condition detection

  // Timeout condition detection
  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i)
      counter_t <= 10'd639; // 10 bits for the default 8N1
    else if(rf_push_pulse || rf_pop || rf_count == 0) // counter is reset when RX FIFO is empty, accessed or above trigger level
      counter_t <= toc_value;
    else if (enable && counter_t != 10'b0)  // we don't want to underflow
      counter_t <= counter_t - 10'd1;
  end
endmodule
