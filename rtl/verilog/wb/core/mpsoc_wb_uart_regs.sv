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
 *   Francisco Javier Reina Campo <frareicam@gmail.com>
 */

`include "mpsoc_uart_wb_pkg.sv"

`define UART_DL1 7:0
`define UART_DL2 15:8

module mpsoc_wb_uart_regs #(
  parameter SIM = 0
)
  (
    input            clk,
    input            wb_rst_i,
    input      [2:0] wb_addr_i,
    input      [7:0] wb_dat_i,
    output reg [7:0] wb_dat_o,
    input            wb_we_i,
    input            wb_re_i,

    output       stx_pad_o,
    input        srx_pad_i,

    input     [3:0] modem_inputs,
    output          rts_pad_o,
    output          dtr_pad_o,
    output reg      int_o,
    output          baud_o
  );

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  reg        enable;

  wire                     srx_pad;

  reg [ 3:0]                ier;
  reg [ 3:0]                iir;
  reg [ 1:0]                fcr;  // bits 7 and 6 of fcr. Other bits are ignored
  reg [ 4:0]                mcr;
  reg [ 7:0]                lcr;
  reg [ 7:0]                msr;
  reg [15:0]                dl;  // 32-bit divisor latch
  reg [ 7:0]                scratch;  // UART scratch register
  reg                       start_dlc;  // activate dlc on writing to UART_DL1
  reg                       lsr_mask_d;  // delay for lsr_mask condition
  reg                       msi_reset;  // reset MSR 4 lower bits indicator
  //reg                     three_clear; // THRE interrupt clear flag
  reg [15:0]                dlc;  // 32-bit divisor latch counter

  reg [3:0]               trigger_level; // trigger level of the receiver FIFO
  reg                     rx_reset;
  reg                     tx_reset;

  wire                     dlab;  // divisor latch access bit
  wire                     cts_pad_i, dsr_pad_i, ri_pad_i, dcd_pad_i;  // modem status bits
  wire                     loopback;  // loopback bit (MCR bit 4)
  wire                     cts, dsr, ri, dcd;  // effective signals
  wire                     cts_c, dsr_c, ri_c, dcd_c;  // Complement effective signals (considering loopback)

  // LSR bits wires and regs
  wire [7:0]             lsr;
  wire                   lsr0, lsr1, lsr2, lsr3, lsr4, lsr5, lsr6, lsr7;
  reg                    lsr0r, lsr1r, lsr2r, lsr3r, lsr4r, lsr5r, lsr6r, lsr7r;
  wire                   lsr_mask; // lsr_mask

  // Interrupt signals
  wire                     rls_int;  // receiver line status interrupt
  wire                     rda_int;  // receiver data available interrupt
  wire                     ti_int;   // timeout indicator interrupt
  wire                     thre_int; // transmitter holding register empty interrupt
  wire                     ms_int;   // modem status interrupt

  // FIFO signals
  reg                             tf_push;
  reg                             rf_pop;
  wire [`UART_FIFO_REC_WIDTH-1:0] rf_data_out;
  wire                            rf_error_bit; // an error (parity or framing) is inside the fifo
  wire                            rf_overrun;
  wire                            rf_push_pulse;
  wire [`UART_FIFO_COUNTER_W-1:0] rf_count;
  wire [`UART_FIFO_COUNTER_W-1:0] tf_count;
  wire [                     2:0] tstate;
  wire [                     3:0] rstate;
  wire [                     9:0] counter_t;

  wire                      thre_set_en; // THRE status is delayed one character time when a character is written to fifo.
  reg  [7:0]                block_cnt;   // While counter counts, THRE status is blocked (delayed one character cycle)
  reg  [7:0]                block_value; // One character length minus stop bit

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //
  assign baud_o = enable; // baud_o is actually the enable signal
  assign                   lsr[7:0] = { lsr7r, lsr6r, lsr5r, lsr4r, lsr3r, lsr2r, lsr1r, lsr0r };

  assign                   {cts_pad_i, dsr_pad_i, ri_pad_i, dcd_pad_i} = modem_inputs;
  assign                   {cts, dsr, ri, dcd} = ~{cts_pad_i,dsr_pad_i,ri_pad_i,dcd_pad_i};

  assign                  {cts_c, dsr_c, ri_c, dcd_c} = loopback ? {mcr[`UART_MC_RTS],mcr[`UART_MC_DTR],mcr[`UART_MC_OUT1],mcr[`UART_MC_OUT2]}
                          : {cts_pad_i,dsr_pad_i,ri_pad_i,dcd_pad_i};

  assign                   dlab = lcr[`UART_LC_DL];
  assign                   loopback = mcr[4];

  // assign modem outputs
  assign                   rts_pad_o = mcr[`UART_MC_RTS];
  assign                   dtr_pad_o = mcr[`UART_MC_DTR];

  // Transmitter Instance
  wire serial_out;

  mpsoc_wb_uart_transmitter #(
    .SIM (SIM)
  )
  transmitter (
    .clk       (clk),
    .wb_rst_i  (wb_rst_i),
    .lcr       (lcr),
    .tf_push   (tf_push),
    .wb_dat_i  (wb_dat_i),
    .enable    (enable),
    .stx_pad_o (serial_out),
    .tstate    (tstate),
    .tf_count  (tf_count),
    .tx_reset  (tx_reset),
    .lsr_mask  (lsr_mask)
  );

  // Synchronizing and sampling serial RX input
  mpsoc_wb_uart_sync_flops #(
    .WIDTH      (1),
    .INIT_VALUE (1'b1)
  )
  i_uart_sync_flops (
    .rst_i           (wb_rst_i),
    .clk_i           (clk),
    .stage1_rst_i    (1'b0),
    .stage1_clk_en_i (1'b1),
    .async_dat_i     (srx_pad_i),
    .sync_dat_o      (srx_pad)
  );

  // handle loopback
  wire serial_in = loopback ? serial_out : srx_pad;
  assign stx_pad_o = loopback ? 1'b1 : serial_out;

  // Receiver Instance
  mpsoc_wb_uart_receiver receiver (
    .clk           (clk),
    .wb_rst_i      (wb_rst_i),
    .lcr           (lcr),
    .rf_pop        (rf_pop),
    .srx_pad_i     (serial_in),
    .enable        (enable), 
    .counter_t     (counter_t),
    .rf_count      (rf_count),
    .rf_data_out   (rf_data_out),
    .rf_error_bit  (rf_error_bit),
    .rf_overrun    (rf_overrun),
    .rx_reset      (rx_reset),
    .lsr_mask      (lsr_mask),
    .rstate        (rstate),
    .rf_push_pulse (rf_push_pulse)
  );

  // Asynchronous reading here because the outputs are sampled in uart_wb.v file 
  always @(dl or dlab or ier or iir or scratch
           or lcr or lsr or msr or rf_data_out or wb_addr_i or wb_re_i) begin  // asynchrounous reading
    case (wb_addr_i)
      `UART_REG_RB  : wb_dat_o = dlab ? dl[`UART_DL1] : rf_data_out[10:3];
      `UART_REG_IE  : wb_dat_o = dlab ? dl[`UART_DL2] : {4'd0,ier};
      `UART_REG_II  : wb_dat_o = {4'b1100,iir};
      `UART_REG_LC  : wb_dat_o = lcr;
      `UART_REG_LS  : wb_dat_o = lsr;
      `UART_REG_MS  : wb_dat_o = msr;
      `UART_REG_SR  : wb_dat_o = scratch;
      default       : wb_dat_o = 8'b0; // ??
    endcase // case(wb_addr_i)
  end  // always @ (dl or dlab or ier or iir or scratch...

  // rf_pop signal handling
  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i)
      rf_pop <= 0;
    else if (rf_pop)  // restore the signal to 0 after one clock cycle
      rf_pop <= 0;
    else if (wb_re_i && wb_addr_i == `UART_REG_RB && !dlab)
      rf_pop <= 1; // advance read pointer
  end

  wire  lsr_mask_condition;
  wire  iir_read;
  wire  msr_read;
  wire  fifo_read;
  wire  fifo_write;

  assign lsr_mask_condition = (wb_re_i && wb_addr_i == `UART_REG_LS && !dlab);
  assign iir_read = (wb_re_i && wb_addr_i == `UART_REG_II && !dlab);
  assign msr_read = (wb_re_i && wb_addr_i == `UART_REG_MS && !dlab);
  assign fifo_read = (wb_re_i && wb_addr_i == `UART_REG_RB && !dlab);
  assign fifo_write = (wb_we_i && wb_addr_i == `UART_REG_TR && !dlab);

  // lsr_mask_d delayed signal handling
  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i)
      lsr_mask_d <= 0;
    else // reset bits in the Line Status Register
      lsr_mask_d <= lsr_mask_condition;
  end

  // lsr_mask is rise detected
  assign lsr_mask = lsr_mask_condition && ~lsr_mask_d;

  // msi_reset signal handling
  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i)
      msi_reset <= 1;
    else if (msi_reset)
      msi_reset <= 0;
    else if (msr_read)
      msi_reset <= 1;  // reset bits in Modem Status Register
  end

  //   WRITES AND RESETS

  // Line Control Register
  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i)
      lcr <= 8'b00000011; // 8n1 setting
    else if (wb_we_i && wb_addr_i==`UART_REG_LC)
      lcr <= wb_dat_i;
  end

  // Interrupt Enable Register or UART_DL2
  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) begin
      ier <= 4'b0000; // no interrupts after reset
      `ifdef PRESCALER_PRESET_HARD
      dl[`UART_DL2] <= `PRESCALER_HIGH_PRESET;
      `else
      dl[`UART_DL2] <= 8'b0;
      `endif
    end
    else if (wb_we_i && wb_addr_i==`UART_REG_IE)
      if (dlab) begin
        dl[`UART_DL2] <=
        `ifdef PRESCALER_PRESET_HARD
        dl[`UART_DL2];
        `else
        wb_dat_i;
        `endif
      end
    else
      ier <= wb_dat_i[3:0]; // ier uses only 4 lsb
  end

  // FIFO Control Register and rx_reset, tx_reset signals
  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) begin
      fcr <= 2'b11;
      rx_reset <= 0;
      tx_reset <= 0;
    end else
      if (wb_we_i && wb_addr_i==`UART_REG_FC) begin
        fcr <= wb_dat_i[7:6];
        rx_reset <= wb_dat_i[1];
        tx_reset <= wb_dat_i[2];
      end
    else begin
      rx_reset <= 0;
      tx_reset <= 0;
    end
  end

  // Modem Control Register
  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i)
      mcr <= 5'b0;
    else if (wb_we_i && wb_addr_i==`UART_REG_MC)
      mcr <= wb_dat_i[4:0];
  end

  // Scratch register
  // Line Control Register
  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i)
      scratch <= 0; // 8n1 setting
    else if (wb_we_i && wb_addr_i==`UART_REG_SR)
      scratch <= wb_dat_i;
  end

  // TX_FIFO or UART_DL1
  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) begin
      `ifdef PRESCALER_PRESET_HARD
      dl[`UART_DL1]  <= `PRESCALER_LOW_PRESET;
      `else
      dl[`UART_DL1]  <= 8'b0;
      `endif
      tf_push   <= 1'b0;
      start_dlc <= 1'b0;
    end
    else if (wb_we_i && wb_addr_i==`UART_REG_TR)
      if (dlab) begin
        `ifdef PRESCALER_PRESET_HARD
        dl[`UART_DL1] <= dl[`UART_DL1];
        `else
        dl[`UART_DL1] <= wb_dat_i;
        `endif
        start_dlc <= 1'b1; // enable DL counter
        tf_push <= 1'b0;
      end
    else begin
      tf_push   <= 1'b1;
      start_dlc <= 1'b0;
    end // else: !if(dlab)
    else begin
      start_dlc <= 1'b0;
      tf_push   <= 1'b0;
    end // else: !if(dlab)
  end

  // Receiver FIFO trigger level selection logic (asynchronous mux)
  always @(fcr)
    case (fcr[`UART_FC_TL])
      2'b00 : trigger_level = 1;
      2'b01 : trigger_level = 4;
      2'b10 : trigger_level = 8;
      2'b11 : trigger_level = 14;
    endcase // case(fcr[`UART_FC_TL])

  //  STATUS REGISTERS

  // Modem Status Register
  reg [3:0] delayed_modem_signals;
  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) begin
      msr <= 0;
      delayed_modem_signals[3:0] <= 0;
    end
    else begin
      msr[`UART_MS_DDCD:`UART_MS_DCTS] <= msi_reset ? 4'b0 :
      msr[`UART_MS_DDCD:`UART_MS_DCTS] | ({dcd, ri, dsr, cts} ^ delayed_modem_signals[3:0]);
      msr[`UART_MS_CDCD:`UART_MS_CCTS] <= {dcd_c, ri_c, dsr_c, cts_c};
      delayed_modem_signals[3:0] <= {dcd, ri, dsr, cts};
    end
  end

  // Line Status Register

  // activation conditions
  assign lsr0 = (rf_count==0 && rf_push_pulse);  // data in receiver fifo available set condition
  assign lsr1 = rf_overrun;     // Receiver overrun error
  assign lsr2 = rf_data_out[1]; // parity error bit
  assign lsr3 = rf_data_out[0]; // framing error bit
  assign lsr4 = rf_data_out[2]; // break error in the character
  assign lsr5 = (tf_count==5'b0 && thre_set_en);  // transmitter fifo is empty
  assign lsr6 = (tf_count==5'b0 && thre_set_en && (tstate == /*`S_IDLE */ 0)); // transmitter empty
  assign lsr7 = rf_error_bit | rf_overrun;

  // lsr bit0 (receiver data available)
  reg    lsr0_d;

  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) lsr0_d <= 0;
    else lsr0_d <= lsr0;
  end

  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) lsr0r <= 0;
    else lsr0r <= (rf_count==1 && rf_pop && !rf_push_pulse || rx_reset) ? 1'b0 : // deassert condition
         lsr0r || (lsr0 && ~lsr0_d); // set on rise of lsr0 and keep asserted until deasserted 
  end

  // lsr bit 1 (receiver overrun)
  reg lsr1_d; // delayed

  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) lsr1_d <= 0;
    else lsr1_d <= lsr1;
  end

  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) lsr1r <= 0;
    else  lsr1r <= lsr_mask ? 1'b0 : lsr1r || (lsr1 && ~lsr1_d); // set on rise
  end

  // lsr bit 2 (parity error)
  reg lsr2_d; // delayed

  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) lsr2_d <= 0;
    else lsr2_d <= lsr2;
  end

  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) lsr2r <= 0;
    else lsr2r <= lsr_mask ? 1'b0 : lsr2r || (lsr2 && ~lsr2_d); // set on rise
  end

  // lsr bit 3 (framing error)
  reg lsr3_d; // delayed

  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) lsr3_d <= 0;
    else lsr3_d <= lsr3;
  end

  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) lsr3r <= 0;
    else lsr3r <= lsr_mask ? 1'b0 : lsr3r || (lsr3 && ~lsr3_d); // set on rise
  end

  // lsr bit 4 (break indicator)
  reg lsr4_d; // delayed

  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) lsr4_d <= 0;
    else lsr4_d <= lsr4;
  end

  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) lsr4r <= 0;
    else lsr4r <= lsr_mask ? 1'b0 : lsr4r || (lsr4 && ~lsr4_d);
  end

  // lsr bit 5 (transmitter fifo is empty)
  reg lsr5_d;

  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) lsr5_d <= 1;
    else lsr5_d <= lsr5;
  end

  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) lsr5r <= 1;
    else lsr5r <= (fifo_write) ? 1'b0 :  lsr5r || (lsr5 && ~lsr5_d);
  end

  // lsr bit 6 (transmitter empty indicator)
  reg lsr6_d;

  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) lsr6_d <= 1;
    else lsr6_d <= lsr6;
  end

  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) lsr6r <= 1;
    else lsr6r <= (fifo_write) ? 1'b0 : lsr6r || (lsr6 && ~lsr6_d);
  end

  // lsr bit 7 (error in fifo)
  reg lsr7_d;

  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) lsr7_d <= 0;
    else lsr7_d <= lsr7;
  end

  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) lsr7r <= 0;
    else lsr7r <= lsr_mask ? 1'b0 : lsr7r || (lsr7 && ~lsr7_d);
  end

  // Frequency divider
  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i)
      dlc <= 0;
    else if (start_dlc | ~ (|dlc))
      dlc <= dl - 16'd1;  // preset counter
    else
      dlc <= dlc - 16'd1;  // decrement counter
  end

  // Enable signal generation logic
  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i)
      enable <= 1'b0;
    else if (|dl & ~(|dlc))  // dl>0 & dlc==0
      enable <= 1'b1;
    else
      enable <= 1'b0;
  end

  // Delaying THRE status for one character cycle after a character is written to an empty fifo.
  always @(lcr)
    case (lcr[3:0])
      4'b0000                             : block_value =  95; // 6 bits
      4'b0100                             : block_value = 103; // 6.5 bits
      4'b0001, 4'b1000                    : block_value = 111; // 7 bits
      4'b1100                             : block_value = 119; // 7.5 bits
      4'b0010, 4'b0101, 4'b1001           : block_value = 127; // 8 bits
      4'b0011, 4'b0110, 4'b1010, 4'b1101  : block_value = 143; // 9 bits
      4'b0111, 4'b1011, 4'b1110           : block_value = 159; // 10 bits
      4'b1111                             : block_value = 175; // 11 bits
    endcase // case(lcr[3:0])

  // Counting time of one character minus stop bit
  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i)
      block_cnt <= 8'd0;
    else if(lsr5r & fifo_write)  // THRE bit set & write to fifo occured
      block_cnt <= SIM ? 8'd1 : block_value;
    else if (enable & block_cnt != 8'b0)  // only work on enable times
      block_cnt <= block_cnt - 8'd1;  // decrement break counter
  end // always of break condition detection

  // Generating THRE status enable signal
  assign thre_set_en = ~(|block_cnt);

  //  INTERRUPT LOGIC
  assign rls_int  = ier[`UART_IE_RLS] && (lsr[`UART_LS_OE] || lsr[`UART_LS_PE] || lsr[`UART_LS_FE] || lsr[`UART_LS_BI]);
  assign rda_int  = ier[`UART_IE_RDA] && (rf_count >= {1'b0,trigger_level});
  assign thre_int = ier[`UART_IE_THRE] && lsr[`UART_LS_TFE];
  assign ms_int   = ier[`UART_IE_MS] && (| msr[3:0]);
  assign ti_int   = ier[`UART_IE_RDA] && (counter_t == 10'b0) && (|rf_count);

  reg    rls_int_d;
  reg    thre_int_d;
  reg    ms_int_d;
  reg    ti_int_d;
  reg    rda_int_d;

  // delay lines
  always  @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) rls_int_d <= 0;
    else rls_int_d <= rls_int;
  end

  always  @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) rda_int_d <= 0;
    else rda_int_d <= rda_int;
  end

  always  @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) thre_int_d <= 0;
    else thre_int_d <= thre_int;
  end

  always  @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) ms_int_d <= 0;
    else ms_int_d <= ms_int;
  end

  always  @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) ti_int_d <= 0;
    else ti_int_d <= ti_int;
  end

  // rise detection signals
  wire    rls_int_rise;
  wire    thre_int_rise;
  wire    ms_int_rise;
  wire    ti_int_rise;
  wire    rda_int_rise;

  assign rda_int_rise    = rda_int & ~rda_int_d;
  assign rls_int_rise    = rls_int & ~rls_int_d;
  assign thre_int_rise   = thre_int & ~thre_int_d;
  assign ms_int_rise     = ms_int & ~ms_int_d;
  assign ti_int_rise     = ti_int & ~ti_int_d;

  // interrupt pending flags
  reg  rls_int_pnd;
  reg  rda_int_pnd;
  reg  thre_int_pnd;
  reg  ms_int_pnd;
  reg  ti_int_pnd;

  // interrupt pending flags assignments
  always  @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) rls_int_pnd <= 0;
    else 
      rls_int_pnd <= lsr_mask ? 1'b0 :                  // reset condition
                     rls_int_rise ? 1'b1 :              // latch condition
                     rls_int_pnd && ier[`UART_IE_RLS];  // default operation: remove if masked
  end

  always  @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) rda_int_pnd <= 0;
    else 
      rda_int_pnd <= ((rf_count == {1'b0,trigger_level}) && fifo_read) ? 1'b0 :  // reset condition
                     rda_int_rise ? 1'b1 :  // latch condition
                     rda_int_pnd && ier[`UART_IE_RDA];  // default operation: remove if masked
  end

  always  @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) thre_int_pnd <= 0;
    else 
      thre_int_pnd <= fifo_write || (iir_read & ~iir[`UART_II_IP] & iir[`UART_II_II] == `UART_II_THRE)? 1'b0 :
                      thre_int_rise ? 1'b1 :
                      thre_int_pnd && ier[`UART_IE_THRE];
  end

  always  @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) ms_int_pnd <= 0;
    else 
      ms_int_pnd <= msr_read ? 1'b0 :
                    ms_int_rise ? 1'b1 :
                    ms_int_pnd && ier[`UART_IE_MS];
  end

  always  @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i) ti_int_pnd <= 0;
    else 
      ti_int_pnd <= fifo_read ? 1'b0 :
                    ti_int_rise ? 1'b1 :
                    ti_int_pnd && ier[`UART_IE_RDA];
  end  // end of pending flags

  // INT_O logic
  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i)  
      int_o <= 1'b0;
    else
      int_o <=
      rls_int_pnd   ?  ~lsr_mask          :
      rda_int_pnd   ? 1'b1                :
      ti_int_pnd    ? ~fifo_read          :
      thre_int_pnd  ? !(fifo_write & iir_read) :
      ms_int_pnd    ? ~msr_read           :
      1'd0;  // if no interrupt are pending
  end

  // Interrupt Identification register
  always @(posedge clk or posedge wb_rst_i) begin
    if (wb_rst_i)
      iir <= 1;
    else if (rls_int_pnd) begin  // interrupt is pending
      iir[`UART_II_II] <= `UART_II_RLS;  // set identification register to correct value
      iir[`UART_II_IP] <= 1'b0;  // and clear the IIR bit 0 (interrupt pending)
    end else  // the sequence of conditions determines priority of interrupt identification
      if (rda_int) begin
        iir[`UART_II_II] <= `UART_II_RDA;
        iir[`UART_II_IP] <= 1'b0;
      end
    else if (ti_int_pnd) begin
      iir[`UART_II_II] <= `UART_II_TI;
      iir[`UART_II_IP] <= 1'b0;
    end
    else if (thre_int_pnd) begin
      iir[`UART_II_II] <= `UART_II_THRE;
      iir[`UART_II_IP] <= 1'b0;
    end
    else if (ms_int_pnd) begin
      iir[`UART_II_II] <= `UART_II_MS;
      iir[`UART_II_IP] <= 1'b0;
    end
    else begin  // no interrupt is pending
      iir[`UART_II_II] <= 0;
      iir[`UART_II_IP] <= 1'b1;
    end
  end
endmodule
