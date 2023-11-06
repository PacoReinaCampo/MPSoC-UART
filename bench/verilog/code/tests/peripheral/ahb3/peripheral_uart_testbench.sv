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
//              AMBA3 AHB-Lite Bus Interface                                  //
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

module peripheral_uart_testbench;

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////
  parameter HADDR_SIZE = 32;
  parameter HDATA_SIZE = 32;
  parameter APB_ADDR_WIDTH = 10;
  parameter APB_DATA_WIDTH = 8;
  parameter SYNC_DEPTH = 3;

  //////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////

  // Common signals
  wire                        HRESETn;
  wire                        HCLK;

  // UART AHB3
  wire                        mst_uart_HSEL;
  wire  [HADDR_SIZE     -1:0] mst_uart_HADDR;
  wire  [HDATA_SIZE     -1:0] mst_uart_HWDATA;
  wire  [HDATA_SIZE     -1:0] mst_uart_HRDATA;
  wire                        mst_uart_HWRITE;
  wire  [                2:0] mst_uart_HSIZE;
  wire  [                2:0] mst_uart_HBURST;
  wire  [                3:0] mst_uart_HPROT;
  wire  [                1:0] mst_uart_HTRANS;
  wire                        mst_uart_HMASTLOCK;
  wire                        mst_uart_HREADY;
  wire                        mst_uart_HREADYOUT;
  wire                        mst_uart_HRESP;

  logic [APB_ADDR_WIDTH -1:0] uart_PADDR;
  logic [APB_DATA_WIDTH -1:0] uart_PWDATA;
  logic                       uart_PWRITE;
  logic                       uart_PSEL;
  logic                       uart_PENABLE;
  logic [APB_DATA_WIDTH -1:0] uart_PRDATA;
  logic                       uart_PREADY;
  logic                       uart_PSLVERR;

  logic                       uart_rx_i;  // Receiver input
  logic                       uart_tx_o;  // Transmitter output

  logic                       uart_event_o;

  //////////////////////////////////////////////////////////////////////////////
  // Module Body
  //////////////////////////////////////////////////////////////////////////////

  // DUT AHB3
  peripheral_apb2ahb #(
    .HADDR_SIZE(HADDR_SIZE),
    .HDATA_SIZE(HDATA_SIZE),
    .PADDR_SIZE(APB_ADDR_WIDTH),
    .PDATA_SIZE(APB_DATA_WIDTH),
    .SYNC_DEPTH(SYNC_DEPTH)
  ) apb2ahb (
    // AHB Slave Interface
    .HRESETn(HRESETn),
    .HCLK   (HCLK),

    .HSEL     (mst_uart_HSEL),
    .HADDR    (mst_uart_HADDR),
    .HWDATA   (mst_uart_HWDATA),
    .HRDATA   (mst_uart_HRDATA),
    .HWRITE   (mst_uart_HWRITE),
    .HSIZE    (mst_uart_HSIZE),
    .HBURST   (mst_uart_HBURST),
    .HPROT    (mst_uart_HPROT),
    .HTRANS   (mst_uart_HTRANS),
    .HMASTLOCK(mst_uart_HMASTLOCK),
    .HREADYOUT(mst_uart_HREADYOUT),
    .HREADY   (mst_uart_HREADY),
    .HRESP    (mst_uart_HRESP),

    // APB Master Interface
    .PRESETn(HRESETn),
    .PCLK   (HCLK),

    .PSEL   (uart_PSEL),
    .PENABLE(uart_PENABLE),
    .PPROT  (),
    .PWRITE (uart_PWRITE),
    .PSTRB  (),
    .PADDR  (uart_PADDR),
    .PWDATA (uart_PWDATA),
    .PRDATA (uart_PRDATA),
    .PREADY (uart_PREADY),
    .PSLVERR(uart_PSLVERR)
  );

  peripheral_uart_apb4 #(
    .APB_ADDR_WIDTH(APB_ADDR_WIDTH),
    .APB_DATA_WIDTH(APB_DATA_WIDTH)
  ) uart_apb4 (
    .RSTN(HRESETn),
    .CLK (HCLK),

    .PADDR  (uart_PADDR),
    .PWDATA (uart_PWDATA),
    .PWRITE (uart_PWRITE),
    .PSEL   (uart_PSEL),
    .PENABLE(uart_PENABLE),
    .PRDATA (uart_PRDATA),
    .PREADY (uart_PREADY),
    .PSLVERR(uart_PSLVERR),

    .rx_i(uart_rx_i),
    .tx_o(uart_tx_o),

    .event_o(uart_event_o)
  );
endmodule
