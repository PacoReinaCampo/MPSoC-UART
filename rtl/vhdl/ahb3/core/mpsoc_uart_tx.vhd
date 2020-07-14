-- Converted from mpsoc_uart_tx.sv
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
-- *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
-- */

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mpsoc_uart_ahb3_pkg.all;

entity mpsoc_uart_tx is
  port (
    clk_i           : in  std_logic;
    rstn_i          : in  std_logic;
    tx_o            : out std_logic;
    busy_o          : out std_logic;
    cfg_en_i        : in  std_logic;
    cfg_div_i       : in  std_logic_vector(15 downto 0);
    cfg_parity_en_i : in  std_logic;
    cfg_bits_i      : in  std_logic_vector(1 downto 0);
    cfg_stop_bits_i : in  std_logic;
    tx_data_i       : in  std_logic_vector(7 downto 0);
    tx_valid_i      : in  std_logic;
    tx_ready_o      : out std_logic
    );
end mpsoc_uart_tx;

architecture RTL of mpsoc_uart_tx is
  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --

  constant IDLE           : std_logic_vector(2 downto 0) := "110";
  constant START_BIT      : std_logic_vector(2 downto 0) := "101";
  constant DATA           : std_logic_vector(2 downto 0) := "100";
  constant PARITY         : std_logic_vector(2 downto 0) := "011";
  constant STOP_BIT_FIRST : std_logic_vector(2 downto 0) := "010";
  constant STOP_BIT_LAST  : std_logic_vector(2 downto 0) := "001";

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  signal CS : std_logic_vector(2 downto 0);
  signal ns : std_logic_vector(2 downto 0);

  signal reg_data      : std_logic_vector(7 downto 0);
  signal reg_data_next : std_logic_vector(7 downto 0);

  signal reg_bit_count      : std_logic_vector(2 downto 0);
  signal reg_bit_count_next : std_logic_vector(2 downto 0);

  signal s_target_bits : std_logic_vector(2 downto 0);

  signal parity_bit      : std_logic;
  signal parity_bit_next : std_logic;

  signal sampleData : std_logic;

  signal baud_cnt   : std_logic_vector(15 downto 0);
  signal baudgen_en : std_logic;
  signal bit_done   : std_logic;

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
    tx_o               <= '1';
    sampleData         <= '0';
    reg_bit_count_next <= reg_bit_count;
    reg_data_next      <= ('1' & reg_data(7 downto 1));
    tx_ready_o         <= '0';
    baudgen_en         <= '0';
    parity_bit_next    <= parity_bit;
    case ((CS)) is
      when IDLE =>
        if (cfg_en_i = '1') then
          tx_ready_o <= '1';
        elsif (tx_valid_i = '1') then
          ns            <= START_BIT;
          sampleData    <= '1';
          reg_data_next <= tx_data_i;
        end if;
      when START_BIT =>
        tx_o            <= '0';
        parity_bit_next <= '0';
        baudgen_en      <= '1';
        if (bit_done = '1') then
          ns <= DATA;
        end if;
      when DATA =>
        tx_o            <= reg_data(0);
        baudgen_en      <= '1';
        parity_bit_next <= parity_bit xor reg_data(0);
        if (bit_done = '1') then
          if (reg_bit_count = s_target_bits) then
            reg_bit_count_next <= "000";
            if (cfg_parity_en_i = '1') then
              ns <= PARITY;
            else
              ns <= STOP_BIT_FIRST;
            end if;
          else
            reg_bit_count_next <= std_logic_vector(unsigned(reg_bit_count)+"001");
            sampleData         <= '1';
          end if;
        end if;
      when PARITY =>
        tx_o       <= parity_bit;
        baudgen_en <= '1';
        if (bit_done = '1') then
          ns <= STOP_BIT_FIRST;
        end if;
      when STOP_BIT_FIRST =>
        tx_o       <= '1';
        baudgen_en <= '1';
        if (bit_done = '1') then
          if (cfg_stop_bits_i = '1') then
            ns <= STOP_BIT_LAST;
          else
            ns <= IDLE;
          end if;
        end if;
      when STOP_BIT_LAST =>
        tx_o       <= '1';
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
      end if;
      if (sampleData = '1') then
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

  processing_3 : process (clk_i, rstn_i)
  begin
    if (rstn_i = '0') then
      baud_cnt <= X"0000";
      bit_done <= '0';
    elsif (rising_edge(clk_i)) then
      if (baudgen_en = '1') then
        if (baud_cnt = cfg_div_i) then
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
end RTL;
