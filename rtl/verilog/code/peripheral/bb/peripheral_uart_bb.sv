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
//              BackBone Bus Interface                                       //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2015-2016 by the author(s)
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the authors nor the names of its contributors
//       may be used to endorse or promote products derived from this software
//       without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
// OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
// THE POSSIBILITY OF SUCH DAMAGE
//
////////////////////////////////////////////////////////////////////////////////
// Author(s):
//   Olivier Girard <olgirard@gmail.com>
//   Paco Reina Campo <pacoreinacampo@queenfield.tech>

module peripheral_uart_bb (
  // OUTPUTs
  output        irq_uart_rx,  // UART receive interrupt
  output        irq_uart_tx,  // UART transmit interrupt
  output [15:0] per_dout,     // Peripheral data output
  output        uart_txd,     // UART Data Transmit (TXD)

  // INPUTs
  input        mclk,      // Main system clock
  input [13:0] per_addr,  // Peripheral address
  input [15:0] per_din,   // Peripheral data input
  input        per_en,    // Peripheral enable (high active)
  input [ 1:0] per_we,    // Peripheral write enable (high active)
  input        puc_rst,   // Main system reset
  input        smclk_en,  // SMCLK enable (from CPU)
  input        uart_rxd   // UART Data Receive (RXD)
);

  //////////////////////////////////////////////////////////////////////////////
  // 1)  PARAMETER DECLARATION
  //////////////////////////////////////////////////////////////////////////////

  // Register base address (must be aligned to decoder bit width)
  parameter [14:0] BASE_ADDR = 15'h0080;

  // Decoder bit width (defines how many bits are considered for address decoding)
  parameter DEC_WD = 3;

  // Register addresses offset
  parameter [DEC_WD-1:0] CTRL = 'h0;
  parameter [DEC_WD-1:0] STATUS = 'h1;
  parameter [DEC_WD-1:0] BAUD_LO = 'h2;
  parameter [DEC_WD-1:0] BAUD_HI = 'h3;
  parameter [DEC_WD-1:0] DATA_TX = 'h4;
  parameter [DEC_WD-1:0] DATA_RX = 'h5;

  // Register one-hot decoder utilities
  parameter DEC_SZ = (1 << DEC_WD);
  parameter [DEC_SZ-1:0] BASE_REG = {{DEC_SZ - 1{1'b0}}, 1'b1};

  // Register one-hot decoder
  parameter [DEC_SZ-1:0] CTRL_D = (BASE_REG << CTRL);
  parameter [DEC_SZ-1:0] STATUS_D = (BASE_REG << STATUS);
  parameter [DEC_SZ-1:0] BAUD_LO_D = (BASE_REG << BAUD_LO);
  parameter [DEC_SZ-1:0] BAUD_HI_D = (BASE_REG << BAUD_HI);
  parameter [DEC_SZ-1:0] DATA_TX_D = (BASE_REG << DATA_TX);
  parameter [DEC_SZ-1:0] DATA_RX_D = (BASE_REG << DATA_RX);

  //////////////////////////////////////////////////////////////////////////////
  // 2)  REGISTER DECODER
  //////////////////////////////////////////////////////////////////////////////

  // Local register selection
  wire reg_sel = per_en & (per_addr[13:DEC_WD-1] == BASE_ADDR[14:DEC_WD]);

  // Register local address
  wire [DEC_WD-1:0] reg_addr = {1'b0, per_addr[DEC_WD-2:0]};

  // Register address decode
  wire [DEC_SZ-1:0] reg_dec      = (CTRL_D    &  {DEC_SZ{(reg_addr==(CTRL    >>1))}}) |
                                   (STATUS_D  &  {DEC_SZ{(reg_addr==(STATUS  >>1))}}) |
                                   (BAUD_LO_D &  {DEC_SZ{(reg_addr==(BAUD_LO >>1))}}) |
                                   (BAUD_HI_D &  {DEC_SZ{(reg_addr==(BAUD_HI >>1))}}) |
                                   (DATA_TX_D &  {DEC_SZ{(reg_addr==(DATA_TX >>1))}}) |
                                   (DATA_RX_D &  {DEC_SZ{(reg_addr==(DATA_RX >>1))}});

  // Read/Write probes
  wire reg_lo_write = per_we[0] & reg_sel;
  wire reg_hi_write = per_we[1] & reg_sel;
  wire reg_read = ~|per_we & reg_sel;

  // Read/Write vectors
  wire [DEC_SZ-1:0] reg_hi_wr = reg_dec & {DEC_SZ{reg_hi_write}};
  wire [DEC_SZ-1:0] reg_lo_wr = reg_dec & {DEC_SZ{reg_lo_write}};
  wire [DEC_SZ-1:0] reg_rd = reg_dec & {DEC_SZ{reg_read}};

  //////////////////////////////////////////////////////////////////////////////
  // 3) REGISTERS
  //////////////////////////////////////////////////////////////////////////////

  // CTRL Register
  reg [7:0] ctrl;

  wire ctrl_wr = CTRL[0] ? reg_hi_wr[CTRL] : reg_lo_wr[CTRL];
  wire [7:0] ctrl_nxt = CTRL[0] ? per_din[15:8] : per_din[7:0];

  always @(posedge mclk or posedge puc_rst) begin
    if (puc_rst) begin
      ctrl <= 8'h00;
    end else if (ctrl_wr) begin
      ctrl <= ctrl_nxt & 8'h73;
    end
  end

  wire       ctrl_ien_tx_empty = ctrl[7];
  wire       ctrl_ien_tx = ctrl[6];
  wire       ctrl_ien_rx_ovflw = ctrl[5];
  wire       ctrl_ien_rx = ctrl[4];
  wire       ctrl_smclk_sel = ctrl[1];
  wire       ctrl_en = ctrl[0];

  // STATUS Register
  wire [7:0] status;
  reg        status_tx_empty_pnd;
  reg        status_tx_pnd;
  reg        status_rx_ovflw_pnd;
  reg        status_rx_pnd;
  wire       status_tx_full;
  wire       status_tx_busy;
  wire       status_rx_busy;

  wire       status_wr = STATUS[0] ? reg_hi_wr[STATUS] : reg_lo_wr[STATUS];
  wire [7:0] status_nxt = STATUS[0] ? per_din[15:8] : per_din[7:0];

  wire       status_tx_empty_pnd_clr = status_wr & status_nxt[7];
  wire       status_tx_pnd_clr = status_wr & status_nxt[6];
  wire       status_rx_ovflw_pnd_clr = status_wr & status_nxt[5];
  wire       status_rx_pnd_clr = status_wr & status_nxt[4];
  wire       status_tx_empty_pnd_set;
  wire       status_tx_pnd_set;
  wire       status_rx_ovflw_pnd_set;
  wire       status_rx_pnd_set;

  always @(posedge mclk or posedge puc_rst) begin
    if (puc_rst) begin
      status_tx_empty_pnd <= 1'b0;
    end else if (status_tx_empty_pnd_set) begin
      status_tx_empty_pnd <= 1'b1;
    end else if (status_tx_empty_pnd_clr) begin
      status_tx_empty_pnd <= 1'b0;
    end
  end

  always @(posedge mclk or posedge puc_rst) begin
    if (puc_rst) begin
      status_tx_pnd <= 1'b0;
    end else if (status_tx_pnd_set) begin
      status_tx_pnd <= 1'b1;
    end else if (status_tx_pnd_clr) begin
      status_tx_pnd <= 1'b0;
    end
  end

  always @(posedge mclk or posedge puc_rst) begin
    if (puc_rst) begin
      status_rx_ovflw_pnd <= 1'b0;
    end else if (status_rx_ovflw_pnd_set) begin
      status_rx_ovflw_pnd <= 1'b1;
    end else if (status_rx_ovflw_pnd_clr) begin
      status_rx_ovflw_pnd <= 1'b0;
    end
  end

  always @(posedge mclk or posedge puc_rst) begin
    if (puc_rst) begin
      status_rx_pnd <= 1'b0;
    end else if (status_rx_pnd_set) begin
      status_rx_pnd <= 1'b1;
    end else if (status_rx_pnd_clr) begin
      status_rx_pnd <= 1'b0;
    end
  end

  assign status = {status_tx_empty_pnd, status_tx_pnd, status_rx_ovflw_pnd, status_rx_pnd, status_tx_full, status_tx_busy, 1'b0, status_rx_busy};

  // BAUD_LO Register
  reg  [7:0] baud_lo;

  wire       baud_lo_wr = BAUD_LO[0] ? reg_hi_wr[BAUD_LO] : reg_lo_wr[BAUD_LO];
  wire [7:0] baud_lo_nxt = BAUD_LO[0] ? per_din[15:8] : per_din[7:0];

  always @(posedge mclk or posedge puc_rst) begin
    if (puc_rst) begin
      baud_lo <= 8'h00;
    end else if (baud_lo_wr) begin
      baud_lo <= baud_lo_nxt;
    end
  end

  // BAUD_HI Register
  reg  [7:0] baud_hi;

  wire       baud_hi_wr = BAUD_HI[0] ? reg_hi_wr[BAUD_HI] : reg_lo_wr[BAUD_HI];
  wire [7:0] baud_hi_nxt = BAUD_HI[0] ? per_din[15:8] : per_din[7:0];

  always @(posedge mclk or posedge puc_rst) begin
    if (puc_rst) begin
      baud_hi <= 8'h00;
    end else if (baud_hi_wr) begin
      baud_hi <= baud_hi_nxt;
    end
  end

  wire [15:0] baudrate = {baud_hi, baud_lo};

  // DATA_TX Register
  reg  [ 7:0] data_tx;

  wire        data_tx_wr = DATA_TX[0] ? reg_hi_wr[DATA_TX] : reg_lo_wr[DATA_TX];
  wire [ 7:0] data_tx_nxt = DATA_TX[0] ? per_din[15:8] : per_din[7:0];

  always @(posedge mclk or posedge puc_rst) begin
    if (puc_rst) begin
      data_tx <= 8'h00;
    end else if (data_tx_wr) begin
      data_tx <= data_tx_nxt;
    end
  end

  // DATA_RX Register
  reg [7:0] data_rx;

  reg [7:0] rxfer_buf;

  always @(posedge mclk or posedge puc_rst) begin
    if (puc_rst) begin
      data_rx <= 8'h00;
    end else if (status_rx_pnd_set) begin
      data_rx <= rxfer_buf;
    end
  end

  //////////////////////////////////////////////////////////////////////////////
  // 4) DATA OUTPUT GENERATION
  //////////////////////////////////////////////////////////////////////////////

  // Data output mux
  wire [15:0] ctrl_rd = {8'h00, (ctrl & {8{reg_rd[CTRL]}})} << (8 & {4{CTRL[0]}});
  wire [15:0] status_rd = {8'h00, (status & {8{reg_rd[STATUS]}})} << (8 & {4{STATUS[0]}});
  wire [15:0] baud_lo_rd = {8'h00, (baud_lo & {8{reg_rd[BAUD_LO]}})} << (8 & {4{BAUD_LO[0]}});
  wire [15:0] baud_hi_rd = {8'h00, (baud_hi & {8{reg_rd[BAUD_HI]}})} << (8 & {4{BAUD_HI[0]}});
  wire [15:0] data_tx_rd = {8'h00, (data_tx & {8{reg_rd[DATA_TX]}})} << (8 & {4{DATA_TX[0]}});
  wire [15:0] data_rx_rd = {8'h00, (data_rx & {8{reg_rd[DATA_RX]}})} << (8 & {4{DATA_RX[0]}});

  assign per_dout = ctrl_rd | status_rd | baud_lo_rd | baud_hi_rd | data_tx_rd | data_rx_rd;

  //////////////////////////////////////////////////////////////////////////////
  // 5)  UART CLOCK SELECTION
  //////////////////////////////////////////////////////////////////////////////

  wire uclk_en = ctrl_smclk_sel ? smclk_en : 1'b1;

  //////////////////////////////////////////////////////////////////////////////
  // 5)  UART RECEIVE LINE SYNCHRONIZTION & FILTERING
  //////////////////////////////////////////////////////////////////////////////

  // Synchronize RXD input
  reg [1:0] data_sync;

  always @(posedge mclk or posedge puc_rst) begin
    if (puc_rst) begin
      data_sync <= 2'b00;
    end else begin
      data_sync <= {data_sync[0], ~uart_rxd};
    end
  end

  wire uart_rxd_sync_n = data_sync[1];

  wire uart_rxd_sync = ~uart_rxd_sync_n;

  // RXD input buffer
  reg  [1:0] rxd_buf;
  always @(posedge mclk or posedge puc_rst) begin
    if (puc_rst) begin
      rxd_buf <= 2'h3;
    end else begin
      rxd_buf <= {rxd_buf[0], uart_rxd_sync};
    end
  end

  // Majority decision
  reg        rxd_maj;

  wire [1:0] rxd_maj_cnt = {1'b0, uart_rxd_sync} + {1'b0, rxd_buf[0]} + {1'b0, rxd_buf[1]};
  wire       rxd_maj_nxt = (rxd_maj_cnt >= 2'b10);

  always @(posedge mclk or posedge puc_rst) begin
    if (puc_rst) begin
      rxd_maj <= 1'b1;
    end else begin
      rxd_maj <= rxd_maj_nxt;
    end
  end

  wire        rxd_s = rxd_maj;
  wire        rxd_fe = rxd_maj & ~rxd_maj_nxt;

  //////////////////////////////////////////////////////////////////////////////
  // 6)  UART RECEIVE
  //////////////////////////////////////////////////////////////////////////////

  // RX Transfer counter
  reg  [ 3:0] rxfer_bit;
  reg  [15:0] rxfer_cnt;

  wire        rxfer_start = (rxfer_bit == 4'h0) & rxd_fe;
  wire        rxfer_bit_inc = (rxfer_bit != 4'h0) & (rxfer_cnt == {16{1'b0}});
  wire        rxfer_done = (rxfer_bit == 4'ha);

  always @(posedge mclk or posedge puc_rst) begin
    if (puc_rst) begin
      rxfer_bit <= 4'h0;
    end else if (~ctrl_en) begin
      rxfer_bit <= 4'h0;
    end else if (rxfer_start) begin
      rxfer_bit <= 4'h1;
    end else if (uclk_en) begin
      if (rxfer_done) begin
        rxfer_bit <= 4'h0;
      end else if (rxfer_bit_inc) begin
        rxfer_bit <= rxfer_bit + 4'h1;
      end
    end
  end

  always @(posedge mclk or posedge puc_rst) begin
    if (puc_rst) begin
      rxfer_cnt <= {16{1'b0}};
    end else if (~ctrl_en) begin
      rxfer_cnt <= {16{1'b0}};
    end else if (rxfer_start) begin
      rxfer_cnt <= {1'b0, baudrate[15:1]};
    end else if (uclk_en) begin
      if (rxfer_bit_inc) begin
        rxfer_cnt <= baudrate;
      end else if (|rxfer_cnt) begin
        rxfer_cnt <= rxfer_cnt + {16{1'b1}};
      end
    end
  end

  // Receive buffer
  wire [7:0] rxfer_buf_nxt = {rxd_s, rxfer_buf[7:1]};

  always @(posedge mclk or posedge puc_rst) begin
    if (puc_rst) begin
      rxfer_buf <= 8'h00;
    end else if (~ctrl_en) begin
      rxfer_buf <= 8'h00;
    end else if (uclk_en) begin
      if (rxfer_bit_inc) begin
        rxfer_buf <= rxfer_buf_nxt;
      end
    end
  end

  // Status flags

  // Edge detection required for the case when
  // the transmit base clock is SMCLK
  reg rxfer_done_dly;
  always @(posedge mclk or posedge puc_rst) begin
    if (puc_rst) begin
      rxfer_done_dly <= 1'b0;
    end else begin
      rxfer_done_dly <= rxfer_done;
    end
  end

  assign status_rx_pnd_set       = rxfer_done & ~rxfer_done_dly;
  assign status_rx_ovflw_pnd_set = status_rx_pnd_set & status_rx_pnd;
  assign status_rx_busy          = (rxfer_bit != 4'h0);

  //////////////////////////////////////////////////////////////////////////////
  // 5) UART TRANSMIT
  //////////////////////////////////////////////////////////////////////////////

  // TX Transfer start detection
  reg  txfer_triggered;
  wire txfer_start;

  always @(posedge mclk or posedge puc_rst) begin
    if (puc_rst) begin
      txfer_triggered <= 1'b0;
    end else if (data_tx_wr) begin
      txfer_triggered <= 1'b1;
    end else if (txfer_start) begin
      txfer_triggered <= 1'b0;
    end
  end

  // TX Transfer counter
  reg [ 3:0] txfer_bit;
  reg [15:0] txfer_cnt;

  assign txfer_start = (txfer_bit == 4'h0) & txfer_triggered;
  wire txfer_bit_inc = (txfer_bit != 4'h0) & (txfer_cnt == {16{1'b0}});
  wire txfer_done = (txfer_bit == 4'hb);

  always @(posedge mclk or posedge puc_rst) begin
    if (puc_rst) begin
      txfer_bit <= 4'h0;
    end else if (~ctrl_en) begin
      txfer_bit <= 4'h0;
    end else if (txfer_start) begin
      txfer_bit <= 4'h1;
    end else if (uclk_en) begin
      if (txfer_done) begin
        txfer_bit <= 4'h0;
      end else if (txfer_bit_inc) begin
        txfer_bit <= txfer_bit + 4'h1;
      end
    end
  end

  always @(posedge mclk or posedge puc_rst) begin
    if (puc_rst) begin
      txfer_cnt <= {16{1'b0}};
    end else if (~ctrl_en) begin
      txfer_cnt <= {16{1'b0}};
    end else if (txfer_start) begin
      txfer_cnt <= baudrate;
    end else if (uclk_en) begin
      if (txfer_bit_inc) begin
        txfer_cnt <= baudrate;
      end else if (|txfer_cnt) begin
        txfer_cnt <= txfer_cnt + {16{1'b1}};
      end
    end
  end

  // Transmit buffer
  reg  [8:0] txfer_buf;

  wire [8:0] txfer_buf_nxt = {1'b1, txfer_buf[8:1]};

  always @(posedge mclk or posedge puc_rst) begin
    if (puc_rst) begin
      txfer_buf <= 9'h1ff;
    end else if (~ctrl_en) begin
      txfer_buf <= 9'h1ff;
    end else if (txfer_start) begin
      txfer_buf <= {data_tx, 1'b0};
    end else if (uclk_en) begin
      if (txfer_bit_inc) begin
        txfer_buf <= txfer_buf_nxt;
      end
    end
  end

  assign uart_txd = txfer_buf[0];

  // Status flags

  // Edge detection required for the case when
  // the transmit base clock is SMCLK
  reg txfer_done_dly;
  always @(posedge mclk or posedge puc_rst) begin
    if (puc_rst) begin
      txfer_done_dly <= 1'b0;
    end else begin
      txfer_done_dly <= txfer_done;
    end
  end

  assign status_tx_pnd_set       = txfer_done & ~txfer_done_dly;
  assign status_tx_empty_pnd_set = status_tx_pnd_set & ~txfer_triggered;
  assign status_tx_busy          = (txfer_bit != 4'h0) | txfer_triggered;
  assign status_tx_full          = status_tx_busy & txfer_triggered;

  //////////////////////////////////////////////////////////////////////////////
  // 6) INTERRUPTS
  //////////////////////////////////////////////////////////////////////////////

  // Receive interrupt can be generated with the completion of a received byte
  // or an overflow occures.
  assign irq_uart_rx             = (status_rx_pnd & ctrl_ien_rx) | (status_rx_ovflw_pnd & ctrl_ien_rx_ovflw);

  // Transmit interrupt can be generated with the transmition completion of
  // a byte or when the tranmit buffer is empty (i.e. nothing left to transmit)
  assign irq_uart_tx             = (status_tx_pnd & ctrl_ien_tx) | (status_tx_empty_pnd & ctrl_ien_tx_empty);
endmodule  // peripheral_uart_bb
