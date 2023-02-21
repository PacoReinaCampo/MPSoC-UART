-- Converted from peripheral_uart_apb4.sv
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
--              AMBA4 APB-Lite Bus Interface                                  --
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
use ieee.math_real.all;

use work.vhdl_pkg.all;
use work.peripheral_ahb3_pkg.all;

entity peripheral_uart_apb4 is
  generic (
    APB_ADDR_WIDTH : integer := 12;  --APB slaves are 4KB by default
    APB_DATA_WIDTH : integer := 32   --APB slaves are 4KB by default
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

    rx_i : in  std_logic;  -- Receiver input
    tx_o : out std_logic;  -- Transmitter output

    event_o : out std_logic  -- interrupt/event output
    );
end peripheral_uart_apb4;

architecture rtl of peripheral_uart_apb4 is
  component peripheral_uart_rx
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
  end component;

  component peripheral_uart_tx
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
  end component;

  component peripheral_uart_fifo
    generic (
      DATA_WIDTH       : integer := 32;
      BUFFER_DEPTH     : integer := 2;
      LOG_BUFFER_DEPTH : integer := 4
      );
    port (
      clk_i  : in std_logic;
      rstn_i : in std_logic;

      clr_i : in std_logic;

      elements_o : out std_logic_vector(LOG_BUFFER_DEPTH downto 0);

      data_o  : out std_logic_vector(DATA_WIDTH-1 downto 0);
      valid_o : out std_logic;
      ready_i : in  std_logic;

      valid_i : in  std_logic;
      data_i  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      ready_o : out std_logic
      );
  end component;

  component peripheral_uart_interrupt
    generic (
      TX_FIFO_DEPTH : integer := 32;
      RX_FIFO_DEPTH : integer := 32
      );
    port (
      clk_i  : in std_logic;
      rstn_i : in std_logic;

      -- registers
      IER_i : in std_logic_vector(2 downto 0);  -- interrupt enable register
      RDA_i : in std_logic;                     -- receiver data available
      CTI_i : in std_logic;                     -- character timeout indication

      -- control logic
      error_i         : in std_logic;
      rx_elements_i   : in std_logic_vector(integer(log2(real(RX_FIFO_DEPTH))) downto 0);
      tx_elements_i   : in std_logic_vector(integer(log2(real(TX_FIFO_DEPTH))) downto 0);
      trigger_level_i : in std_logic_vector(1 downto 0);

      clr_int_i : in std_logic_vector(3 downto 0);  -- one hot

      interrupt_o : out std_logic;
      IIR_o       : out std_logic_vector(3 downto 0)
      );
  end component;

  ------------------------------------------------------------------------------
  -- Constants
  ------------------------------------------------------------------------------

  -- register addresses
  constant HRBR : std_logic_vector(2 downto 0) := "000";
  constant HTHR : std_logic_vector(2 downto 0) := "000";
  constant HDLL : std_logic_vector(2 downto 0) := "000";
  constant HIER : std_logic_vector(2 downto 0) := "001";
  constant HDLM : std_logic_vector(2 downto 0) := "001";
  constant HIIR : std_logic_vector(2 downto 0) := "010";
  constant HFCR : std_logic_vector(2 downto 0) := "010";
  constant HLCR : std_logic_vector(2 downto 0) := "011";
  constant HMCR : std_logic_vector(2 downto 0) := "100";
  constant HLSR : std_logic_vector(2 downto 0) := "101";
  constant HMSR : std_logic_vector(2 downto 0) := "110";
  constant HSCR : std_logic_vector(2 downto 0) := "111";

  constant RBR : integer := 0;
  constant THR : integer := 0;
  constant DLL : integer := 0;
  constant IER : integer := 1;
  constant DLM : integer := 1;
  constant IIR : integer := 2;
  constant FCR : integer := 2;
  constant LCR : integer := 3;
  constant MCR : integer := 4;
  constant LSR : integer := 5;
  constant MSR : integer := 6;
  constant SCR : integer := 7;

  constant TX_FIFO_DEPTH : integer := 16;  -- in bytes
  constant RX_FIFO_DEPTH : integer := 16;  -- in bytes

  ------------------------------------------------------------------------------
  -- Variables
  ------------------------------------------------------------------------------

  signal register_adr    : std_logic_vector(2 downto 0);
  signal regs_n          : std_logic_matrix(9 downto 0)(7 downto 0);
  signal regs_q          : std_logic_matrix(9 downto 0)(7 downto 0);
  signal trigger_level_n : std_logic_vector(1 downto 0);
  signal trigger_level_q : std_logic_vector(1 downto 0);

  -- receive buffer register, read only
  signal rx_data      : std_logic_vector(7 downto 0);
  signal parity_error : std_logic;
  signal IIR_o        : std_logic_vector(3 downto 0);
  signal clr_int      : std_logic_vector(3 downto 0);

  -- tx flow control
  signal tx_ready : std_logic;

  -- rx flow control
  signal apb_rx_ready : std_logic;
  signal rx_valid     : std_logic;

  signal tx_fifo_clr_n, tx_fifo_clr_q : std_logic;
  signal rx_fifo_clr_n, rx_fifo_clr_q : std_logic;

  signal fifo_tx_valid : std_logic;
  signal tx_valid      : std_logic;
  signal fifo_rx_valid : std_logic;
  signal fifo_rx_ready : std_logic;
  signal rx_ready      : std_logic;

  signal fifo_tx_data : std_logic_vector(7 downto 0);
  signal fifo_rx_data : std_logic_vector(8 downto 0);

  signal tx_data     : std_logic_vector(7 downto 0);
  signal tx_elements : std_logic_vector(integer(log2(real(TX_FIFO_DEPTH))) downto 0);
  signal rx_elements : std_logic_vector(integer(log2(real(RX_FIFO_DEPTH))) downto 0);

  signal cfg_div_i : std_logic_vector(15 downto 0);

  signal data_rx_fifo_i : std_logic_vector(8 downto 0);

