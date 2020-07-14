-- Converted from mpsoc_uart_wb_pkg.v
-- by verilog2vhdl - QueenField

--//////////////////////////////////////////////////////////////////////////////
--                                            __ _      _     _               //
--                                           / _(_)    | |   | |              //
--                __ _ _   _  ___  ___ _ __ | |_ _  ___| | __| |              //
--               / _` | | | |/ _ \/ _ \ '_ \|  _| |/ _ \ |/ _` |              //
--              | (_| | |_| |  __/  __/ | | | | | |  __/ | (_| |              //
--               \__, |\__,_|\___|\___|_| |_|_| |_|\___|_|\__,_|              //
--                  | |                                                       //
--                  |_|                                                       //
--                                                                            //
--                                                                            //
--              MPSoC-RISCV CPU                                               //
--              Universal Asynchronous Receiver-Transmitter                   //
--              Wishbone Bus Interface                                        //
--                                                                            //
--//////////////////////////////////////////////////////////////////////////////

-- Copyright (c) 2018-2019 by the author(s)
-- *
-- * Permission is hereby granted, free of charge, to any person obtaining a copy
-- * of this software and associated documentation files (the "Software"), to deal
-- * in the Software without restriction, including without limitation the rights
-- * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- * copies of the Software, and to permit persons to whom the Software is
-- * furnished to do so, subject to the following conditions:
-- *
-- * The above copyright notice and this permission notice shall be included in
-- * all copies or substantial portions of the Software.
-- *
-- * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- * THE SOFTWARE.
-- *
-- * =============================================================================
-- * Author(s):
-- *   Jacob Gorban <gorban@opencores.org>
-- *   Igor Mohor <igorm@opencores.org>
-- *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
-- */

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package mpsoc_uart_wb_pkg is

  -- Register addresses
  constant UART_REG_RB  : std_logic_vector(2 downto 0) := "000";  -- receiver buffer
  constant UART_REG_TR  : std_logic_vector(2 downto 0) := "000";  -- transmitter
  constant UART_REG_IE  : std_logic_vector(2 downto 0) := "001";  -- Interrupt enable
  constant UART_REG_II  : std_logic_vector(2 downto 0) := "010";  -- Interrupt identification
  constant UART_REG_FC  : std_logic_vector(2 downto 0) := "010";  -- FIFO control
  constant UART_REG_LC  : std_logic_vector(2 downto 0) := "011";  -- Line Control
  constant UART_REG_MC  : std_logic_vector(2 downto 0) := "100";  -- Modem control
  constant UART_REG_LS  : std_logic_vector(2 downto 0) := "101";  -- Line status
  constant UART_REG_MS  : std_logic_vector(2 downto 0) := "110";  -- Modem status
  constant UART_REG_SR  : std_logic_vector(2 downto 0) := "111";  -- Scratch register
  constant UART_REG_DL1 : std_logic_vector(2 downto 0) := "000";  -- Divisor latch bytes (1-2)
  constant UART_REG_DL2 : std_logic_vector(2 downto 0) := "001";

  -- Interrupt Enable register bits
  constant UART_IE_RDA  : integer := 0;  -- Received Data available interrupt
  constant UART_IE_THRE : integer := 1;  -- Transmitter Holding Register empty interrupt
  constant UART_IE_RLS  : integer := 2;  -- Receiver Line Status Interrupt
  constant UART_IE_MS   : integer := 3;  -- Modem Status Interrupt

  -- Interrupt Identification register bits
  constant UART_II_IP : integer := 0;   -- Interrupt pending when 0

  -- Interrupt identification values for bits 3:1
  constant UART_II_RLS  : std_logic_vector(2 downto 0) := "011";  -- Receiver Line Status
  constant UART_II_RDA  : std_logic_vector(2 downto 0) := "010";  -- Receiver Data available
  constant UART_II_TI   : std_logic_vector(2 downto 0) := "110";  -- Timeout Indication
  constant UART_II_THRE : std_logic_vector(2 downto 0) := "001";  -- Transmitter Holding Register empty
  constant UART_II_MS   : std_logic_vector(2 downto 0) := "000";  -- Modem Status

  -- FIFO Control Register bits

  -- FIFO trigger level values
  constant UART_FC_1  : std_logic_vector(1 downto 0) := "00";
  constant UART_FC_4  : std_logic_vector(1 downto 0) := "01";
  constant UART_FC_8  : std_logic_vector(1 downto 0) := "10";
  constant UART_FC_14 : std_logic_vector(1 downto 0) := "11";

  -- Line Control register bits
  constant UART_LC_SB : integer := 2;     -- stop bits
  constant UART_LC_PE : integer := 3;     -- parity enable
  constant UART_LC_EP : integer := 4;     -- even parity
  constant UART_LC_SP : integer := 5;     -- stick parity
  constant UART_LC_BC : integer := 6;     -- Break control
  constant UART_LC_DL : integer := 7;     -- Divisor Latch access bit

  -- Modem Control register bits
  constant UART_MC_DTR  : integer := 0;
  constant UART_MC_RTS  : integer := 1;
  constant UART_MC_OUT1 : integer := 2;
  constant UART_MC_OUT2 : integer := 3;
  constant UART_MC_LB   : integer := 4;  -- Loopback mode

  -- Line Status Register bits
  constant UART_LS_DR  : integer := 0;  -- Data ready
  constant UART_LS_OE  : integer := 1;  -- Overrun Error
  constant UART_LS_PE  : integer := 2;  -- Parity Error
  constant UART_LS_FE  : integer := 3;  -- Framing Error
  constant UART_LS_BI  : integer := 4;  -- Break interrupt
  constant UART_LS_TFE : integer := 5;  -- Transmit FIFO is empty
  constant UART_LS_TE  : integer := 6;  -- Transmitter Empty indicator
  constant UART_LS_EI  : integer := 7;  -- Error indicator

  -- Modem Status Register bits
  constant UART_MS_DCTS : integer := 0;  -- Delta signals
  constant UART_MS_DDSR : integer := 1;
  constant UART_MS_TERI : integer := 2;
  constant UART_MS_DDCD : integer := 3;
  constant UART_MS_CCTS : integer := 4;  -- Complement signals
  constant UART_MS_CDSR : integer := 5;
  constant UART_MS_CRI  : integer := 6;
  constant UART_MS_CDCD : integer := 7;

  -- FIFO parameter defines
  constant UART_FIFO_WIDTH     : integer := 8;
  constant UART_FIFO_DEPTH     : integer := 16;
  constant UART_FIFO_POINTER_W : integer := 4;
  constant UART_FIFO_COUNTER_W : integer := 5;
  -- receiver fifo has width 11 because it has break, parity and framing error bits
  constant UART_FIFO_REC_WIDTH : integer := 11;

  constant VERBOSE_WB          : integer := 0;  -- All activity on the WISHBONE is recorded
  constant VERBOSE_LINE_STATUS : integer := 0;  -- Details about the lsr (line status register)
  constant FAST_TEST           : integer := 1;  -- 64/1024 packets are sent

  --////////////////////////////////////////////////////////////////
  --
  -- Types
  --
  type std_logic_matrix is array (natural range <>) of std_logic_vector;
  type std_logic_3array is array (natural range <>) of std_logic_matrix;
  type std_logic_4array is array (natural range <>) of std_logic_3array;
  type std_logic_5array is array (natural range <>) of std_logic_4array;
  type std_logic_6array is array (natural range <>) of std_logic_5array;
  type std_logic_7array is array (natural range <>) of std_logic_6array;
  type std_logic_8array is array (natural range <>) of std_logic_7array;
  type std_logic_9array is array (natural range <>) of std_logic_8array;

  type xy_std_logic        is array (natural range <>, natural range <>) of std_logic;
  type xy_std_logic_vector is array (natural range <>, natural range <>) of std_logic_vector;
  type xy_std_logic_matrix is array (natural range <>, natural range <>) of std_logic_matrix;
  type xy_std_logic_3array is array (natural range <>, natural range <>) of std_logic_3array;
  type xy_std_logic_4array is array (natural range <>, natural range <>) of std_logic_4array;
  type xy_std_logic_5array is array (natural range <>, natural range <>) of std_logic_5array;
  type xy_std_logic_6array is array (natural range <>, natural range <>) of std_logic_6array;
  type xy_std_logic_7array is array (natural range <>, natural range <>) of std_logic_7array;
  type xy_std_logic_8array is array (natural range <>, natural range <>) of std_logic_8array;
  type xy_std_logic_9array is array (natural range <>, natural range <>) of std_logic_9array;

  type xyz_std_logic        is array (natural range <>, natural range <>, natural range <>) of std_logic;
  type xyz_std_logic_vector is array (natural range <>, natural range <>, natural range <>) of std_logic_vector;
  type xyz_std_logic_matrix is array (natural range <>, natural range <>, natural range <>) of std_logic_matrix;
  type xyz_std_logic_3array is array (natural range <>, natural range <>, natural range <>) of std_logic_3array;
  type xyz_std_logic_4array is array (natural range <>, natural range <>, natural range <>) of std_logic_4array;
  type xyz_std_logic_5array is array (natural range <>, natural range <>, natural range <>) of std_logic_5array;
  type xyz_std_logic_6array is array (natural range <>, natural range <>, natural range <>) of std_logic_6array;
  type xyz_std_logic_7array is array (natural range <>, natural range <>, natural range <>) of std_logic_7array;
  type xyz_std_logic_8array is array (natural range <>, natural range <>, natural range <>) of std_logic_8array;
  type xyz_std_logic_9array is array (natural range <>, natural range <>, natural range <>) of std_logic_9array;

  function to_stdlogic (input : boolean) return std_logic;
  function reduce_or (reduce_or_in : std_logic_vector) return std_logic;
  function reduce_nor (reduce_nor_in : std_logic_vector) return std_logic;
  function reduce_xor (reduce_xor_in : std_logic_vector) return std_logic;
end mpsoc_uart_wb_pkg;

package body mpsoc_uart_wb_pkg is
  --////////////////////////////////////////////////////////////////
  --
  -- Functions
  --
  function to_stdlogic (
    input : boolean
    ) return std_logic is
  begin
    if input then
      return('1');
    else
      return('0');
    end if;
  end function to_stdlogic;

  function reduce_or (
    reduce_or_in : std_logic_vector
    ) return std_logic is
    variable reduce_or_out : std_logic := '0';
  begin
    for i in reduce_or_in'range loop
      reduce_or_out := reduce_or_out or reduce_or_in(i);
    end loop;
    return reduce_or_out;
  end reduce_or;

  function reduce_nor (
    reduce_nor_in : std_logic_vector
    ) return std_logic is
    variable reduce_nor_out : std_logic := '0';
  begin
    for i in reduce_nor_in'range loop
      reduce_nor_out := reduce_nor_out nor reduce_nor_in(i);
    end loop;
    return reduce_nor_out;
  end reduce_nor;

  function reduce_xor (
    reduce_xor_in : std_logic_vector
    ) return std_logic is
    variable reduce_xor_out : std_logic := '0';
  begin
    for i in reduce_xor_in'range loop
      reduce_xor_out := reduce_xor_out xor reduce_xor_in(i);
    end loop;
    return reduce_xor_out;
  end reduce_xor;
end mpsoc_uart_wb_pkg;
