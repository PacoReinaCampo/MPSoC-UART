-- Converted from mpsoc_wb_uart_receiver.v
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

entity mpsoc_wb_uart_receiver is
  port (
    clk       : in std_logic;
    wb_rst_i  : in std_logic;
    lcr       : in std_logic_vector(7 downto 0);
    rf_pop    : in std_logic;
    srx_pad_i : in std_logic;
    enable    : in std_logic;
    rx_reset  : in std_logic;
    lsr_mask  : in std_logic;

    counter_t     : out std_logic_vector(9 downto 0);
    rf_count      : out std_logic_vector(UART_FIFO_COUNTER_W-1 downto 0);
    rf_data_out   : out std_logic_vector(UART_FIFO_REC_WIDTH-1 downto 0);
    rf_overrun    : out std_logic;
    rf_error_bit  : out std_logic;
    rstate        : out std_logic_vector(3 downto 0);
    rf_push_pulse : out std_logic
    );
end mpsoc_wb_uart_receiver;

architecture RTL of mpsoc_wb_uart_receiver is
  component mpsoc_wb_uart_rfifo
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
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --
  constant sr_idle         : std_logic_vector(3 downto 0) := "0000";
  constant sr_rec_start    : std_logic_vector(3 downto 0) := "0001";
  constant sr_rec_bit      : std_logic_vector(3 downto 0) := "0010";
  constant sr_rec_parity   : std_logic_vector(3 downto 0) := "0011";
  constant sr_rec_stop     : std_logic_vector(3 downto 0) := "0100";
  constant sr_check_parity : std_logic_vector(3 downto 0) := "0101";
  constant sr_rec_prepare  : std_logic_vector(3 downto 0) := "0110";
  constant sr_end_bit      : std_logic_vector(3 downto 0) := "0111";
  constant sr_ca_lc_parity : std_logic_vector(3 downto 0) := "1000";
  constant sr_wait1        : std_logic_vector(3 downto 0) := "1001";
  constant sr_push         : std_logic_vector(3 downto 0) := "1010";

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal rstate_o       : std_logic_vector(3 downto 0);
  signal rcounter16     : std_logic_vector(3 downto 0);
  signal rbit_counter   : std_logic_vector(2 downto 0);
  signal rshift         : std_logic_vector(7 downto 0);  -- receiver shift register
  signal rparity        : std_logic;    -- received parity
  signal rparity_error  : std_logic;
  signal rframing_error : std_logic;    -- framing error flag
  signal rparity_xor    : std_logic;
  signal counter_b      : std_logic_vector(7 downto 0);  -- counts the 0 (low) signals
  signal rf_push_q      : std_logic;

  -- RX FIFO signals
  signal rf_data_in      : std_logic_vector(UART_FIFO_REC_WIDTH-1 downto 0);
  signal rf_push_pulse_o : std_logic;
  signal rf_push         : std_logic;
  signal rf_count_o      : std_logic_vector(UART_FIFO_COUNTER_W-1 downto 0);

  signal break_error : std_logic;

  signal rcounter16_eq_7 : std_logic;
  signal rcounter16_eq_0 : std_logic;

  signal rcounter16_minus_1 : std_logic_vector(3 downto 0);

  -- value to be set to timeout counter
  signal toc_value : std_logic_vector(9 downto 0);

  -- value to be set to break counter
  signal brc_value : std_logic_vector(7 downto 0);

  -- counts the timeout condition clocks
  signal counter_t_o : std_logic_vector(9 downto 0);

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  break_error        <= to_stdlogic(unsigned(counter_b) = X"00");
  rcounter16_eq_7    <= to_stdlogic(unsigned(rcounter16) = to_unsigned(7, 4));
  rcounter16_eq_0    <= to_stdlogic(unsigned(rcounter16) = to_unsigned(0, 4));
  rcounter16_minus_1 <= std_logic_vector(unsigned(rcounter16)-to_unsigned(1, 3));

  -- RX FIFO instance
  fifo_rx : mpsoc_wb_uart_rfifo
    generic map (
      FIFO_WIDTH     => UART_FIFO_REC_WIDTH,
      FIFO_DEPTH     => 16,
      FIFO_POINTER_W => 4,
      FIFO_COUNTER_W => 5
      )
    port map (
      clk          => clk,
      wb_rst_i     => wb_rst_i,
      data_in      => rf_data_in,
      data_out     => rf_data_out,
      push         => rf_push_pulse_o,
      pop          => rf_pop,
      overrun      => rf_overrun,
      count        => rf_count_o,
      error_bit    => rf_error_bit,
      fifo_reset   => rx_reset,
      reset_status => lsr_mask
      );

  processing_0 : process (clk, wb_rst_i)
    variable state : std_logic_vector(1 downto 0);
  begin
    if (wb_rst_i = '1') then
      rstate_o       <= sr_idle;
      rcounter16     <= (others => '0');
      rbit_counter   <= (others => '0');
      rparity_xor    <= '0';
      rframing_error <= '0';
      rparity_error  <= '0';
      rparity        <= '0';
      rshift         <= (others => '0');
      rf_push        <= '0';
      rf_data_in     <= (others => '0');
    elsif (rising_edge(clk)) then
      if (enable = '1') then
        case ((rstate_o)) is
          when sr_idle =>
            rf_push    <= '0';
            rf_data_in <= (others => '0');
            rcounter16 <= "1110";
            if (srx_pad_i = '0' and break_error = '0') then  -- detected a pulse (start bit?)
              rstate_o <= sr_rec_start;
            end if;
          when sr_rec_start =>
            rf_push <= '0';
            if (rcounter16_eq_7 = '1') then   -- check the pulse
              if (srx_pad_i = '1') then    -- no start bit
                rstate_o <= sr_idle;
              else                      -- start bit detected
                rstate_o <= sr_rec_prepare;
              end if;
            end if;
            rcounter16 <= rcounter16_minus_1;
          when sr_rec_prepare =>
            --`UART_LC_BITS*/        -- number of bits in a word
            case ((lcr(1 downto 0))) is
              when "00" =>
                rbit_counter <= "100";
              when "01" =>
                rbit_counter <= "101";
              when "10" =>
                rbit_counter <= "110";
              when "11" =>
                rbit_counter <= "111";
              when others =>
                null;
            end case;
            if (rcounter16_eq_0 = '1') then
              rstate_o   <= sr_rec_bit;
              rcounter16 <= "1110";
              rshift     <= (others => '0');
            else
              rstate_o <= sr_rec_prepare;
            end if;
            rcounter16 <= rcounter16_minus_1;
          when sr_rec_bit =>
            if (rcounter16_eq_0 = '1') then
              rstate_o <= sr_end_bit;
            end if;
            if (rcounter16_eq_7 = '1') then   -- read the bit
              case ((lcr(1 downto 0))) is  --`UART_LC_BITS*/            -- number of bits in a word
                when "00" =>
                  rshift(4 downto 0) <= (srx_pad_i & rshift(4 downto 1));
                when "01" =>
                  rshift(5 downto 0) <= (srx_pad_i & rshift(5 downto 1));
                when "10" =>
                  rshift(6 downto 0) <= (srx_pad_i & rshift(6 downto 1));
                when "11" =>
                  rshift(7 downto 0) <= (srx_pad_i & rshift(7 downto 1));
                when others =>
                  null;
              end case;
            end if;
            rcounter16 <= rcounter16_minus_1;
          when sr_end_bit =>
            -- no more bits in word
            if (rbit_counter = "000") then
              if (lcr(UART_LC_PE) = '1') then  -- choose state based on parity
                rstate_o <= sr_rec_parity;
              else
                rstate_o      <= sr_rec_stop;
                rparity_error <= '0';   -- no parity - no error :)
              end if;
            else                        -- else we have more bits to read
              rstate_o     <= sr_rec_bit;
              rbit_counter <= std_logic_vector(unsigned(rbit_counter)-"001");
            end if;
            rcounter16 <= "1110";
          when sr_rec_parity =>
            -- read the parity
            if (rcounter16_eq_7 = '1') then
              rparity  <= srx_pad_i;
              rstate_o <= sr_ca_lc_parity;
            end if;
            rcounter16 <= rcounter16_minus_1;
          when sr_ca_lc_parity =>
            -- rcounter equals 6
            rcounter16  <= rcounter16_minus_1;
            rparity_xor <= reduce_xor(rshift & rparity);  -- calculate parity on all incoming data
            rstate_o    <= sr_check_parity;
          when sr_check_parity =>
            -- rcounter equals 5
            case (state) is
              when "00" =>
                -- no error if parity 1
                rparity_error <= to_stdlogic(rparity_xor = '0');
              when "01" =>
                -- parity should sticked to 1
                rparity_error <= not rparity;
              when "10" =>
                -- error if parity is odd
                rparity_error <= to_stdlogic(rparity_xor = '1');
              when "11" =>
                -- parity should be sticked to 0
                rparity_error <= rparity;
              when others =>
                null;
            end case;
            rcounter16 <= rcounter16_minus_1;
            rstate_o   <= sr_wait1;
          when sr_wait1 =>
            if (rcounter16_eq_0 = '1') then
              rstate_o   <= sr_rec_stop;
              rcounter16 <= "1110";
            else
              rcounter16 <= rcounter16_minus_1;
            end if;
          when sr_rec_stop =>
            -- read the parity
            if (rcounter16_eq_7 = '1') then
              rframing_error <= not srx_pad_i;  -- no framing error if input is 1 (stop bit)
              rstate_o       <= sr_push;
            end if;
            rcounter16 <= rcounter16_minus_1;
          when sr_push =>
            --$display($time, ": received: %b", rf_data_in);
            if (srx_pad_i = '1' or break_error = '1') then
              if (break_error = '1') then
                rf_data_in <= (X"00" & "100");  -- break input (empty character) to receiver FIFO
              else
                rf_data_in <= (rshift & '0' & rparity_error & rframing_error);
              end if;
              rf_push  <= '1';
              rstate_o <= sr_idle;
            elsif (rframing_error = '0') then  -- There's always a framing before break_error -> wait for break or srx_pad_i
              rf_data_in <= (rshift & '0' & rparity_error & rframing_error);
              rf_push    <= '1';
              rcounter16 <= "1110";
              rstate_o   <= sr_rec_start;
            end if;
          when others =>
            rstate_o <= sr_idle;
        end case;
      end if;
    end if;
    state := lcr(UART_LC_EP) & lcr(UART_LC_SP);
  end process;

  rstate <= rstate_o;

  processing_1 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      rf_push_q <= '0';
    elsif (rising_edge(clk)) then
      rf_push_q <= rf_push;
    end if;
  end process;

  rf_push_pulse_o <= rf_push and not rf_push_q;
  rf_push_pulse   <= rf_push_pulse_o;

  -- Break condition detection.
  -- Works in conjuction with the receiver state machine
  processing_2 : process (lcr)
  begin
    case ((lcr(3 downto 0))) is
      when "0000" =>
        -- 7 bits
        toc_value <= std_logic_vector(to_unsigned(447, 10));
      when "0100" =>
        -- 7.5 bits
        toc_value <= std_logic_vector(to_unsigned(479, 10));
      when "0001" =>
      when "1000" =>
        -- 8 bits
        toc_value <= std_logic_vector(to_unsigned(511, 10));
      when "1100" =>
        -- 8.5 bits
        toc_value <= std_logic_vector(to_unsigned(543, 10));
      when "0010" =>
      when "0101" =>
      when "1001" =>
        -- 9 bits
        toc_value <= std_logic_vector(to_unsigned(575, 10));
      when "0011" =>
      when "0110" =>
      when "1010" =>
      when "1101" =>
        -- 10 bits
        toc_value <= std_logic_vector(to_unsigned(639, 10));
      when "0111" =>
      when "1011" =>
      when "1110" =>
        -- 11 bits
        toc_value <= std_logic_vector(to_unsigned(703, 10));
      when "1111" =>
        -- 12 bits
        toc_value <= std_logic_vector(to_unsigned(767, 10));
      when others =>
        null;
    end case;
  end process;
  -- case(lcr[3:0])
  brc_value <= toc_value(9 downto 2);  -- the same as timeout but 1 insead of 4 character times

  processing_3 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      counter_b <= std_logic_vector(to_unsigned(159, 8));
    elsif (rising_edge(clk)) then
      if (srx_pad_i = '1') then
        counter_b <= brc_value;         -- character time length - 1
      elsif (enable = '1' and counter_b /= X"00") then  -- only work on enable times  break not reached.
        counter_b <= std_logic_vector(unsigned(counter_b)-X"01");  -- decrement break counter
      end if;
    end if;
  end process;
  -- always of break condition detection

  -- Timeout condition detection
  processing_4 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      counter_t_o <= std_logic_vector(to_unsigned(639, 10));  -- 10 bits for the default 8N1
    elsif (rising_edge(clk)) then
      if (rf_push_pulse_o = '1' or rf_pop = '1' or unsigned(rf_count_o) = to_unsigned(0, UART_FIFO_COUNTER_W)) then  -- counter is reset when RX FIFO is empty, accessed or above trigger level
        counter_t_o <= toc_value;
      elsif (enable = '1' and counter_t_o /= "0000000000") then  -- we don't want to underflow
        counter_t_o <= std_logic_vector(unsigned(counter_t_o)-to_unsigned(1, 10));
      end if;
    end if;
  end process;

  rf_count  <= rf_count_o;
  counter_t <= counter_t_o;
end RTL;
