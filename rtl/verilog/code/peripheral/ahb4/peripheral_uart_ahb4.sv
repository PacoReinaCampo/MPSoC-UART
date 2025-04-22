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

module peripheral_uart_ahb4 #(
  parameter APB_ADDR_WIDTH = 12,  // APB slaves are 4KB by default
  parameter APB_DATA_WIDTH = 32   // APB slaves are 4KB by default
) (
  input  logic                      CLK,
  input  logic                      RSTN,
  input  logic [APB_ADDR_WIDTH-1:0] PADDR,
  input  logic [APB_DATA_WIDTH-1:0] PWDATA,
  input  logic                      PWRITE,
  input  logic                      PSEL,
  input  logic                      PENABLE,
  output logic [APB_DATA_WIDTH-1:0] PRDATA,
  output logic                      PREADY,
  output logic                      PSLVERR,

  input  logic rx_i,  // Receiver input
  output logic tx_o,  // Transmitter output

  output logic event_o  // interrupt/event output
);

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  // register addresses
  parameter RBR = 3'h0, THR = 3'h0, DLL = 3'h0, IER = 3'h1, DLM = 3'h1, IIR = 3'h2;
  parameter FCR = 3'h2, LCR = 3'h3, MCR = 3'h4, LSR = 3'h5, MSR = 3'h6, SCR = 3'h7;

  parameter TX_FIFO_DEPTH = 16;  // in bytes
  parameter RX_FIFO_DEPTH = 16;  // in bytes

  //////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////

  logic [2:0] register_adr;
  logic [9:0][7:0] regs_q, regs_n;
  logic [1:0] trigger_level_n, trigger_level_q;

  // receive buffer register, read only
  logic [7:0] rx_data;
  logic       parity_error;
  logic [3:0] IIR_o;
  logic [3:0] clr_int;

  // tx flow control
  logic       tx_ready;

  // rx flow control
  logic       apb_rx_ready;
  logic       rx_valid;

  logic tx_fifo_clr_n, tx_fifo_clr_q;
  logic rx_fifo_clr_n, rx_fifo_clr_q;

  logic                           fifo_tx_valid;
  logic                           tx_valid;
  logic                           fifo_rx_valid;
  logic                           fifo_rx_ready;
  logic                           rx_ready;

  logic [                    7:0] fifo_tx_data;
  logic [                    8:0] fifo_rx_data;

  logic [                    7:0] tx_data;
  logic [$clog2(TX_FIFO_DEPTH):0] tx_elements;
  logic [$clog2(RX_FIFO_DEPTH):0] rx_elements;

  //////////////////////////////////////////////////////////////////////////////
  // Body
  //////////////////////////////////////////////////////////////////////////////

  // TO-DO: check that stop bits are really not necessary here
  peripheral_uart_rx peripheral_uart_rx_i (
    .clk_i          (CLK),
    .rstn_i         (RSTN),
    .rx_i           (rx_i),
    .cfg_en_i       (1'b1),
    .cfg_div_i      ({regs_q[DLM+'d8], regs_q[DLL+'d8]}),
    .cfg_parity_en_i(regs_q[LCR][3]),
    .cfg_bits_i     (regs_q[LCR][1:0]),
    .busy_o         (),
    .err_o          (parity_error),
    .err_clr_i      (1'b1),
    .rx_data_o      (rx_data),
    .rx_valid_o     (rx_valid),
    .rx_ready_i     (rx_ready)
  );

  peripheral_uart_tx peripheral_uart_tx_i (
    .clk_i          (CLK),
    .rstn_i         (RSTN),
    .tx_o           (tx_o),
    .busy_o         (),
    .cfg_en_i       (1'b1),
    .cfg_div_i      ({regs_q[DLM+'d8], regs_q[DLL+'d8]}),
    .cfg_parity_en_i(regs_q[LCR][3]),
    .cfg_bits_i     (regs_q[LCR][1:0]),
    .cfg_stop_bits_i(regs_q[LCR][2]),

    .tx_data_i (tx_data),
    .tx_valid_i(tx_valid),
    .tx_ready_o(tx_ready)
  );

  peripheral_uart_fifo #(
    .DATA_WIDTH  (9),
    .BUFFER_DEPTH(RX_FIFO_DEPTH)
  ) uart_rx_fifo_i (
    .clk_i (CLK),
    .rstn_i(RSTN),

    .clr_i(rx_fifo_clr_q),

    .elements_o(rx_elements),

    .data_o (fifo_rx_data),
    .valid_o(fifo_rx_valid),
    .ready_i(fifo_rx_ready),

    .valid_i(rx_valid),
    .data_i ({parity_error, rx_data}),
    .ready_o(rx_ready)
  );

  peripheral_uart_fifo #(
    .DATA_WIDTH  (8),
    .BUFFER_DEPTH(TX_FIFO_DEPTH)
  ) uart_tx_fifo_i (
    .clk_i (CLK),
    .rstn_i(RSTN),

    .clr_i(tx_fifo_clr_q),

    .elements_o(tx_elements),

    .data_o (tx_data),
    .valid_o(tx_valid),
    .ready_i(tx_ready),

    .valid_i(fifo_tx_valid),
    .data_i (fifo_tx_data),
    // not needed since we are getting the status via the fifo population
    .ready_o()
  );

  peripheral_uart_interrupt #(
    .TX_FIFO_DEPTH(TX_FIFO_DEPTH),
    .RX_FIFO_DEPTH(RX_FIFO_DEPTH)
  ) peripheral_uart_interrupt_i (
    .clk_i (CLK),
    .rstn_i(RSTN),

    .IER_i(regs_q[IER][2:0]),  // interrupt enable register
    .RDA_i(regs_n[LSR][5]),    // receiver data available
    .CTI_i(1'b0),              // character timeout indication

    .error_i        (regs_n[LSR][2]),
    .rx_elements_i  (rx_elements),
    .tx_elements_i  (tx_elements),
    .trigger_level_i(trigger_level_q),

    .clr_int_i(clr_int),  // one hot

    .interrupt_o(event_o),
    .IIR_o      (IIR_o)
  );

  // UART Registers

  // register write and update logic
  always @(*) begin
    regs_n          = regs_q;
    trigger_level_n = trigger_level_q;
    fifo_tx_valid   = 1'b0;
    tx_fifo_clr_n   = 1'b0;  // self clearing
    rx_fifo_clr_n   = 1'b0;  // self clearing
    // rx status
    regs_n[LSR][0]  = fifo_rx_valid;  // fifo is empty
    // parity error on receiving part has occured
    regs_n[LSR][2]  = fifo_rx_data[8];  // parity error is detected when element is retrieved
    // tx status register
    regs_n[LSR][5]  = ~(|tx_elements);  // fifo is empty
    regs_n[LSR][6]  = tx_ready & ~(|tx_elements);  // shift register and fifo are empty
    if (PSEL && PENABLE && PWRITE) begin
      case (register_adr)
        THR: begin  // either THR or DLL
          if (regs_q[LCR][7]) begin  // Divisor Latch Access Bit (DLAB)
            regs_n[DLL+'d8] = PWDATA[7:0];
          end else begin
            fifo_tx_data  = PWDATA[7:0];
            fifo_tx_valid = 1'b1;
          end
        end
        IER: begin  // either IER or DLM
          if (regs_q[LCR][7]) begin  // Divisor Latch Access Bit (DLAB)
            regs_n[DLM+'d8] = PWDATA[7:0];
          end else begin
            regs_n[IER] = PWDATA[7:0];
          end
        end
        LCR: begin
          regs_n[LCR] = PWDATA[7:0];
        end
        FCR: begin  // write only register, fifo control register
          rx_fifo_clr_n   = PWDATA[1];
          tx_fifo_clr_n   = PWDATA[2];
          trigger_level_n = PWDATA[7:6];
        end
        default: begin
        end
      endcase
    end
  end

  // register read logic
  always @(*) begin
    PRDATA        = 'b0;
    apb_rx_ready  = 1'b0;
    fifo_rx_ready = 1'b0;
    clr_int       = 4'b0;
    if (PSEL && PENABLE && !PWRITE) begin
      case (register_adr)
        RBR: begin  // either RBR or DLL
          if (regs_q[LCR][7]) begin  // Divisor Latch Access Bit (DLAB)
            PRDATA = {24'b0, regs_q[DLL+'d8]};
          end else begin
            fifo_rx_ready = 1'b1;
            PRDATA        = {24'b0, fifo_rx_data[7:0]};
            clr_int       = 4'b1000;  // clear Received Data Available interrupt
          end
        end
        LSR: begin  // Line Status Register
          PRDATA  = {24'b0, regs_q[LSR]};
          clr_int = 4'b1100;  // clear parrity interrupt error
        end
        LCR: begin  // Line Control Register
          PRDATA = {24'b0, regs_q[LCR]};
        end
        IER: begin  // either IER or DLM
          if (regs_q[LCR][7]) begin  // Divisor Latch Access Bit (DLAB)
            PRDATA = {24'b0, regs_q[DLM+'d8]};
          end else begin
            PRDATA = {24'b0, regs_q[IER]};
          end
        end
        IIR: begin  // interrupt identification register read only
          PRDATA  = {24'b0, 1'b1, 1'b1, 2'b0, IIR_o};
          clr_int = 4'b0100;  // clear Transmitter Holding Register Empty
        end
        default: begin
        end
      endcase
    end
  end

  // synchronouse part
  always @(posedge CLK, negedge RSTN) begin
    if (~RSTN) begin
      regs_q[IER]     <= 8'h0;
      regs_q[IIR]     <= 8'h1;
      regs_q[LCR]     <= 8'h0;
      regs_q[MCR]     <= 8'h0;
      regs_q[LSR]     <= 8'h60;
      regs_q[MSR]     <= 8'h0;
      regs_q[SCR]     <= 8'h0;
      regs_q[DLM+'d8] <= 8'h0;
      regs_q[DLL+'d8] <= 8'h0;
      trigger_level_q <= 2'b00;
      tx_fifo_clr_q   <= 1'b0;
      rx_fifo_clr_q   <= 1'b0;
    end else begin
      regs_q          <= regs_n;
      trigger_level_q <= trigger_level_n;
      tx_fifo_clr_q   <= tx_fifo_clr_n;
      rx_fifo_clr_q   <= rx_fifo_clr_n;
    end
  end

  assign register_adr = {PADDR[2:0]};
  // APB logic: we are always ready to capture the data into our regs
  // not supporting transfare failure
  assign PREADY       = 1'b1;
  assign PSLVERR      = 1'b0;
endmodule
