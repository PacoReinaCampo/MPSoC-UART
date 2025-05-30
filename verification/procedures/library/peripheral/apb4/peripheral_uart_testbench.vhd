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
--              AMBA4 AHB-Lite Bus Interface                                  --
--                                                                            --
--------------------------------------------------------------------------------

-- Copyright (c) 2018-2019 by the author(s)
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
--------------------------------------------------------------------------------
-- Author(s):
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

  component peripheral_apb2ahb
    generic (
      HADDR_SIZE : integer := 32;
      HDATA_SIZE : integer := 32;
      PADDR_SIZE : integer := 10;
      PDATA_SIZE : integer := 8;
      SYNC_DEPTH : integer := 3
      );
    port (
      -- AHB Slave Interface
      HRESETn   : in  std_logic;
      HCLK      : in  std_logic;
      HSEL      : in  std_logic;
      HADDR     : in  std_logic_vector(HADDR_SIZE-1 downto 0);
      HWDATA    : in  std_logic_vector(HDATA_SIZE-1 downto 0);
      HRDATA    : out std_logic_vector(HDATA_SIZE-1 downto 0);
      HWRITE    : in  std_logic;
      HSIZE     : in  std_logic_vector(2 downto 0);
      HBURST    : in  std_logic_vector(2 downto 0);
      HPROT     : in  std_logic_vector(3 downto 0);
      HTRANS    : in  std_logic_vector(1 downto 0);
      HMASTLOCK : in  std_logic;
      HREADYOUT : out std_logic;
      HREADY    : in  std_logic;
      HRESP     : out std_logic;

      -- APB Master Interface
      PRESETn : in  std_logic;
      PCLK    : in  std_logic;
      PSEL    : out std_logic;
      PENABLE : out std_logic;
      PPROT   : out std_logic_vector(2 downto 0);
      PWRITE  : out std_logic;
      PSTRB   : out std_logic;
      PADDR   : out std_logic_vector(PADDR_SIZE-1 downto 0);
      PWDATA  : out std_logic_vector(PDATA_SIZE-1 downto 0);
      PRDATA  : in  std_logic_vector(PDATA_SIZE-1 downto 0);
      PREADY  : in  std_logic;
      PSLVERR : in  std_logic
      );
  end component;

  component peripheral_uart_apb4
    generic (
      APB_ADDR_WIDTH : integer := 12;   -- APB slaves are 4KB by default
      APB_DATA_WIDTH : integer := 32    -- APB slaves are 4KB by default
      );
    port (
      CLK     : in  std_logic;
      RSTN    : in  std_logic;
      PADDR   : in  std_logic_vector(APB_ADDR_WIDTH-1 downto 0);
      PWDATA  : in  std_logic_vector(APB_DATA_WIDTH-1 downto 0);
      PWRITE  : in  std_logic;
      PSEL    : in  std_logic;
      PENABLE : in  std_logic;
      PRDATA  : out std_logic_vector(APB_DATA_WIDTH-1 downto 0);
      PREADY  : out std_logic;
      PSLVERR : out std_logic;

      rx_i : in  std_logic;             -- Receiver input
      tx_o : out std_logic;             -- Transmitter output

      event_o : out std_logic           -- interrupt/event output
      );
  end component;

  ------------------------------------------------------------------------------
  --  Constants
  ------------------------------------------------------------------------------
  constant HADDR_SIZE     : integer := 32;
  constant HDATA_SIZE     : integer := 32;
  constant APB_ADDR_WIDTH : integer := 10;
  constant APB_DATA_WIDTH : integer := 8;
  constant SYNC_DEPTH     : integer := 3;

  ------------------------------------------------------------------------------
  -- Variables
  ------------------------------------------------------------------------------

  -- Common signals
  signal HRESETn : std_logic;
  signal HCLK    : std_logic;

  -- UART AHB4
  signal mst_uart_HSEL      : std_logic;
  signal mst_uart_HADDR     : std_logic_vector(HADDR_SIZE-1 downto 0);
  signal mst_uart_HWDATA    : std_logic_vector(HDATA_SIZE-1 downto 0);
  signal mst_uart_HRDATA    : std_logic_vector(HDATA_SIZE-1 downto 0);
  signal mst_uart_HWRITE    : std_logic;
  signal mst_uart_HSIZE     : std_logic_vector(2 downto 0);
  signal mst_uart_HBURST    : std_logic_vector(2 downto 0);
  signal mst_uart_HPROT     : std_logic_vector(3 downto 0);
  signal mst_uart_HTRANS    : std_logic_vector(1 downto 0);
  signal mst_uart_HMASTLOCK : std_logic;
  signal mst_uart_HREADY    : std_logic;
  signal mst_uart_HREADYOUT : std_logic;
  signal mst_uart_HRESP     : std_logic;

  signal uart_PADDR   : std_logic_vector(APB_ADDR_WIDTH-1 downto 0);
  signal uart_PWDATA  : std_logic_vector(APB_DATA_WIDTH-1 downto 0);
  signal uart_PWRITE  : std_logic;
  signal uart_PSEL    : std_logic;
  signal uart_PENABLE : std_logic;
  signal uart_PRDATA  : std_logic_vector(APB_DATA_WIDTH-1 downto 0);
  signal uart_PREADY  : std_logic;
  signal uart_PSLVERR : std_logic;

  signal uart_rx_i : std_logic;         -- Receiver input
  signal uart_tx_o : std_logic;         -- Transmitter output

  signal uart_event_o : std_logic;

