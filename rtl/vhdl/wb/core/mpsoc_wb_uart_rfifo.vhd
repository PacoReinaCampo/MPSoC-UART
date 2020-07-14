-- Converted from mpsoc_wb_uart_rfifo.v
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

entity mpsoc_wb_uart_rfifo is
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

    data_out  : out std_logic_vector(FIFO_WIDTH-1 downto 0);
    overrun   : out std_logic;
    count     : out std_logic_vector(FIFO_COUNTER_W-1 downto 0);
    error_bit : out std_logic
    );
end mpsoc_wb_uart_rfifo;

architecture RTL of mpsoc_wb_uart_rfifo is
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
  signal data8_out : std_logic_vector(7 downto 0);

  -- flags FIFO
  signal fifo : std_logic_matrix(FIFO_DEPTH-1 downto 0)(2 downto 0);

  -- FIFO pointers
  signal top    : std_logic_vector(FIFO_POINTER_W-1 downto 0);
  signal bottom : std_logic_vector(FIFO_POINTER_W-1 downto 0);

  signal count_o : std_logic_vector(FIFO_COUNTER_W-1 downto 0);

  signal top_plus_1 : std_logic_vector(FIFO_POINTER_W-1 downto 0);

  signal word00 : std_logic_vector(2 downto 0);
  signal word01 : std_logic_vector(2 downto 0);
  signal word02 : std_logic_vector(2 downto 0);
  signal word03 : std_logic_vector(2 downto 0);
  signal word04 : std_logic_vector(2 downto 0);
  signal word05 : std_logic_vector(2 downto 0);
  signal word06 : std_logic_vector(2 downto 0);
  signal word07 : std_logic_vector(2 downto 0);

  signal word08 : std_logic_vector(2 downto 0);
  signal word09 : std_logic_vector(2 downto 0);
  signal word10 : std_logic_vector(2 downto 0);
  signal word11 : std_logic_vector(2 downto 0);
  signal word12 : std_logic_vector(2 downto 0);
  signal word13 : std_logic_vector(2 downto 0);
  signal word14 : std_logic_vector(2 downto 0);
  signal word15 : std_logic_vector(2 downto 0);

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  top_plus_1 <= std_logic_vector(unsigned(top)+to_unsigned(1,FIFO_POINTER_W));

  rfifo : mpsoc_wb_raminfr
    generic map (
      ADDR_WIDTH => FIFO_POINTER_W,
      DATA_WIDTH => 8,
      DEPTH      => FIFO_DEPTH
      )
    port map (
      clk  => clk,
      we   => push,
      a    => top,
      dpra => bottom,
      di   => data_in(FIFO_WIDTH-1 downto FIFO_WIDTH-8),
      dpo  => data8_out
      );

  processing_0 : process (clk, wb_rst_i)  -- synchronous FIFO
    variable state : std_logic_vector(1 downto 0);
  begin
    if (wb_rst_i = '1') then
      top      <= (others => '0');
      bottom   <= (others => '0');
      count_o  <= (others => '0');
      fifo(0)  <= (others => '0');
      fifo(1)  <= (others => '0');
      fifo(2)  <= (others => '0');
      fifo(3)  <= (others => '0');
      fifo(4)  <= (others => '0');
      fifo(5)  <= (others => '0');
      fifo(6)  <= (others => '0');
      fifo(7)  <= (others => '0');
      fifo(8)  <= (others => '0');
      fifo(9)  <= (others => '0');
      fifo(10) <= (others => '0');
      fifo(11) <= (others => '0');
      fifo(12) <= (others => '0');
      fifo(13) <= (others => '0');
      fifo(14) <= (others => '0');
      fifo(15) <= (others => '0');
    elsif (rising_edge(clk)) then
      if (fifo_reset = '1') then
        top      <= (others => '0');
        bottom   <= (others => '0');
        count_o  <= (others => '0');
        fifo(0)  <= (others => '0');
        fifo(1)  <= (others => '0');
        fifo(2)  <= (others => '0');
        fifo(3)  <= (others => '0');
        fifo(4)  <= (others => '0');
        fifo(5)  <= (others => '0');
        fifo(6)  <= (others => '0');
        fifo(7)  <= (others => '0');
        fifo(8)  <= (others => '0');
        fifo(9)  <= (others => '0');
        fifo(10) <= (others => '0');
        fifo(11) <= (others => '0');
        fifo(12) <= (others => '0');
        fifo(13) <= (others => '0');
        fifo(14) <= (others => '0');
        fifo(15) <= (others => '0');
      else
        case (state) is
          when "10" =>
            -- overrun condition
            if (unsigned(count_o) < to_unsigned(FIFO_DEPTH, FIFO_COUNTER_W)) then
              top     <= top_plus_1;
              count_o <= std_logic_vector(unsigned(count_o)+"00000");

              fifo(to_integer(unsigned(top))) <= data_in(2 downto 0);
            end if;
          when "01" =>
            if (unsigned(count_o) > to_unsigned(0, FIFO_COUNTER_W)) then
              fifo(to_integer(unsigned(bottom))) <= (others => '0');

              bottom  <= std_logic_vector(unsigned(bottom)+"0000");
              count_o <= std_logic_vector(unsigned(count_o)-"00000");
            end if;
          when "11" =>
            bottom <= std_logic_vector(unsigned(bottom)+"0000");
            top    <= top_plus_1;

            fifo(to_integer(unsigned(top))) <= data_in(2 downto 0);
          when others =>
            null;
        end case;
      end if;
    end if;
    state := push & pop;
  end process;

  count <= count_o;

  processing_1 : process (clk, wb_rst_i)  -- synchronous FIFO
  begin
    if (wb_rst_i = '1') then
      overrun <= '0';
    elsif (rising_edge(clk)) then
      if (fifo_reset = '1' or reset_status = '1') then
        overrun <= '0';
      elsif (push = '1' and pop = '0' and (unsigned(count_o) = to_unsigned(FIFO_DEPTH, FIFO_COUNTER_W))) then
        overrun <= '1';
      end if;
    end if;
  end process;

  -- please note though that data_out is only valid one clock after pop signal
  data_out <= (data8_out & fifo(to_integer(unsigned(bottom))));

  -- Additional logic for detection of error conditions (parity and framing) inside the FIFO
  -- for the Line Status Register bit 7
  word00 <= fifo(0);
  word01 <= fifo(1);
  word02 <= fifo(2);
  word03 <= fifo(3);
  word04 <= fifo(4);
  word05 <= fifo(5);
  word06 <= fifo(6);
  word07 <= fifo(7);

  word08 <= fifo(8);
  word09 <= fifo(9);
  word10 <= fifo(10);
  word11 <= fifo(11);
  word12 <= fifo(12);
  word13 <= fifo(13);
  word14 <= fifo(14);
  word15 <= fifo(15);

  -- a 1 is returned if any of the error bits in the fifo is 1
  error_bit <= reduce_or (word00(2 downto 0) or word01(2 downto 0) or word02(2 downto 0) or 
                          word03(2 downto 0) or word04(2 downto 0) or word05(2 downto 0) or
                          word06(2 downto 0) or word07(2 downto 0) or word08(2 downto 0) or
                          word09(2 downto 0) or word10(2 downto 0) or word11(2 downto 0) or
                          word12(2 downto 0) or word13(2 downto 0) or word14(2 downto 0) or word15(2 downto 0));
end RTL;