begin
  ------------------------------------------------------------------------------
  -- Module Body
  ------------------------------------------------------------------------------

  -- TODO: check that stop bits are really not necessary here
  peripheral_uart_rx_i : peripheral_uart_rx
    port map (
      clk_i           => CLK,
      rstn_i          => RSTN,
      rx_i            => rx_i,
      cfg_en_i        => '1',
      cfg_div_i       => cfg_div_i,
      cfg_parity_en_i => regs_q(LCR)(3),
      cfg_bits_i      => regs_q(LCR)(1 downto 0),
      busy_o          => open,
      err_o           => parity_error,
      err_clr_i       => '1',
      rx_data_o       => rx_data,
      rx_valid_o      => rx_valid,
      rx_ready_i      => rx_ready
      );

  peripheral_uart_tx_i : peripheral_uart_tx
    port map (
      clk_i           => CLK,
      rstn_i          => RSTN,
      tx_o            => tx_o,
      busy_o          => open,
      cfg_en_i        => '1',
      cfg_div_i       => cfg_div_i,
      cfg_parity_en_i => regs_q(LCR)(3),
      cfg_bits_i      => regs_q(LCR)(1 downto 0),
      cfg_stop_bits_i => regs_q(LCR)(2),

      tx_data_i  => tx_data,
      tx_valid_i => tx_valid,
      tx_ready_o => tx_ready
      );

  cfg_div_i <= regs_q(DLM+8) & regs_q(DLL+8);

  uart_rx_fifo_i : peripheral_uart_fifo
    generic map (
      DATA_WIDTH       => 9,
      BUFFER_DEPTH     => RX_FIFO_DEPTH,
      LOG_BUFFER_DEPTH => integer(log2(real(RX_FIFO_DEPTH)))
      )
    port map (
      clk_i  => CLK,
      rstn_i => RSTN,

      clr_i => rx_fifo_clr_q,

      elements_o => rx_elements,

      data_o  => fifo_rx_data,
      valid_o => fifo_rx_valid,
      ready_i => fifo_rx_ready,

      valid_i => rx_valid,
      data_i  => data_rx_fifo_i,
      ready_o => rx_ready
      );

  data_rx_fifo_i <= parity_error & rx_data;

  uart_tx_fifo_i : peripheral_uart_fifo
    generic map (
      DATA_WIDTH       => 8,
      BUFFER_DEPTH     => TX_FIFO_DEPTH,
      LOG_BUFFER_DEPTH => integer(log2(real(TX_FIFO_DEPTH)))
      )
    port map (
      clk_i  => CLK,
      rstn_i => RSTN,

      clr_i => tx_fifo_clr_q,

      elements_o => tx_elements,

      data_o  => tx_data,
      valid_o => tx_valid,
      ready_i => tx_ready,

      valid_i => fifo_tx_valid,
      data_i  => fifo_tx_data,
      -- not needed since we are getting the status via the fifo population
      ready_o => open
      );

  peripheral_uart_interrupt_i : peripheral_uart_interrupt
    generic map (
      TX_FIFO_DEPTH => TX_FIFO_DEPTH,
      RX_FIFO_DEPTH => RX_FIFO_DEPTH
      )
    port map (
      clk_i  => CLK,
      rstn_i => RSTN,

      IER_i => regs_q(IER)(2 downto 0),  -- interrupt enable register
      RDA_i => regs_n(LSR)(5),           -- receiver data available
      CTI_i => '0',                      -- character timeout indication

      error_i         => regs_n(LSR)(2),
      rx_elements_i   => rx_elements,
      tx_elements_i   => tx_elements,
      trigger_level_i => trigger_level_q,

      clr_int_i => clr_int,             -- one hot

      interrupt_o => event_o,
      IIR_o       => IIR_o
      );

  -- UART Registers

  -- register write and update logic
  processing_0 : process (register_adr)
  begin
    regs_n          <= regs_q;
    trigger_level_n <= trigger_level_q;
    fifo_tx_valid   <= '0';
    tx_fifo_clr_n   <= '0';             -- self clearing
    rx_fifo_clr_n   <= '0';             -- self clearing
    -- rx status
    regs_n(LSR)(0)  <= fifo_rx_valid;   -- fifo is empty
    -- parity error on receiving part has occured
    regs_n(LSR)(2)  <= fifo_rx_data(8);  -- parity error is detected when element is retrieved
    -- tx status register
    regs_n(LSR)(5)  <= not reduce_or(tx_elements);               -- fifo is empty
    regs_n(LSR)(6)  <= tx_ready and not reduce_or(tx_elements);  -- shift register and fifo are empty
    if (PSEL = '1' and PENABLE = '1' and PWRITE = '1') then
      case ((register_adr)) is
        when HTHR =>
          -- either THR or DLL
          -- Divisor Latch Access Bit (DLAB)
          if (regs_q(LCR)(7) = '1') then
            regs_n(DLL+8) <= PWDATA(7 downto 0);
          else
            fifo_tx_data  <= PWDATA(7 downto 0);
            fifo_tx_valid <= '1';
          end if;
        when HIER =>
          -- either IER or DLM
          -- Divisor Latch Access Bit (DLAB)
          if (regs_q(LCR)(7) = '1') then
            regs_n(DLM+8) <= PWDATA(7 downto 0);
          else
            regs_n(IER) <= PWDATA(7 downto 0);
          end if;
        when HLCR =>
          regs_n(LCR) <= PWDATA(7 downto 0);
        when HFCR =>
          -- write only register, fifo control register
          rx_fifo_clr_n   <= PWDATA(1);
          tx_fifo_clr_n   <= PWDATA(2);
          trigger_level_n <= PWDATA(7 downto 6);
        when others =>
          null;
      end case;
    end if;
  end process;

  -- register read logic
  processing_1 : process (register_adr)
  begin
    PRDATA        <= (others => '0');
    apb_rx_ready  <= '0';
    fifo_rx_ready <= '0';
    clr_int       <= (others => '0');
    if (PSEL = '1' and PENABLE = '1' and PWRITE = '0') then
      case ((register_adr)) is
        when HRBR =>
          -- either RBR or DLL
          -- Divisor Latch Access Bit (DLAB)
          if (regs_q(LCR)(7) = '1') then
            PRDATA <= (std_logic_vector(to_unsigned(0,APB_DATA_WIDTH-8)) & regs_q(DLL+8));
          else
            fifo_rx_ready <= '1';
            PRDATA        <= (std_logic_vector(to_unsigned(0,APB_DATA_WIDTH-8)) & fifo_rx_data(7 downto 0));
            clr_int       <= "1000";  -- clear Received Data Available interrupt
          end if;
        when HLSR =>
          -- Line Status Register
          PRDATA  <= (std_logic_vector(to_unsigned(0,APB_DATA_WIDTH-8)) & regs_q(LSR));
          clr_int <= "1100";            -- clear parrity interrupt error
        when HLCR =>
          -- Line Control Register
          PRDATA <= (std_logic_vector(to_unsigned(0,APB_DATA_WIDTH-8)) & regs_q(LCR));
        when HIER =>
          -- either IER or DLM
          -- Divisor Latch Access Bit (DLAB)
          if (regs_q(LCR)(7) = '1') then
            PRDATA <= (std_logic_vector(to_unsigned(0,APB_DATA_WIDTH-8)) & regs_q(DLM+8));
          else
            PRDATA <= (std_logic_vector(to_unsigned(0,APB_DATA_WIDTH-8)) & regs_q(IER));
          end if;
        when HIIR =>
          -- interrupt identification register read only
          PRDATA  <= (std_logic_vector(to_unsigned(0,APB_DATA_WIDTH-8)) & "0110" & IIR_o);
          clr_int <= "0100";  -- clear Transmitter Holding Register Empty
        when others =>
          null;
      end case;
    end if;
  end process;

  -- synchronouse part
  processing_2 : process (CLK, RSTN)
  begin
    if (RSTN = '0') then
      regs_q(IER)     <= X"00";
      regs_q(IIR)     <= X"01";
      regs_q(LCR)     <= X"00";
      regs_q(MCR)     <= X"00";
      regs_q(LSR)     <= X"60";
      regs_q(MSR)     <= X"00";
      regs_q(SCR)     <= X"00";
      regs_q(DLM+8)   <= X"00";
      regs_q(DLL+8)   <= X"00";
      trigger_level_q <= "00";
      tx_fifo_clr_q   <= '0';
      rx_fifo_clr_q   <= '0';
    elsif (rising_edge(CLK)) then
      regs_q          <= regs_n;
      trigger_level_q <= trigger_level_n;
      tx_fifo_clr_q   <= tx_fifo_clr_n;
      rx_fifo_clr_q   <= rx_fifo_clr_n;
    end if;
  end process;

  register_adr <= (PADDR(2 downto 0));
  -- APB logic: we are always ready to capture the data into our regs
  -- not supporting transfare failure
  PREADY       <= '1';
  PSLVERR      <= '0';
end rtl;