-- Converted from mpsoc_uart_fifo.sv
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
--              AMBA3 APB-Lite Bus Interface                                  //
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
-- *   Francisco Javier Reina Campo <frareicam@gmail.com>
-- */

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.mpsoc_uart_ahb3_pkg.all;

entity mpsoc_uart_fifo is
  generic (
    DATA_WIDTH       : integer := 32;
    BUFFER_DEPTH     : integer := 2;
    LOG_BUFFER_DEPTH : integer := 4
  );
  port (
    clk_i  : in std_logic;
    rstn_i : in std_logic;

    clr_i : in std_logic;

    elements_o : out std_logic_vector(LOG_BUFFER_DEPTH downto 0);

    data_o  : out std_logic_vector(DATA_WIDTH-1 downto 0);
    valid_o : out std_logic;
    ready_i : in  std_logic;

    valid_i : in  std_logic;
    data_i  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    ready_o : out std_logic
    );
end mpsoc_uart_fifo;

architecture RTL of mpsoc_uart_fifo is
  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  -- Internal data structures
  signal pointer_in  : std_logic_vector(LOG_BUFFER_DEPTH-1 downto 0);  -- location to which we last wrote
  signal pointer_out : std_logic_vector(LOG_BUFFER_DEPTH-1 downto 0);  -- location from which we last sent
  signal elements    : std_logic_vector(LOG_BUFFER_DEPTH downto 0);  -- number of elements in the buffer
  signal buffered    : std_logic_matrix(BUFFER_DEPTH-1 downto 0)(DATA_WIDTH-1 downto 0);

  signal full : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --

  full       <= to_stdlogic(elements = std_logic_vector(to_unsigned(BUFFER_DEPTH, LOG_BUFFER_DEPTH)));
  elements_o <= elements;

  processing_0 : process (clk_i, rstn_i)
  begin
    if (rstn_i = '0') then
      elements <= (others => '0');
    elsif (rising_edge(clk_i)) then
      if (clr_i = '1') then
        elements <= (others => '0');
      -- ------------------
      -- Are we filling up?
      -- ------------------
      -- One out, none in
      elsif (ready_i = '1' and (elements /= "0000") and (valid_i = '0' or full = '1')) then
        elements <= std_logic_vector(unsigned(elements)-to_unsigned(1, LOG_BUFFER_DEPTH));
      -- None out, one in
      elsif (((elements /= "0000") or ready_i = '0') and valid_i = '1' and full = '0') then
        elements <= std_logic_vector(unsigned(elements)+to_unsigned(1, LOG_BUFFER_DEPTH));
      end if;
    end if;
  end process;
  -- Else, either one out and one in, or none out and none in - stays unchanged

  processing_1 : process (clk_i, rstn_i)
  begin
    if (rstn_i = '0') then
      for i in 0 to BUFFER_DEPTH - 1 loop
        buffered(i) <= (others => '0');
      end loop;
    elsif (rising_edge(clk_i)) then
      -- Update the memory
      if (valid_i = '1' and full = '0') then
        buffered(to_integer(unsigned(pointer_in))) <= data_i;
      end if;
    end if;
  end process;

  processing_2 : process (clk_i, rstn_i)
  begin
    if (rstn_i = '0') then
      pointer_out <= (others => '0');
      pointer_in  <= (others => '0');
    elsif (rising_edge(clk_i)) then
      if (clr_i = '1') then
        pointer_out <= (others => '0');
        pointer_in  <= (others => '0');
      -- ------------------------------------
      -- Check what to do with the input side
      -- ------------------------------------
      -- We have some input, increase by 1 the input pointer
      elsif (valid_i = '1' and full = '0') then
        if (unsigned(pointer_in) = to_unsigned(BUFFER_DEPTH-1, LOG_BUFFER_DEPTH)) then
          pointer_in <= (others => '0');
        else
          pointer_in <= std_logic_vector(unsigned(pointer_in)+to_unsigned(1, LOG_BUFFER_DEPTH));
        end if;
        -- Else we don't have any input, the input pointer stays the same

        -- -------------------------------------
        -- Check what to do with the output side
        -- -------------------------------------
        -- We had pushed one flit out, we can try to go for the next one
        if (ready_i = '1' and (elements /= "0000")) then
          if (unsigned(pointer_out) = to_unsigned(BUFFER_DEPTH-1, LOG_BUFFER_DEPTH)) then
            pointer_out <= (others => '0');
          else
            pointer_out <= std_logic_vector(unsigned(pointer_in)+to_unsigned(1, LOG_BUFFER_DEPTH));
          end if;
        end if;
      -- Else stay on the same output location
      end if;
    end if;
  end process;

  -- Update output ports
  data_o  <= buffered(to_integer(unsigned(pointer_out)));
  valid_o <= to_stdlogic(elements /= "0000");

  ready_o <= not full;
end RTL;
