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

package peripheral_uart_pkg;

  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //

  // localparam UART_HAS_BAUDRATE_OUTPUT = 1'b0;

  // Register addresses
  localparam UART_REG_RB  = 3'd0;  // receiver buffer
  localparam UART_REG_TR  = 3'd0;  // transmitter
  localparam UART_REG_IE  = 3'd1;  // Interrupt enable
  localparam UART_REG_II  = 3'd2;  // Interrupt identification
  localparam UART_REG_FC  = 3'd2;  // FIFO control
  localparam UART_REG_LC  = 3'd3;  // Line Control
  localparam UART_REG_MC  = 3'd4;  // Modem control
  localparam UART_REG_LS  = 3'd5;  // Line status
  localparam UART_REG_MS  = 3'd6;  // Modem status
  localparam UART_REG_SR  = 3'd7;  // Scratch register
  localparam UART_REG_DL1 = 3'd0;  // Divisor latch bytes (1-2)
  localparam UART_REG_DL2 = 3'd1;

  // Interrupt Enable register bits
  localparam UART_IE_RDA  = 0;  // Received Data available interrupt
  localparam UART_IE_THRE = 1;  // Transmitter Holding Register empty interrupt
  localparam UART_IE_RLS  = 2;  // Receiver Line Status Interrupt
  localparam UART_IE_MS   = 3;  // Modem Status Interrupt

  // Interrupt Identification register bits
  localparam UART_II_IP = 0;    // Interrupt pending when 0
  // UART_II_II = 3:1;  // Interrupt identification

  // Interrupt identification values for bits 3:1
  localparam UART_II_RLS  = 3'b011;  // Receiver Line Status
  localparam UART_II_RDA  = 3'b010;  // Receiver Data available
  localparam UART_II_TI   = 3'b110;  // Timeout Indication
  localparam UART_II_THRE = 3'b001;  // Transmitter Holding Register empty
  localparam UART_II_MS   = 3'b000;  // Modem Status

  // FIFO Control Register bits
  // UART_FC_TL = 1:0;  // Trigger level

  // FIFO trigger level values
  localparam UART_FC_1  = 2'b00;
  localparam UART_FC_4  = 2'b01;
  localparam UART_FC_8  = 2'b10;
  localparam UART_FC_14 = 2'b11;

  // Line Control register bits
  //         UART_LC_BITS = 1:0;  // bits in character
  localparam UART_LC_SB   =   2;  // stop bits
  localparam UART_LC_PE   =   3;  // parity enable
  localparam UART_LC_EP   =   4;  // even parity
  localparam UART_LC_SP   =   5;  // stick parity
  localparam UART_LC_BC   =   6;  // Break control
  localparam UART_LC_DL   =   7;  // Divisor Latch access bit

  // Modem Control register bits
  localparam UART_MC_DTR  = 0;
  localparam UART_MC_RTS  = 1;
  localparam UART_MC_OUT1 = 2;
  localparam UART_MC_OUT2 = 3;
  localparam UART_MC_LB   = 4;  // Loopback mode

  // Line Status Register bits
  localparam UART_LS_DR  = 0;  // Data ready
  localparam UART_LS_OE  = 1;  // Overrun Error
  localparam UART_LS_PE  = 2;  // Parity Error
  localparam UART_LS_FE  = 3;  // Framing Error
  localparam UART_LS_BI  = 4;  // Break interrupt
  localparam UART_LS_TFE = 5;  // Transmit FIFO is empty
  localparam UART_LS_TE  = 6;  // Transmitter Empty indicator
  localparam UART_LS_EI  = 7;  // Error indicator

  // Modem Status Register bits
  localparam UART_MS_DCTS = 0;  // Delta signals
  localparam UART_MS_DDSR = 1;
  localparam UART_MS_TERI = 2;
  localparam UART_MS_DDCD = 3;
  localparam UART_MS_CCTS = 4;  // Complement signals
  localparam UART_MS_CDSR = 5;
  localparam UART_MS_CRI  = 6;
  localparam UART_MS_CDCD = 7;

  // FIFO parameter defines
  localparam UART_FIFO_WIDTH     =  8;
  localparam UART_FIFO_DEPTH     = 16;
  localparam UART_FIFO_POINTER_W =  4;
  localparam UART_FIFO_COUNTER_W =  5;

  // receiver fifo has width 11 because it has break, parity and framing error bits
  localparam UART_FIFO_REC_WIDTH = 11;

  localparam VERBOSE_WB          = 0;   // All activity on the WISHBONE is recorded
  localparam VERBOSE_LINE_STATUS = 0;   // Details about the lsr (line status register)
  localparam FAST_TEST           = 1;   // 64/1024 packets are sent

endpackage