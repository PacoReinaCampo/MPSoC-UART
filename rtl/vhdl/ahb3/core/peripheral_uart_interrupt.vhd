-- Converted from peripheral_uart_interrupt.sv
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
--              Peripheral-UART for MPSoC                                     //
--              Universal Asynchronous Receiver-Transmitter for MPSoC         //
--              AMBA4 APB-Lite Bus Interface                                  //
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
-- *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
-- */

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity peripheral_uart_interrupt is
  generic (
    TX_FIFO_DEPTH : integer := 32;
    RX_FIFO_DEPTH : integer := 32
  );
  port (
    clk_i  : in std_logic;
    rstn_i : in std_logic;

    -- registers
    IER_i : in std_logic_vector(2 downto 0);  -- interrupt enable register
    RDA_i : in std_logic;                     -- receiver data available
    CTI_i : in std_logic;                     -- character timeout indication

    -- control logic
    error_i         : in std_logic;
    rx_elements_i   : in std_logic_vector(integer(log2(real(RX_FIFO_DEPTH))) downto 0);
    tx_elements_i   : in std_logic_vector(integer(log2(real(TX_FIFO_DEPTH))) downto 0);
    trigger_level_i : in std_logic_vector(1 downto 0);

    clr_int_i : in std_logic_vector(3 downto 0);  -- one hot

    interrupt_o : out std_logic;
    IIR_o       : out std_logic_vector(3 downto 0)
    );
end peripheral_uart_interrupt;

architecture RTL of peripheral_uart_interrupt is
  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  signal iir_n : std_logic_vector(3 downto 0);
  signal iir_q : std_logic_vector(3 downto 0);

  signal trigger_level_reached : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --

  processing_0 : process (trigger_level_i)
  begin
    trigger_level_reached <= '0';
    case ((trigger_level_i)) is
      when "00" =>
        if (to_integer(unsigned(rx_elements_i)) = 1) then
          trigger_level_reached <= '1';
        end if;
      when "01" =>
        if (to_integer(unsigned(rx_elements_i)) = 4) then
          trigger_level_reached <= '1';
        end if;
      when "10" =>
        if (to_integer(unsigned(rx_elements_i)) = 8) then
          trigger_level_reached <= '1';
        end if;
      when "11" =>
        if (to_integer(unsigned(rx_elements_i)) = 14) then
          trigger_level_reached <= '1';
        end if;
      when others =>
        null;
    end case;
  end process;

  processing_1 : process (clr_int_i)
  begin
    if (clr_int_i = "0000") then
      iir_n <= iir_q;
    else
      iir_n <= iir_q and not (clr_int_i);
    end if;
    -- Receiver line status interrupt on: Overrun error, parity error, framing error or break interrupt
    if (IER_i(2) = '1' and error_i = '1') then
      iir_n <= "1100";
    -- Received data available or trigger level reached in FIFO mode
    elsif (IER_i(0) = '1' and (trigger_level_reached = '1' or RDA_i = '1')) then
      iir_n <= "1000";
    -- Character timeout indication
    elsif (IER_i(0) = '1' and CTI_i = '1') then
      iir_n <= "1000";
    -- Transmitter holding register empty
    elsif (IER_i(1) = '1' and to_integer(unsigned(tx_elements_i)) = 0) then
      iir_n <= "0100";
    end if;
  end process;

  processing_2 : process (clk_i, rstn_i)
  begin
    if (rstn_i = '0') then
      iir_q <= "0001";
    elsif (rising_edge(clk_i)) then
      iir_q <= iir_n;
    end if;
  end process;

  IIR_o       <= iir_q;
  interrupt_o <= not iir_q(0);
end RTL;
