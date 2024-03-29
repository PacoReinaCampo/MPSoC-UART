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
//   Paco Reina Campo <pacoreinacampo@queenfield.tech>

module peripheral_uart_rx (
  input  logic        clk_i,
  input  logic        rstn_i,
  input  logic        rx_i,
  input  logic [15:0] cfg_div_i,
  input  logic        cfg_en_i,
  input  logic        cfg_parity_en_i,
  input  logic [ 1:0] cfg_bits_i,
  output logic        busy_o,
  output logic        err_o,
  input  logic        err_clr_i,
  output logic [ 7:0] rx_data_o,
  output logic        rx_valid_o,
  input  logic        rx_ready_i
);

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  parameter [2:0] IDLE = 3'b110;
  parameter [2:0] START_BIT = 3'b101;
  parameter [2:0] DATA = 3'b100;
  parameter [2:0] SAVE_DATA = 3'b011;
  parameter [2:0] PARITY = 3'b010;
  parameter [2:0] STOP_BIT = 3'b001;

  //////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////

  logic [2:0] CS, NS;

  logic [ 7:0] reg_data;
  logic [ 7:0] reg_data_next;

  logic [ 2:0] reg_rx_sync;

  logic [ 2:0] reg_bit_count;
  logic [ 2:0] reg_bit_count_next;

  logic [ 2:0] s_target_bits;

  logic        parity_bit;
  logic        parity_bit_next;

  logic        sampleData;

  logic [15:0] baud_cnt;
  logic        baudgen_en;
  logic        bit_done;

  logic        start_bit;
  logic        set_error;
  logic        s_rx_fall;

  //////////////////////////////////////////////////////////////////////////////
  // Body
  //////////////////////////////////////////////////////////////////////////////

  assign busy_o = (CS != IDLE);

  always @(*) begin
    case (cfg_bits_i)
      2'b00: s_target_bits = 3'h4;
      2'b01: s_target_bits = 3'h5;
      2'b10: s_target_bits = 3'h6;
      2'b11: s_target_bits = 3'h7;
    endcase
  end

  always @(*) begin
    NS                 = CS;
    sampleData         = 1'b0;
    reg_bit_count_next = reg_bit_count;
    reg_data_next      = reg_data;
    rx_valid_o         = 1'b0;
    baudgen_en         = 1'b0;
    start_bit          = 1'b0;
    parity_bit_next    = parity_bit;
    set_error          = 1'b0;
    case (CS)
      IDLE: begin
        if (s_rx_fall) begin
          NS         = START_BIT;
          baudgen_en = 1'b1;
          start_bit  = 1'b1;
        end
      end
      START_BIT: begin
        parity_bit_next = 1'b0;
        baudgen_en      = 1'b1;
        start_bit       = 1'b1;
        if (bit_done) begin
          NS = DATA;
        end
      end
      DATA: begin
        baudgen_en      = 1'b1;
        parity_bit_next = parity_bit ^ reg_rx_sync[2];
        case (cfg_bits_i)
          2'b00: reg_data_next = {3'b000, reg_rx_sync[2], reg_data[4:1]};
          2'b01: reg_data_next = {2'b00, reg_rx_sync[2], reg_data[5:1]};
          2'b10: reg_data_next = {1'b0, reg_rx_sync[2], reg_data[6:1]};
          2'b11: reg_data_next = {reg_rx_sync[2], reg_data[7:1]};
        endcase
        if (bit_done) begin
          sampleData = 1'b1;
          if (reg_bit_count == s_target_bits) begin
            reg_bit_count_next = 'h0;
            NS                 = SAVE_DATA;
          end else begin
            reg_bit_count_next = reg_bit_count + 1;
          end
        end
      end
      SAVE_DATA: begin
        baudgen_en = 1'b1;
        rx_valid_o = 1'b1;
        if (rx_ready_i) begin
          if (cfg_parity_en_i) begin
            NS = PARITY;
          end else begin
            NS = STOP_BIT;
          end
        end
      end
      PARITY: begin
        baudgen_en = 1'b1;
        if (bit_done) begin
          if (parity_bit != reg_rx_sync[2]) begin
            set_error = 1'b1;
          end
          NS = STOP_BIT;
        end
      end
      STOP_BIT: begin
        baudgen_en = 1'b1;
        if (bit_done) begin
          NS = IDLE;
        end
      end
      default: begin
        NS = IDLE;
      end
    endcase
  end

  always @(posedge clk_i or negedge rstn_i) begin
    if (rstn_i == 1'b0) begin
      CS            <= IDLE;
      reg_data      <= 8'hFF;
      reg_bit_count <= 'h0;
      parity_bit    <= 1'b0;
    end else begin
      if (bit_done) begin
        parity_bit <= parity_bit_next;
      end else if (sampleData) begin
        reg_data <= reg_data_next;
      end
      reg_bit_count <= reg_bit_count_next;
      if (cfg_en_i) begin
        CS <= NS;
      end else begin
        CS <= IDLE;
      end
    end
  end

  assign s_rx_fall = ~reg_rx_sync[1] & reg_rx_sync[2];

  always @(posedge clk_i or negedge rstn_i) begin
    if (rstn_i == 1'b0) begin
      reg_rx_sync <= 3'b111;
    end else begin
      if (cfg_en_i) begin
        reg_rx_sync <= {reg_rx_sync[1:0], rx_i};
      end else begin
        reg_rx_sync <= 3'b111;
      end
    end
  end

  always @(posedge clk_i or negedge rstn_i) begin
    if (rstn_i == 1'b0) begin
      baud_cnt <= 'h0;
      bit_done <= 1'b0;
    end else begin
      if (baudgen_en) begin
        if (!start_bit && (baud_cnt == cfg_div_i)) begin
          baud_cnt <= 'h0;
          bit_done <= 1'b1;
        end else if (start_bit && (baud_cnt == {1'b0, cfg_div_i[15:1]})) begin
          baud_cnt <= 'h0;
          bit_done <= 1'b1;
        end else begin
          baud_cnt <= baud_cnt + 1;
          bit_done <= 1'b0;
        end
      end else begin
        baud_cnt <= 'h0;
        bit_done <= 1'b0;
      end
    end
  end

  always @(posedge clk_i or negedge rstn_i) begin
    if (rstn_i == 1'b0) begin
      err_o <= 1'b0;
    end else begin
      if (err_clr_i) begin
        err_o <= 1'b0;
      end else begin
        if (set_error) begin
          err_o <= 1'b1;
        end
      end
    end
  end

  assign rx_data_o = reg_data;
endmodule
