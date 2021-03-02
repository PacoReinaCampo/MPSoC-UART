-- Converted from mpsoc_wb_raminfr.v
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
-- *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
-- */

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mpsoc_uart_wb_pkg.all;

entity mpsoc_wb_raminfr is
  generic (
    ADDR_WIDTH : integer := 4;
    DATA_WIDTH : integer := 8;
    DEPTH      : integer := 16
    );
  port (
    clk  : in  std_logic;
    we   : in  std_logic;
    a    : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    dpra : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    di   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    dpo  : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end mpsoc_wb_raminfr;

architecture RTL of mpsoc_wb_raminfr is
  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal ram : std_logic_matrix(DEPTH-1 downto 0)(DATA_WIDTH-1 downto 0);

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  processing_0 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (we = '1') then
        ram(to_integer(unsigned(a))) <= di;
      end if;
    end if;
  end process;

  dpo <= ram(to_integer(unsigned(dpra)));
end RTL;
