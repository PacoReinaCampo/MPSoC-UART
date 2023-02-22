-- Converted from peripheral_uart_synthesis.sv
-- by verilog2vhdl - QueenField

--------------------------------------------------------------------------------
--                                            __ _      _     _               --
--                                           / _(_)    | |   | |              --
--                __ _ _   _  ___  ___ _ __ | |_ _  ___| | __| |              --
--               / _` | | | |/ _ \/ _ \ '_ \|  _| |/ _ \ |/ _` |              --
--              | (_| | |_| |  __/  __/ | | | | | |  __/ | (_| |              --
--               \__, |\__,_|\___|\___|_| |_|_| |_|\___|_|\__,_|              --
--                  | |                                                       --
--                  |_|                                                       --
--                                                                            --
--                                                                            --
--              Peripheral-UART for MPSoC                                     --
--              Universal Asynchronous Receiver-Transmitter for MPSoC         --
--              BlackBone Bus Interface                                       --
--                                                                            --
--------------------------------------------------------------------------------

-- Copyright (c) 2015-2016 by the author(s)
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
--     * Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--     * Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
--     * Neither the name of the authors nor the names of its contributors
--       may be used to endorse or promote products derived from this software
--       without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
-- OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
-- THE POSSIBILITY OF SUCH DAMAGE
--
--------------------------------------------------------------------------------
-- Author(s):
--   Olivier Girard <olgirard@gmail.com>
--   Paco Reina Campo <pacoreinacampo@queenfield.tech>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity peripheral_uart_testbench is
end peripheral_uart_testbench;

architecture rtl of peripheral_uart_testbench is

  ------------------------------------------------------------------------------
  -- Components
  ------------------------------------------------------------------------------

  component peripheral_uart_bb
    port (
      mclk     : in  std_logic;
      puc_rst  : in  std_logic;

      smclk_en : in  std_logic;

      uart_rxd : in  std_logic;
      uart_txd : out std_logic;

      irq_uart_rx : out std_logic;
      irq_uart_tx : out std_logic;

      per_dout : out std_logic_vector (15 downto 0);
      per_en   : in  std_logic;
      per_we   : in  std_logic_vector (1 downto 0);
      per_addr : in  std_logic_vector (13 downto 0);
      per_din  : in  std_logic_vector (15 downto 0)
    );
  end component;

  ------------------------------------------------------------------------------
  -- Variables
  ------------------------------------------------------------------------------
  signal mclk     : std_logic;
  signal puc_rst  : std_logic;

  signal smclk_en : std_logic;

  signal uart_txd : std_logic;
  signal uart_rxd : std_logic;

  signal irq_uart_rx : std_logic;
  signal irq_uart_tx : std_logic;

  signal per_dout : std_logic_vector (15 downto 0);
  signal per_en   : std_logic;
  signal per_we   : std_logic_vector (1 downto 0);
  signal per_addr : std_logic_vector (13 downto 0);
  signal per_din  : std_logic_vector (15 downto 0);
	
begin

  ------------------------------------------------------------------------------
  -- Module Body
  ------------------------------------------------------------------------------

  --DUT BB
  uart_bb : peripheral_uart_bb
    port map (
      mclk     => mclk,
      puc_rst  => puc_rst,

      smclk_en => smclk_en,

      uart_rxd => uart_rxd,
      uart_txd => uart_txd,

      irq_uart_rx => irq_uart_rx,
      irq_uart_tx => irq_uart_tx,

      per_dout => per_dout,
      per_en   => per_en,
      per_we   => per_we,
      per_addr => per_addr,
      per_din  => per_din
    );
end rtl;