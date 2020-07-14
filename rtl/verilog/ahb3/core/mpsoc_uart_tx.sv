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

module mpsoc_uart_tx (
  input  logic            clk_i,
  input  logic            rstn_i,
  output logic            tx_o,
  output logic            busy_o,
  input  logic            cfg_en_i,
  input  logic [15:0]     cfg_div_i,
  input  logic            cfg_parity_en_i,
  input  logic [ 1:0]     cfg_bits_i,
  input  logic            cfg_stop_bits_i,
  input  logic [ 7:0]     tx_data_i,
  input  logic            tx_valid_i,
  output logic            tx_ready_o
);

  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //

  parameter [2:0] IDLE           = 3'b110;
  parameter [2:0] START_BIT      = 3'b101;
  parameter [2:0] DATA           = 3'b100;
  parameter [2:0] PARITY         = 3'b011;
  parameter [2:0] STOP_BIT_FIRST = 3'b010;
  parameter [2:0] STOP_BIT_LAST  = 3'b001;

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  logic [2:0]  CS, NS;

  logic [7:0]  reg_data;
  logic [7:0]  reg_data_next;

  logic [2:0]  reg_bit_count;
  logic [2:0]  reg_bit_count_next;

  logic [2:0]  s_target_bits;

  logic        parity_bit;
  logic        parity_bit_next;

  logic        sampleData;

  logic [15:0] baud_cnt;
  logic        baudgen_en;
  logic        bit_done;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //

  assign busy_o = (CS != IDLE);

  always @(*) begin
    case(cfg_bits_i)
      2'b00:
        s_target_bits = 3'h4;
      2'b01:
        s_target_bits = 3'h5;
      2'b10:
        s_target_bits = 3'h6;
      2'b11:
        s_target_bits = 3'h7;
    endcase
  end

  always @(*) begin
    NS = CS;
    tx_o = 1'b1;
    sampleData = 1'b0;
    reg_bit_count_next  = reg_bit_count;
    reg_data_next = {1'b1,reg_data[7:1]};
    tx_ready_o = 1'b0;
    baudgen_en = 1'b0;
    parity_bit_next = parity_bit;
    case(CS)
      IDLE: begin
        if (cfg_en_i) begin
          tx_ready_o = 1'b1;
        end
        else if (tx_valid_i) begin
          NS = START_BIT;
          sampleData = 1'b1;
          reg_data_next = tx_data_i;
        end
      end
      START_BIT: begin
        tx_o = 1'b0;
        parity_bit_next = 1'b0;
        baudgen_en = 1'b1;
        if (bit_done)
          NS = DATA;
      end
      DATA: begin
        tx_o = reg_data[0];
        baudgen_en = 1'b1;
        parity_bit_next = parity_bit ^ reg_data[0];
        if (bit_done) begin
          if (reg_bit_count == s_target_bits) begin
            reg_bit_count_next = 'h0;
            if (cfg_parity_en_i) begin
              NS = PARITY;
            end
            else begin
              NS = STOP_BIT_FIRST;
            end
          end
          else begin
            reg_bit_count_next = reg_bit_count + 1;
            sampleData = 1'b1;
          end
        end
      end
      PARITY: begin
        tx_o = parity_bit;
        baudgen_en = 1'b1;
        if (bit_done)
          NS = STOP_BIT_FIRST;
      end
      STOP_BIT_FIRST: begin
        tx_o = 1'b1;
        baudgen_en = 1'b1;
        if (bit_done) begin
          if (cfg_stop_bits_i)
            NS = STOP_BIT_LAST;
          else
            NS = IDLE;
        end
      end
      STOP_BIT_LAST: begin
        tx_o = 1'b1;
        baudgen_en = 1'b1;
        if (bit_done) begin
          NS = IDLE;
        end
      end
      default:
        NS = IDLE;
    endcase
  end

  always @(posedge clk_i or negedge rstn_i) begin
    if (rstn_i == 1'b0) begin
      CS             <= IDLE;
      reg_data       <= 8'hFF;
      reg_bit_count  <=  'h0;
      parity_bit     <= 1'b0;
    end
    else begin
      if(bit_done) begin
        parity_bit <= parity_bit_next;
      end
      if(sampleData) begin
        reg_data <= reg_data_next;
      end
      reg_bit_count  <= reg_bit_count_next;
      if(cfg_en_i)
        CS <= NS;
      else
        CS <= IDLE;
    end
  end

  always @(posedge clk_i or negedge rstn_i) begin
    if (rstn_i == 1'b0) begin
      baud_cnt <= 'h0;
      bit_done <= 1'b0;
    end
    else begin
      if(baudgen_en) begin
        if(baud_cnt == cfg_div_i) begin
          baud_cnt <= 'h0;
          bit_done <= 1'b1;
        end
        else begin
          baud_cnt <= baud_cnt + 1;
          bit_done <= 1'b0;
        end
      end
      else begin
        baud_cnt <= 'h0;
        bit_done <= 1'b0;
      end
    end
  end
endmodule
