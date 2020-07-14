-- Converted from mpsoc_wb_uart_peripheral_bridge.v
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
-- *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
-- */

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mpsoc_uart_wb_pkg.all;

entity mpsoc_wb_uart_peripheral_bridge is
  port (
    clk : in std_logic;

    -- WISHBONE interface  
    wb_rst_i : in std_logic;
    wb_we_i  : in std_logic;
    wb_stb_i : in std_logic;
    wb_cyc_i : in std_logic;
    wb_sel_i : in std_logic_vector(3 downto 0);
    wb_adr_i : in std_logic_vector(2 downto 0);  --WISHBONE address line

    wb_dat_i   : in  std_logic_vector(7 downto 0);  --input WISHBONE bus 
    wb_dat_o   : out std_logic_vector(7 downto 0);
    wb_adr_int : out std_logic_vector(2 downto 0);  -- internal signal for address bus
    wb_dat8_o  : in  std_logic_vector(7 downto 0);  -- internal 8 bit output to be put into wb_dat_o
    wb_dat8_i  : out std_logic_vector(7 downto 0);
    wb_dat32_o : in  std_logic_vector(31 downto 0);  -- 32 bit data output (for debug interface)
    wb_ack_o   : out std_logic;
    we_o       : out std_logic;
    re_o       : out std_logic
    );
end mpsoc_wb_uart_peripheral_bridge;

architecture RTL of mpsoc_wb_uart_peripheral_bridge is
  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal wb_dat_is : std_logic_vector(7 downto 0);

  signal wb_adr_is : std_logic_vector(2 downto 0);
  signal wb_we_is  : std_logic;
  signal wb_cyc_is : std_logic;
  signal wb_stb_is : std_logic;
  signal wre       : std_logic;  -- timing control signal for write or read enable

  -- wb_ack_o FSM
  signal wbstate : std_logic_vector(1 downto 0);

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  processing_0 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      wb_ack_o <= '0';
      wbstate  <= "00";
      wre      <= '1';
    elsif (rising_edge(clk)) then
      case ((wbstate)) is
        when "00" =>
          if (wb_stb_is = '1' and wb_cyc_is = '1') then
            wre      <= '0';
            wbstate  <= "01";
            wb_ack_o <= '1';
          else
            wre      <= '1';
            wb_ack_o <= '0';
          end if;
        when "01" =>
          wb_ack_o <= '0';
          wbstate  <= "10";
          wre      <= '0';
        when "10" =>
          wb_ack_o <= '0';
          wbstate  <= "11";
          wre      <= '0';
        when "11" =>
          wb_ack_o <= '0';
          wbstate  <= "00";
          wre      <= '1';
        when others =>
          null;
      end case;
    end if;
  end process;

  we_o <= wb_we_is and wb_stb_is and wb_cyc_is and wre;  --WE for registers  
  re_o <= not wb_we_is and wb_stb_is and wb_cyc_is and wre;  --RE for registers  

  -- Sample input signals
  processing_1 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      wb_adr_is <= (others => '0');
      wb_we_is  <= '0';
      wb_cyc_is <= '0';
      wb_stb_is <= '0';
      wb_dat_is <= (others => '0');
    elsif (rising_edge(clk)) then
      wb_adr_is <= wb_adr_i;
      wb_we_is  <= wb_we_i;
      wb_cyc_is <= wb_cyc_i;
      wb_stb_is <= wb_stb_i;
      wb_dat_is <= wb_dat_i;
    end if;
  end process;

  processing_2 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      wb_dat_o <= (others => '0');
    elsif (rising_edge(clk)) then
      wb_dat_o <= wb_dat8_o;
    end if;
  end process;

  processing_3 : process (wb_dat_is)
  begin
    wb_dat8_i <= wb_dat_is;
  end process;

  wb_adr_int <= wb_adr_is;
end RTL;
