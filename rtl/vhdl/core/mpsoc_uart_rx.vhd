-- Converted from mpsoc_uart_rx.sv
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

entity mpsoc_uart_rx is
  port (
    clk_i           : in  std_logic;
    rstn_i          : in  std_logic;
    rx_i            : in  std_logic;
    cfg_div_i       : in  std_logic_vector(15 downto 0);
    cfg_en_i        : in  std_logic;
    cfg_parity_en_i : in  std_logic;
    cfg_bits_i      : in  std_logic_vector(1 downto 0);
    busy_o          : out std_logic;
    err_o           : out std_logic;
    err_clr_i       : in  std_logic;
    rx_data_o       : out std_logic_vector(7 downto 0);
    rx_valid_o      : out std_logic;
    rx_ready_i      : in  std_logic
    );
end mpsoc_uart_rx;

architecture RTL of mpsoc_uart_rx is
  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --

  constant IDLE      : std_logic_vector(2 downto 0) := "110";
  constant START_BIT : std_logic_vector(2 downto 0) := "101";
  constant DATA      : std_logic_vector(2 downto 0) := "100";
  constant SAVE_DATA : std_logic_vector(2 downto 0) := "011";
  constant PARITY    : std_logic_vector(2 downto 0) := "010";
  constant STOP_BIT  : std_logic_vector(2 downto 0) := "001";

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

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  signal CS, ns : std_logic_vector(2 downto 0);

  signal reg_data      : std_logic_vector(7 downto 0);
  signal reg_data_next : std_logic_vector(7 downto 0);

  signal reg_rx_sync : std_logic_vector(2 downto 0);

  signal reg_bit_count      : std_logic_vector(2 downto 0);
  signal reg_bit_count_next : std_logic_vector(2 downto 0);

  signal s_target_bits : std_logic_vector(2 downto 0);

  signal parity_bit      : std_logic;
  signal parity_bit_next : std_logic;

  signal sampleData : std_logic;

  signal baud_cnt   : std_logic_vector(15 downto 0);
  signal baudgen_en : std_logic;
  signal bit_done   : std_logic;

  signal start_bit_s : std_logic;
  signal set_error   : std_logic;
  signal s_rx_fall   : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --

  busy_o <= to_stdlogic(CS /= IDLE);

  processing_0 : process (cfg_bits_i)
  begin
    case ((cfg_bits_i)) is
      when "00" =>
        s_target_bits <= "100";
      when "01" =>
        s_target_bits <= "101";
      when "10" =>
        s_target_bits <= "110";
      when "11" =>
        s_target_bits <= "111";
      when others =>
        null;
    end case;
  end process;

  processing_1 : process (CS)
  begin
    ns                 <= CS;
    sampleData         <= '0';
    reg_bit_count_next <= reg_bit_count;
    reg_data_next      <= reg_data;
    rx_valid_o         <= '0';
    baudgen_en         <= '0';
    start_bit_s        <= '0';
    parity_bit_next    <= parity_bit;
    set_error          <= '0';
    case ((CS)) is
      when IDLE =>
        if (s_rx_fall = '1') then
          ns          <= START_BIT;
          baudgen_en  <= '1';
          start_bit_s <= '1';
        end if;
      when START_BIT =>
        parity_bit_next <= '0';
        baudgen_en      <= '1';
        start_bit_s     <= '1';
        if (bit_done = '1') then
          ns <= DATA;
        end if;
      when DATA =>
        baudgen_en      <= '1';
        parity_bit_next <= parity_bit xor reg_rx_sync(2);
        case ((cfg_bits_i)) is
          when "00" =>
            reg_data_next <= ("000" & reg_rx_sync(2) & reg_data(4 downto 1));
          when "01" =>
            reg_data_next <= ("00"  & reg_rx_sync(2) & reg_data(5 downto 1));
          when "10" =>
            reg_data_next <= ('0'   & reg_rx_sync(2) & reg_data(6 downto 1));
          when "11" =>
            reg_data_next <= (reg_rx_sync(2) & reg_data(7 downto 1));
          when others =>
            null;
        end case;
        if (bit_done = '1') then
          sampleData <= '1';
          if (reg_bit_count = s_target_bits) then
            reg_bit_count_next <= "000";
            ns                 <= SAVE_DATA;
          else
            reg_bit_count_next <= std_logic_vector(unsigned(reg_bit_count)+"001");
          end if;
        end if;
      when SAVE_DATA =>
        baudgen_en <= '1';
        rx_valid_o <= '1';
        if (rx_ready_i = '1') then
          if (cfg_parity_en_i = '1') then
            ns <= PARITY;
          else
            ns <= STOP_BIT;
          end if;
        end if;
      when PARITY =>
        baudgen_en <= '1';
        if (bit_done = '1') then
          if (parity_bit /= reg_rx_sync(2)) then
            set_error <= '1';
          end if;
          ns <= STOP_BIT;
        end if;
      when STOP_BIT =>
        baudgen_en <= '1';
        if (bit_done = '1') then
          ns <= IDLE;
        end if;
      when others =>
        ns <= IDLE;
    end case;
  end process;

  processing_2 : process (clk_i, rstn_i)
  begin
    if (rstn_i = '0') then
      CS            <= IDLE;
      reg_data      <= X"FF";
      reg_bit_count <= "000";
      parity_bit    <= '0';
    elsif (rising_edge(clk_i)) then
      if (bit_done = '1') then
        parity_bit <= parity_bit_next;
      elsif (sampleData = '1') then
        reg_data <= reg_data_next;
      end if;
      reg_bit_count <= reg_bit_count_next;
      if (cfg_en_i = '1') then
        CS <= ns;
      else
        CS <= IDLE;
      end if;
    end if;
  end process;

  s_rx_fall <= not reg_rx_sync(1) and reg_rx_sync(2);

  processing_3 : process (clk_i, rstn_i)
  begin
    if (rstn_i = '0') then
      reg_rx_sync <= "111";
    elsif (rising_edge(clk_i)) then
      if (cfg_en_i = '1') then
        reg_rx_sync <= (reg_rx_sync(1 downto 0) & rx_i);
      else
        reg_rx_sync <= "111";
      end if;
    end if;
  end process;

  processing_4 : process (clk_i, rstn_i)
  begin
    if (rstn_i = '0') then
      baud_cnt <= X"0000";
      bit_done <= '0';
    elsif (rising_edge(clk_i)) then
      if (baudgen_en = '1') then
        if (start_bit_s = '0' and (baud_cnt = cfg_div_i)) then
          baud_cnt <= X"0000";
          bit_done <= '1';
        elsif (start_bit_s = '1' and (baud_cnt = ('0' & cfg_div_i(15 downto 1)))) then
          baud_cnt <= X"0000";
          bit_done <= '1';
        else
          baud_cnt <= std_logic_vector(unsigned(baud_cnt)+to_unsigned(1, 16));
          bit_done <= '0';
        end if;
      else
        baud_cnt <= X"0000";
        bit_done <= '0';
      end if;
    end if;
  end process;

  processing_5 : process (clk_i, rstn_i)
  begin
    if (rstn_i = '0') then
      err_o <= '0';
    elsif (rising_edge(clk_i)) then
      if (err_clr_i = '1') then
        err_o <= '0';
      elsif (set_error = '1') then
        err_o <= '1';
      end if;
    end if;
  end process;

  rx_data_o <= reg_data;
end RTL;
