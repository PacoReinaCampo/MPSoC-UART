-- Converted from mpsoc_wb_uart_tfifo.v
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

use work.mpsoc_uart_wb_pkg.all;

entity mpsoc_wb_uart_tfifo is
  generic (
    FIFO_WIDTH     : integer := 8;
    FIFO_DEPTH     : integer := 16;
    FIFO_POINTER_W : integer := 4;
    FIFO_COUNTER_W : integer := 5
    );
  port (
    clk          : in std_logic;
    wb_rst_i     : in std_logic;
    push         : in std_logic;
    pop          : in std_logic;
    data_in      : in std_logic_vector(FIFO_WIDTH-1 downto 0);
    fifo_reset   : in std_logic;
    reset_status : in std_logic;

    data_out : out std_logic_vector(FIFO_WIDTH-1 downto 0);
    overrun  : out std_logic;
    count    : out std_logic_vector(FIFO_COUNTER_W-1 downto 0)
    );
end mpsoc_wb_uart_tfifo;

architecture RTL of mpsoc_wb_uart_tfifo is
  component mpsoc_wb_raminfr
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
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  -- FIFO pointers
  signal top    : std_logic_vector(FIFO_POINTER_W-1 downto 0);
  signal bottom : std_logic_vector(FIFO_POINTER_W-1 downto 0);

  signal count_o    : std_logic_vector(FIFO_COUNTER_W-1 downto 0);
  signal top_plus_1 : std_logic_vector(FIFO_POINTER_W-1 downto 0);

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  top_plus_1 <= std_logic_vector(unsigned(top)+"0001");

  tfifo : mpsoc_wb_raminfr
    generic map (
      ADDR_WIDTH => FIFO_POINTER_W,
      DATA_WIDTH => FIFO_WIDTH,
      DEPTH      => FIFO_DEPTH
      )
    port map (
      clk  => clk,
      we   => push,
      a    => top,
      dpra => bottom,
      di   => data_in,
      dpo  => data_out
      );

  processing_0 : process (clk, wb_rst_i)  -- synchronous FIFO
    variable state : std_logic_vector(1 downto 0);
  begin
    if (wb_rst_i = '1') then
      top     <= (others => '0');
      bottom  <= (others => '0');
      count_o <= (others => '0');
    elsif (rising_edge(clk)) then
      if (fifo_reset = '1') then
        top     <= (others => '0');
        bottom  <= (others => '0');
        count_o <= (others => '0');
      else
        case (state) is
          when "10" =>
            -- overrun condition
            if (unsigned(count_o) < to_unsigned(FIFO_DEPTH, FIFO_COUNTER_W)) then
              top   <= top_plus_1;
              count_o <= std_logic_vector(unsigned(count_o)+"00001");
            end if;
          when "01" =>
            if (unsigned(count_o) > to_unsigned(0, FIFO_COUNTER_W)) then
              bottom <= std_logic_vector(unsigned(bottom)+"0001");
              count_o  <= std_logic_vector(unsigned(count_o)-"00001");
            end if;
          when "11" =>
            bottom <= std_logic_vector(unsigned(bottom)+"0001");
            top    <= top_plus_1;
          when others =>
            null;
        end case;
      end if;
    end if;
    state := push & pop;
  end process;

  processing_1 : process (clk, wb_rst_i)  -- synchronous FIFO
  begin
    if (wb_rst_i = '1') then
      overrun <= '0';
    elsif (rising_edge(clk)) then
      if (fifo_reset = '1' or reset_status = '1') then
        overrun <= '0';
      elsif (push = '1' and (unsigned(count_o) < to_unsigned(FIFO_DEPTH, FIFO_COUNTER_W))) then
        overrun <= '1';
      end if;
    end if;
  end process;

  count <= count_o;
end RTL;
