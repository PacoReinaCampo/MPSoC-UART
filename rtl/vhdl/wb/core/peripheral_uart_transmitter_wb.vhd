-- Converted from mpsoc_wb_uart_transmitter.v
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

entity mpsoc_wb_uart_transmitter is
  generic (
    SIM : integer := 0
    );
  port (
    clk       : in  std_logic;
    wb_rst_i  : in  std_logic;
    lcr       : in  std_logic_vector(7 downto 0);
    tf_push   : in  std_logic;
    wb_dat_i  : in  std_logic_vector(7 downto 0);
    enable    : in  std_logic;
    tx_reset  : in  std_logic;
    lsr_mask  : in  std_logic;          --reset of fifo
    stx_pad_o : out std_logic;
    tstate    : out std_logic_vector(2 downto 0);
    tf_count  : out std_logic_vector(UART_FIFO_COUNTER_W-1 downto 0)
    );
end mpsoc_wb_uart_transmitter;

architecture RTL of mpsoc_wb_uart_transmitter is
  component mpsoc_wb_uart_tfifo
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
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --

  -- TRANSMITTER FINAL STATE MACHINE
  constant s_idle        : std_logic_vector(2 downto 0) := "000";
  constant s_send_start  : std_logic_vector(2 downto 0) := "001";
  constant s_send_byte   : std_logic_vector(2 downto 0) := "010";
  constant s_send_parity : std_logic_vector(2 downto 0) := "011";
  constant s_send_stop   : std_logic_vector(2 downto 0) := "100";
  constant s_pop_byte    : std_logic_vector(2 downto 0) := "101";

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal tstate_o    : std_logic_vector(2 downto 0);
  signal counter     : std_logic_vector(4 downto 0);
  signal bit_counter : std_logic_vector(2 downto 0);  -- counts the bits to be sent
  signal shift_out   : std_logic_vector(6 downto 0);  -- output shift register
  signal stx_o_tmp   : std_logic;
  signal parity_xor  : std_logic;       -- parity of the word
  signal tf_pop      : std_logic;
  signal bit_out     : std_logic;

  -- TX FIFO instance

  -- Transmitter FIFO signals
  signal tf_data_in  : std_logic_vector(UART_FIFO_WIDTH-1 downto 0);
  signal tf_data_out : std_logic_vector(UART_FIFO_WIDTH-1 downto 0);
  signal tf_overrun  : std_logic;
  signal tf_count_o  : std_logic_vector(UART_FIFO_COUNTER_W-1 downto 0);

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  tf_data_in <= wb_dat_i;

  fifo_tx : mpsoc_wb_uart_tfifo
    generic map (
      FIFO_WIDTH     => 8,
      FIFO_DEPTH     => 16,
      FIFO_POINTER_W => 4,
      FIFO_COUNTER_W => 5
      )
    port map (
      -- error bit signal is not used in transmitter FIFO
      clk          => clk,
      wb_rst_i     => wb_rst_i,
      data_in      => tf_data_in,
      data_out     => tf_data_out,
      push         => tf_push,
      pop          => tf_pop,
      overrun      => tf_overrun,
      count        => tf_count_o,
      fifo_reset   => tx_reset,
      reset_status => lsr_mask
      );

  processing_0 : process (clk, wb_rst_i)
    variable state_ep_sp : std_logic_vector(1 downto 0);
    variable state_sb    : std_logic_vector(2 downto 0);
  begin
    if (wb_rst_i = '1') then
      tstate_o    <= s_idle;
      stx_o_tmp   <= '1';
      counter     <= (others => '0');
      shift_out   <= (others => '0');
      bit_out     <= '0';
      parity_xor  <= '0';
      tf_pop      <= '0';
      bit_counter <= (others => '0');
    elsif (rising_edge(clk)) then
      if (enable = '1' or SIM = 1) then
        case ((tstate_o)) is
          when s_idle =>
            if (reduce_nor(tf_count_o) = '1') then
              tstate_o  <= s_idle;
              stx_o_tmp <= '1';
            else
              tf_pop    <= '0';
              stx_o_tmp <= '1';
              tstate_o  <= s_pop_byte;
            end if;
          when s_pop_byte =>
            tf_pop <= '1';
            case ((lcr(1 downto 0))) is  --`UART_LC_BITS*/          -- number of bits in a word
              when "00" =>
                bit_counter <= "100";
                parity_xor  <= reduce_xor(tf_data_out(4 downto 0));
              when "01" =>
                bit_counter <= "101";
                parity_xor  <= reduce_xor(tf_data_out(5 downto 0));
              when "10" =>
                bit_counter <= "110";
                parity_xor  <= reduce_xor(tf_data_out(6 downto 0));
              when "11" =>
                bit_counter <= "111";
                parity_xor  <= reduce_xor(tf_data_out(7 downto 0));
              when others =>
                null;
            end case;
            shift_out <= tf_data_out(7 downto 1);
            bit_out   <= tf_data_out(0);
            tstate_o  <= s_send_start;
          when s_send_start =>
            tf_pop <= '0';
            if (reduce_nor(counter) = '1') then
              counter <= "01111";
            elsif (counter = "00001") then
              counter  <= (others => '0');
              tstate_o <= s_send_byte;
            else
              counter <= std_logic_vector(unsigned(counter)-"00001");
            end if;
            stx_o_tmp <= '0';
            if (SIM = 1) then
              tstate_o <= s_idle;
            end if;
          when s_send_byte =>
            if (reduce_nor(counter) = '1') then
              counter <= "01111";
            elsif (counter = "00001") then
              if (bit_counter > "000") then
                bit_counter <= std_logic_vector(unsigned(bit_counter)-"001");
                bit_out     <= shift_out(0);
                tstate_o    <= s_send_byte;

                shift_out(5 downto 0) <= shift_out(6 downto 1);
              elsif (lcr(UART_LC_PE) = '0') then  -- end of byte
                tstate_o <= s_send_stop;
              else
                case (state_ep_sp) is
                  when "00" =>
                    bit_out <= not parity_xor;
                  when "01" =>
                    bit_out <= '1';
                  when "10" =>
                    bit_out <= parity_xor;
                  when "11" =>
                    bit_out <= '0';
                  when others =>
                    null;
                end case;
                tstate_o <= s_send_parity;
              end if;
              counter <= (others => '0');
            else
              counter <= std_logic_vector(unsigned(counter)-"00001");
            end if;
            stx_o_tmp <= bit_out;       -- set output pin
          when s_send_parity =>
            if (reduce_nor(counter) = '1') then
              counter <= "01111";
            elsif (counter = "00001") then
              counter  <= "00000";
              tstate_o <= s_send_stop;
            else
              counter <= std_logic_vector(unsigned(counter)-"00001");
            end if;
            stx_o_tmp <= bit_out;
          when s_send_stop =>
            if (reduce_nor(counter) = '1') then
              case (state_sb) is
                when "0XX" =>
                  -- 1 stop bit ok igor
                  counter <= "01101";
                when "100" =>
                  -- 1.5 stop bit
                  counter <= "10101";
                when others =>
                  -- 2 stop bits
                  counter <= "11101";
              end case;
            elsif (counter = "00001") then
              counter  <= (others => '0');
              tstate_o <= s_idle;
            else
              counter <= std_logic_vector(unsigned(counter)-"00001");
            end if;
            stx_o_tmp <= '1';
          when others =>
            -- should never get here
            tstate_o <= s_idle;
        end case;
      else                              -- end if enable
        -- tf_pop must be 1 cycle width
        tf_pop <= '0';
      end if;
    end if;
    state_ep_sp := lcr(UART_LC_EP) & lcr(UART_LC_SP);
    state_sb    := lcr(UART_LC_SB) & lcr(1 downto 0);
  end process;  -- transmitter logic

  tf_count  <= tf_count_o;
  tstate    <= tstate_o;
  stx_pad_o <= '0' when lcr(UART_LC_BC) = '1' else stx_o_tmp;  -- Break condition
end RTL;