begin
  ------------------------------------------------------------------------------
  -- Module Body
  ------------------------------------------------------------------------------

  -- DUT AHB4
  apb2ahb : peripheral_apb2ahb
    generic map (
      HADDR_SIZE => HADDR_SIZE,
      HDATA_SIZE => HDATA_SIZE,
      PADDR_SIZE => APB_ADDR_WIDTH,
      PDATA_SIZE => APB_DATA_WIDTH,
      SYNC_DEPTH => SYNC_DEPTH
      )
    port map (
      -- AHB Slave Interface
      HRESETn => HRESETn,
      HCLK    => HCLK,

      HSEL      => mst_uart_HSEL,
      HADDR     => mst_uart_HADDR,
      HWDATA    => mst_uart_HWDATA,
      HRDATA    => mst_uart_HRDATA,
      HWRITE    => mst_uart_HWRITE,
      HSIZE     => mst_uart_HSIZE,
      HBURST    => mst_uart_HBURST,
      HPROT     => mst_uart_HPROT,
      HTRANS    => mst_uart_HTRANS,
      HMASTLOCK => mst_uart_HMASTLOCK,
      HREADYOUT => mst_uart_HREADYOUT,
      HREADY    => mst_uart_HREADY,
      HRESP     => mst_uart_HRESP,

      -- APB Master Interface
      PRESETn => HRESETn,
      PCLK    => HCLK,

      PSEL    => uart_PSEL,
      PENABLE => uart_PENABLE,
      PPROT   => open,
      PWRITE  => uart_PWRITE,
      PSTRB   => open,
      PADDR   => uart_PADDR,
      PWDATA  => uart_PWDATA,
      PRDATA  => uart_PRDATA,
      PREADY  => uart_PREADY,
      PSLVERR => uart_PSLVERR
      );

  apb4_uart : peripheral_uart_apb4
    generic map (
      APB_ADDR_WIDTH => APB_ADDR_WIDTH,
      APB_DATA_WIDTH => APB_DATA_WIDTH
      )
    port map (
      CLK     => HCLK,
      RSTN    => HRESETn,
      PADDR   => uart_PADDR,
      PWDATA  => uart_PWDATA,
      PWRITE  => uart_PWRITE,
      PSEL    => uart_PSEL,
      PENABLE => uart_PENABLE,
      PRDATA  => uart_PRDATA,
      PREADY  => uart_PREADY,
      PSLVERR => uart_PSLVERR,

      rx_i => uart_rx_i,
      tx_o => uart_tx_o,

      event_o => uart_event_o
      );
end rtl;
