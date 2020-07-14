-- Converted from mpsoc_wb_uart_sync_flops.v
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
-- *   Andrej Erzen <andreje@flextronics.si>
-- *   Tadej Markovic <tadejm@flextronics.si>
-- *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
-- */

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mpsoc_wb_uart_sync_flops is
  generic (
    WIDTH      : integer   := 1;
    INIT_VALUE : std_logic := '0'
    );
  port (
    rst_i           : in  std_logic;  -- reset input
    clk_i           : in  std_logic;  -- clock input
    stage1_rst_i    : in  std_logic;  -- synchronous reset for stage 1 FF
    stage1_clk_en_i : in  std_logic;  -- synchronous clock enable for stage 1 FF
    async_dat_i     : in  std_logic_vector(WIDTH-1 downto 0);  -- asynchronous data input
    sync_dat_o      : out std_logic_vector(WIDTH-1 downto 0)  -- synchronous data output
    );
end mpsoc_wb_uart_sync_flops;

architecture RTL of mpsoc_wb_uart_sync_flops is
  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  -- Internal signal declarations
  signal flop_0     : std_logic_vector(WIDTH-1 downto 0);

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --

  -- first stage
  processing_0 : process (clk_i, rst_i)
  begin
    if (rst_i = '1') then
      flop_0 <= (others => INIT_VALUE);
    elsif (rising_edge(clk_i)) then
      flop_0 <= async_dat_i;
    end if;
  end process;

  -- second stage
  processing_1 : process (clk_i, rst_i)
  begin
    if (rst_i = '1') then
      sync_dat_o <= (others => INIT_VALUE);
    elsif (rising_edge(clk_i)) then
      if (stage1_rst_i = '1') then
        sync_dat_o <= (others => INIT_VALUE);
      elsif (stage1_clk_en_i = '1') then
        sync_dat_o <= flop_0;
      end if;
    end if;
  end process;
end RTL;
