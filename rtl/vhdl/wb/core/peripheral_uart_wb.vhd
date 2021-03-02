-- Converted from mpsoc_wb_uart.v
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

entity mpsoc_wb_uart is
  generic (
    SIM   : integer := 0;
    DEBUG : integer := 0
    );
  port (
    wb_clk_i : in std_logic;
    wb_rst_i : in std_logic;

    -- WISHBONE interface
    wb_adr_i : in  std_logic_vector(2 downto 0);
    wb_dat_i : in  std_logic_vector(7 downto 0);
    wb_dat_o : out std_logic_vector(7 downto 0);
    wb_we_i  : in  std_logic;
    wb_stb_i : in  std_logic;
    wb_cyc_i : in  std_logic;
    wb_sel_i : in  std_logic_vector(3 downto 0);
    wb_ack_o : out std_logic;
    int_o    : out std_logic;

    -- UART  signals
    srx_pad_i : in  std_logic;
    stx_pad_o : out std_logic;
    rts_pad_o : out std_logic;
    cts_pad_i : in  std_logic;
    dtr_pad_o : out std_logic;
    dsr_pad_i : in  std_logic;
    ri_pad_i  : in  std_logic;
    dcd_pad_i : in  std_logic;

    -- optional baudrate output
    baud_o : out std_logic
    );
end mpsoc_wb_uart;

architecture RTL of mpsoc_wb_uart is
  component mpsoc_wb_uart_peripheral_bridge
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
  end component;

  component mpsoc_wb_uart_regs
    generic (
      SIM : integer := 0
      );
    port (
      clk       : in  std_logic;
      wb_rst_i  : in  std_logic;
      wb_addr_i : in  std_logic_vector(2 downto 0);
      wb_dat_i  : in  std_logic_vector(7 downto 0);
      wb_dat_o  : out std_logic_vector(7 downto 0);
      wb_we_i   : in  std_logic;
      wb_re_i   : in  std_logic;

      stx_pad_o : out std_logic;
      srx_pad_i : in  std_logic;

      modem_inputs : in  std_logic_vector(3 downto 0);
      rts_pad_o    : out std_logic;
      dtr_pad_o    : out std_logic;
      int_o        : out std_logic;
      baud_o       : out std_logic
      );
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal wb_dat8_i  : std_logic_vector(7 downto 0);  -- 8-bit internal data input
  signal wb_dat8_o  : std_logic_vector(7 downto 0);  -- 8-bit internal data output output
  signal wb_adr_int : std_logic_vector(2 downto 0);
  signal we_o       : std_logic;  -- Write enable for registers
  signal re_o       : std_logic;  -- Read enable for registers

  signal modem_inputs : std_logic_vector(3 downto 0);

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --

  -- WISHBONE interface module
  wb_interface : mpsoc_wb_uart_peripheral_bridge
    port map (
      clk        => wb_clk_i,
      wb_rst_i   => wb_rst_i,
      wb_dat_i   => wb_dat_i,
      wb_dat_o   => wb_dat_o,
      wb_dat8_i  => wb_dat8_i,
      wb_dat8_o  => wb_dat8_o,
      wb_dat32_o => (others => '0'),
      wb_sel_i   => (others => '0'),
      wb_we_i    => wb_we_i,
      wb_stb_i   => wb_stb_i,
      wb_cyc_i   => wb_cyc_i,
      wb_ack_o   => wb_ack_o,
      wb_adr_i   => wb_adr_i,
      wb_adr_int => wb_adr_int,
      we_o       => we_o,
      re_o       => re_o
      );

  -- Registers
  regs : mpsoc_wb_uart_regs
    generic map (
      SIM => SIM
      )
    port map (
      clk          => wb_clk_i,
      wb_rst_i     => wb_rst_i,
      wb_addr_i    => wb_adr_int,
      wb_dat_i     => wb_dat8_i,
      wb_dat_o     => wb_dat8_o,
      wb_we_i      => we_o,
      wb_re_i      => re_o,

      stx_pad_o    => stx_pad_o,
      srx_pad_i    => srx_pad_i,

      modem_inputs => modem_inputs,
      rts_pad_o    => rts_pad_o,
      dtr_pad_o    => dtr_pad_o,
      int_o        => int_o,
      baud_o       => baud_o
      );

  modem_inputs <= (cts_pad_i & dsr_pad_i & ri_pad_i & dcd_pad_i);
end RTL;
