-- Converted from mpsoc_wb_uart_regs.v
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
-- *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
-- */

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mpsoc_uart_wb_pkg.all;

entity mpsoc_wb_uart_regs is
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
end mpsoc_wb_uart_regs;

architecture RTL of mpsoc_wb_uart_regs is
  component mpsoc_wb_uart_transmitter
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
      lsr_mask  : in  std_logic;        --reset of fifo
      stx_pad_o : out std_logic;
      tstate    : out std_logic_vector(2 downto 0);
      tf_count  : out std_logic_vector(UART_FIFO_COUNTER_W-1 downto 0)
      );
  end component;

  component mpsoc_wb_uart_sync_flops
    generic (
      WIDTH      : integer   := 1;
      INIT_VALUE : std_logic := '0'
      );
    port (
      rst_i           : in  std_logic;  -- reset input
      clk_i           : in  std_logic;  -- clock input
      stage1_rst_i    : in  std_logic;  -- synchronous reset for stage 1 FF
      stage1_clk_en_i : in  std_logic;  -- synchronous clock enable for stage 1 FF
      async_dat_i     : in  std_logic_vector(WIDTH-1 downto 0);  -- asynchronous data input
      sync_dat_o      : out std_logic_vector(WIDTH-1 downto 0)  -- synchronous data output
      );
  end component;

  component mpsoc_wb_uart_receiver
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
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --
  constant PRESCALER_PRESET_HARD : std_logic := '1';

  constant PRESCALER_HIGH_PRESET : std_logic_vector(7 downto 0) := X"00";
  constant PRESCALER_LOW_PRESET  : std_logic_vector(7 downto 0) := X"00";

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal enable : std_logic;

  signal srx_pad   : std_logic_vector(0 downto 0);
  signal srx_pad_o : std_logic_vector(0 downto 0);

  signal ier        : std_logic_vector(3 downto 0);
  signal iir        : std_logic_vector(3 downto 0);
  signal fcr        : std_logic_vector(1 downto 0);  -- bits 7 and 6 of fcr. Other bits are ignored
  signal mcr        : std_logic_vector(4 downto 0);
  signal lcr        : std_logic_vector(7 downto 0);
  signal msr        : std_logic_vector(7 downto 0);
  signal dl         : std_logic_vector(15 downto 0);  -- 32-bit divisor latch
  signal scratch    : std_logic_vector(7 downto 0);  -- UART scratch register
  signal start_dlc  : std_logic;        -- activate dlc on writing to UART_DL1
  signal lsr_mask_d : std_logic;        -- delay for lsr_mask condition
  signal msi_reset  : std_logic;        -- reset MSR 4 lower bits indicator
  signal dlc        : std_logic_vector(15 downto 0);  -- 32-bit divisor latch counter

  signal trigger_level : std_logic_vector(3 downto 0);  -- trigger level of the receiver FIFO
  signal rx_reset      : std_logic;
  signal tx_reset      : std_logic;

  signal dlab     : std_logic;  -- divisor latch access bit
  signal loopback : std_logic;  -- loopback bit (MCR bit 4)

  signal cts_pad_i, dsr_pad_i, ri_pad_i, dcd_pad_i : std_logic;  -- modem status bits

  signal cts, dsr, ri, dcd         : std_logic;  -- effective signals
  signal cts_c, dsr_c, ri_c, dcd_c : std_logic;  -- Complement effective signals (considering loopback)

  -- LSR bits wires and regs
  signal lsr      : std_logic_vector(7 downto 0);
  signal lsr_mask : std_logic;  -- lsr_mask

  signal lsr0, lsr1, lsr2, lsr3, lsr4, lsr5, lsr6, lsr7 : std_logic;

  signal lsr0r, lsr1r, lsr2r, lsr3r, lsr4r, lsr5r, lsr6r, lsr7r : std_logic;

  -- Interrupt signals
  signal rls_int  : std_logic;  -- receiver line status interrupt
  signal rda_int  : std_logic;  -- receiver data available interrupt
  signal ti_int   : std_logic;  -- timeout indicator interrupt
  signal thre_int : std_logic;  -- transmitter holding register empty interrupt
  signal ms_int   : std_logic;  -- modem status interrupt

  -- FIFO signals
  signal tf_push       : std_logic;
  signal rf_pop        : std_logic;
  signal rf_data_out   : std_logic_vector(UART_FIFO_REC_WIDTH-1 downto 0);
  signal rf_error_bit  : std_logic;  -- an error (parity or framing) is inside the fifo
  signal rf_overrun    : std_logic;
  signal rf_push_pulse : std_logic;
  signal rf_count      : std_logic_vector(UART_FIFO_COUNTER_W-1 downto 0);
  signal tf_count      : std_logic_vector(UART_FIFO_COUNTER_W-1 downto 0);
  signal tstate        : std_logic_vector(2 downto 0);
  signal rstate        : std_logic_vector(3 downto 0);
  signal counter_t     : std_logic_vector(9 downto 0);

  signal thre_set_en : std_logic;  -- THRE status is delayed one character time when a character is written to fifo.
  signal block_cnt   : std_logic_vector(7 downto 0);  -- While counter counts, THRE status is blocked (delayed one character cycle)
  signal block_value : std_logic_vector(7 downto 0);  -- One character length minus stop bit

  -- Transmitter Instance
  signal serial_out : std_logic;

  -- handle loopback
  signal serial_in : std_logic;

  signal lsr_mask_condition : std_logic;
  signal iir_read           : std_logic;
  signal msr_read           : std_logic;
  signal fifo_read          : std_logic;
  signal fifo_write         : std_logic;

  --  STATUS REGISTERS

  -- Modem Status Register
  signal delayed_modem_signals : std_logic_vector(3 downto 0);
  -- lsr bit0 (receiver data available)
  signal lsr0_d                : std_logic;

  -- lsr bit 1 (receiver overrun)
  signal lsr1_d : std_logic;            -- delayed

  -- lsr bit 2 (parity error)
  signal lsr2_d : std_logic;            -- delayed

  -- lsr bit 3 (framing error)
  signal lsr3_d : std_logic;            -- delayed

  -- lsr bit 4 (break indicator)
  signal lsr4_d : std_logic;            -- delayed

  -- lsr bit 5 (transmitter fifo is empty)
  signal lsr5_d : std_logic;

  -- lsr bit 6 (transmitter empty indicator)
  signal lsr6_d : std_logic;

  -- lsr bit 7 (error in fifo)
  signal lsr7_d : std_logic;

  signal rls_int_d  : std_logic;
  signal thre_int_d : std_logic;
  signal ms_int_d   : std_logic;
  signal ti_int_d   : std_logic;
  signal rda_int_d  : std_logic;

  -- rise detection signals
  signal rls_int_rise  : std_logic;
  signal thre_int_rise : std_logic;
  signal ms_int_rise   : std_logic;
  signal ti_int_rise   : std_logic;
  signal rda_int_rise  : std_logic;

  -- interrupt pending flags
  signal rls_int_pnd  : std_logic;
  signal rda_int_pnd  : std_logic;
  signal thre_int_pnd : std_logic;
  signal ms_int_pnd   : std_logic;
  signal ti_int_pnd   : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  baud_o          <= enable;            -- baud_o is actually the enable signal
  lsr(7 downto 0) <= (lsr7r & lsr6r & lsr5r & lsr4r & lsr3r & lsr2r & lsr1r & lsr0r);

  cts_pad_i <= modem_inputs(3);
  dsr_pad_i <= modem_inputs(2);
  dsr_pad_i <= modem_inputs(1);
  dcd_pad_i <= modem_inputs(0);

  cts <= not cts_pad_i;
  dsr <= not dsr_pad_i;
  ri  <= not ri_pad_i;
  dcd <= not dcd_pad_i;

  cts_c <= mcr(UART_MC_RTS)  when loopback = '1' else cts_pad_i;
  dsr_c <= mcr(UART_MC_DTR)  when loopback = '1' else dsr_pad_i;
  ri_c  <= mcr(UART_MC_OUT1) when loopback = '1' else ri_pad_i;
  dcd_c <= mcr(UART_MC_OUT2) when loopback = '1' else dcd_pad_i;

  dlab     <= lcr(UART_LC_DL);
  loopback <= mcr(4);

  -- assign modem outputs
  rts_pad_o <= mcr(UART_MC_RTS);
  dtr_pad_o <= mcr(UART_MC_DTR);

  transmitter : mpsoc_wb_uart_transmitter
    generic map (
      SIM => SIM
      )
    port map (
      clk       => clk,
      wb_rst_i  => wb_rst_i,
      lcr       => lcr,
      tf_push   => tf_push,
      wb_dat_i  => wb_dat_i,
      enable    => enable,
      stx_pad_o => serial_out,
      tstate    => tstate,
      tf_count  => tf_count,
      tx_reset  => tx_reset,
      lsr_mask  => lsr_mask
      );

  -- Synchronizing and sampling serial RX input
  i_uart_sync_flops : mpsoc_wb_uart_sync_flops
    generic map (
      WIDTH      => 1,
      INIT_VALUE => '0'
      )
    port map (
      rst_i           => wb_rst_i,
      clk_i           => clk,
      stage1_rst_i    => '0',
      stage1_clk_en_i => '1',
      async_dat_i     => srx_pad_o,
      sync_dat_o      => srx_pad
      );

  srx_pad_o(0) <= srx_pad_i;

  serial_in <= serial_out when loopback = '1' else srx_pad(0);
  stx_pad_o <= '1'        when loopback = '1' else serial_out;

  -- Receiver Instance
  receiver : mpsoc_wb_uart_receiver
    port map (
      clk           => clk,
      wb_rst_i      => wb_rst_i,
      lcr           => lcr,
      rf_pop        => rf_pop,
      srx_pad_i     => serial_in,
      enable        => enable,
      counter_t     => counter_t,
      rf_count      => rf_count,
      rf_data_out   => rf_data_out,
      rf_error_bit  => rf_error_bit,
      rf_overrun    => rf_overrun,
      rx_reset      => rx_reset,
      lsr_mask      => lsr_mask,
      rstate        => rstate,
      rf_push_pulse => rf_push_pulse
      );

  -- Asynchronous reading here because the outputs are sampled in uart_wb.v file 
  processing_0 : process (dl, dlab, ier, iir, scratch, lcr, lsr, msr, rf_data_out, wb_addr_i, wb_re_i)
  begin
    -- asynchrounous reading
    case ((wb_addr_i)) is
      when UART_REG_RB =>
        if (dlab = '1') then
          wb_dat_o <= dl(7 downto 0);
        else
          wb_dat_o <= rf_data_out(10 downto 3);
        end if;
      when UART_REG_IE =>
        if (dlab = '1') then
          wb_dat_o <= dl(15 downto 8);
        else
          wb_dat_o <= ("0000" & ier);
        end if;
      when UART_REG_II =>
        wb_dat_o <= ("1100" & iir);
      when UART_REG_LC =>
        wb_dat_o <= lcr;
      when UART_REG_LS =>
        wb_dat_o <= lsr;
      when UART_REG_MS =>
        wb_dat_o <= msr;
      when UART_REG_SR =>
        wb_dat_o <= scratch;
      when others =>
        wb_dat_o <= (others => '0');
    end case;
  end process;

  -- rf_pop signal handling
  processing_1 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      rf_pop <= '0';
    elsif (rising_edge(clk)) then
      if (rf_pop = '1') then  -- restore the signal to 0 after one clock cycle
        rf_pop <= '0';
      elsif (wb_re_i = '1' and wb_addr_i = UART_REG_RB and dlab = '0') then
        rf_pop <= '1';                  -- advance read pointer
      end if;
    end if;
  end process;

  lsr_mask_condition <= (wb_re_i and to_stdlogic(wb_addr_i = UART_REG_LS) and not dlab);
  iir_read           <= (wb_re_i and to_stdlogic(wb_addr_i = UART_REG_II) and not dlab);
  msr_read           <= (wb_re_i and to_stdlogic(wb_addr_i = UART_REG_MS) and not dlab);
  fifo_read          <= (wb_re_i and to_stdlogic(wb_addr_i = UART_REG_RB) and not dlab);
  fifo_write         <= (wb_we_i and to_stdlogic(wb_addr_i = UART_REG_TR) and not dlab);

  -- lsr_mask_d delayed signal handling
  processing_2 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      lsr_mask_d <= '0';
    elsif (rising_edge(clk)) then
      -- reset bits in the Line Status Register
      lsr_mask_d <= lsr_mask_condition;
    end if;
  end process;

  -- lsr_mask is rise detected
  lsr_mask <= lsr_mask_condition and not lsr_mask_d;

  -- msi_reset signal handling
  processing_3 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      msi_reset <= '1';
    elsif (rising_edge(clk)) then
      if (msi_reset = '1') then
        msi_reset <= '0';
      elsif (msr_read = '1') then
        msi_reset <= '1';               -- reset bits in Modem Status Register
      end if;
    end if;
  end process;

  -- WRITES AND RESETS

  -- Line Control Register
  processing_4 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      lcr <= "00000011";                -- 8n1 setting
    elsif (rising_edge(clk)) then
      if (wb_we_i = '1' and wb_addr_i = UART_REG_LC) then
        lcr <= wb_dat_i;
      end if;
    end if;
  end process;

  -- Interrupt Enable Register or UART_DL2
  processing_5 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      ier <= "0000";                    -- no interrupts after reset
      if (PRESCALER_PRESET_HARD = '1') then
        dl(15 downto 8) <= PRESCALER_HIGH_PRESET;
      elsif (PRESCALER_PRESET_HARD = '0') then
        dl(15 downto 8) <= (others => '0');
      end if;
    elsif (rising_edge(clk)) then
      if (wb_we_i = '1' and wb_addr_i = UART_REG_IE) then
        if (dlab = '1') then
          if (PRESCALER_PRESET_HARD = '0') then
            dl(15 downto 8) <= wb_dat_i;
          end if;
        else                            -- ier uses only 4 lsb
          ier <= wb_dat_i(3 downto 0);
        end if;
      end if;
    end if;
  end process;

  -- FIFO Control Register and rx_reset, tx_reset signals
  processing_6 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      fcr      <= "11";
      rx_reset <= '0';
      tx_reset <= '0';
    elsif (rising_edge(clk)) then
      if (wb_we_i = '1' and wb_addr_i = UART_REG_FC) then
        fcr      <= wb_dat_i(7 downto 6);
        rx_reset <= wb_dat_i(1);
        tx_reset <= wb_dat_i(2);
      else
        rx_reset <= '0';
        tx_reset <= '0';
      end if;
    end if;
  end process;

  -- Modem Control Register
  processing_7 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      mcr <= (others => '0');
    elsif (rising_edge(clk)) then
      if (wb_we_i = '1' and wb_addr_i = UART_REG_MC) then
        mcr <= wb_dat_i(4 downto 0);
      end if;
    end if;
  end process;

  -- Scratch register
  -- Line Control Register
  processing_8 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      scratch <= (others => '0');       -- 8n1 setting
    elsif (rising_edge(clk)) then
      if (wb_we_i = '1' and wb_addr_i = UART_REG_SR) then
        scratch <= wb_dat_i;
      end if;
    end if;
  end process;

  -- TX_FIFO or UART_DL1
  processing_9 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      if (PRESCALER_PRESET_HARD = '1') then
        dl(7 downto 0) <= PRESCALER_LOW_PRESET;
      elsif (PRESCALER_PRESET_HARD = '0') then
        dl(7 downto 0) <= (others => '0');
      end if;
      tf_push   <= '0';
      start_dlc <= '0';
    elsif (rising_edge(clk)) then
      if (wb_we_i = '1' and wb_addr_i = UART_REG_TR) then
        if (dlab = '1') then
          if (PRESCALER_PRESET_HARD = '0') then
            dl(7 downto 0) <= wb_dat_i;
          end if;
          start_dlc <= '1';             -- enable DL counter
          tf_push   <= '0';
        else
          tf_push   <= '1';
          start_dlc <= '0';
        end if;
      else                              -- else: !if(dlab)
        start_dlc <= '0';
        tf_push   <= '0';
      end if;
    end if;
  end process;

  -- Receiver FIFO trigger level selection logic (asynchronous mux)
  processing_10 : process (fcr)
  begin
    case (fcr(1 downto 0)) is
      when "00" =>
        trigger_level <= std_logic_vector(to_unsigned(1, 4));
      when "01" =>
        trigger_level <= std_logic_vector(to_unsigned(4, 4));
      when "10" =>
        trigger_level <= std_logic_vector(to_unsigned(8, 4));
      when "11" =>
        trigger_level <= std_logic_vector(to_unsigned(14, 4));
      when others =>
        null;
    end case;
  end process;

  processing_11 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      msr                               <= (others => '0');
      delayed_modem_signals(3 downto 0) <= (others => '0');
    elsif (rising_edge(clk)) then
      if (msi_reset = '1') then
        msr(UART_MS_DDCD downto UART_MS_DCTS) <= (others => '0');
      else
        msr(UART_MS_DDCD downto UART_MS_DCTS) <= msr(UART_MS_DDCD downto UART_MS_DCTS) or ((dcd & ri & dsr & cts) xor delayed_modem_signals(3 downto 0));
      end if;
      msr(UART_MS_CDCD downto UART_MS_CCTS) <= (dcd_c & ri_c & dsr_c & cts_c);
      delayed_modem_signals(3 downto 0)     <= (dcd & ri & dsr & cts);
    end if;
  end process;

  -- Line Status Register

  -- activation conditions
  lsr0 <= to_stdlogic(unsigned(tf_count) = to_unsigned(0, UART_FIFO_COUNTER_W)) and rf_push_pulse;  -- data in receiver fifo available set condition
  lsr1 <= rf_overrun;                   -- Receiver overrun error

  lsr2 <= rf_data_out(1);               -- parity error bit
  lsr3 <= rf_data_out(0);               -- framing error bit
  lsr4 <= rf_data_out(2);               -- break error in the character

  lsr5 <= to_stdlogic(unsigned(tf_count) = to_unsigned(0, UART_FIFO_COUNTER_W)) and thre_set_en;  -- transmitter fifo is empty
  lsr6 <= to_stdlogic(unsigned(tf_count) = to_unsigned(0, UART_FIFO_COUNTER_W)) and thre_set_en and to_stdlogic(tstate = "000");  -- transmitter empty
  lsr7 <= rf_error_bit or rf_overrun;

  processing_12 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      lsr0_d <= '0';
    elsif (rising_edge(clk)) then
      lsr0_d <= lsr0;
    end if;
  end process;

  processing_13 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      lsr0r <= '0';
    elsif (rising_edge(clk)) then
      -- deassert condition
      if ((rf_count = std_logic_vector(to_unsigned(1, UART_FIFO_COUNTER_W)) and rf_pop = '1' and rf_push_pulse = '0') or rx_reset = '1') then
        lsr0r <= '0';
      else
        lsr0r <= lsr0r or (lsr0 and not lsr0_d);  -- set on rise of lsr0 and keep asserted until deasserted
      end if;
    end if;
  end process;

  processing_14 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      lsr1_d <= '0';
    elsif (rising_edge(clk)) then
      lsr1_d <= lsr1;
    end if;
  end process;

  processing_15 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      lsr1r <= '0';
    elsif (rising_edge(clk)) then
      if (lsr_mask = '1') then
        lsr1r <= '0';
      else
        lsr1r <= lsr1r or (lsr1 and not lsr1_d);  -- set on rise
      end if;
    end if;
  end process;

  processing_16 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      lsr2_d <= '0';
    elsif (rising_edge(clk)) then
      lsr2_d <= lsr2;
    end if;
  end process;

  processing_17 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      lsr2r <= '0';
    elsif (rising_edge(clk)) then
      if (lsr_mask = '1') then
        lsr2r <= '0';
      else
        lsr2r <= lsr2r or (lsr1 and not lsr2_d);  -- set on rise
      end if;
    end if;
  end process;

  processing_18 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      lsr3_d <= '0';
    elsif (rising_edge(clk)) then
      lsr3_d <= lsr3;
    end if;
  end process;

  processing_19 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      lsr3r <= '0';
    elsif (rising_edge(clk)) then
      if (lsr_mask = '1') then
        lsr3r <= '0';
      else
        lsr3r <= lsr3r or (lsr3 and not lsr3_d);  -- set on rise
      end if;
    end if;
  end process;
  processing_20 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      lsr4_d <= '0';
    elsif (rising_edge(clk)) then
      lsr4_d <= lsr4;
    end if;
  end process;

  processing_21 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      lsr4r <= '0';
    elsif (rising_edge(clk)) then
      if (lsr_mask = '1') then
        lsr4r <= '0';
      else
        lsr4r <= lsr4r or (lsr4 and not lsr4_d);
      end if;
    end if;
  end process;

  processing_22 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      lsr5_d <= '1';
    elsif (rising_edge(clk)) then
      lsr5_d <= lsr5;
    end if;
  end process;

  processing_23 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      lsr5r <= '1';
    elsif (rising_edge(clk)) then
      if (fifo_write = '1') then
        lsr5r <= '0';
      else
        lsr5r <= lsr5r or (lsr5 and not lsr5_d);
      end if;
    end if;
  end process;

  processing_24 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      lsr6_d <= '1';
    elsif (rising_edge(clk)) then
      lsr6_d <= lsr6;
    end if;
  end process;

  processing_25 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      lsr6r <= '1';
    elsif (rising_edge(clk)) then
      if (fifo_write = '1') then
        lsr6r <= '0';
      else
        lsr6r <= lsr6r or (lsr6 and not lsr6_d);
      end if;
    end if;
  end process;

  processing_26 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      lsr7_d <= '0';
    elsif (rising_edge(clk)) then
      lsr7_d <= lsr7;
    end if;
  end process;

  processing_27 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      lsr7r <= '0';
    elsif (rising_edge(clk)) then
      if (lsr_mask = '1') then
        lsr7r <= '0';
      else
        lsr7r <= lsr7r or (lsr7 and not lsr7_d);
      end if;
    end if;
  end process;

  -- Frequency divider
  processing_28 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      dlc <= (others => '0');
    elsif (rising_edge(clk)) then
      if (start_dlc = '1' or reduce_or(dlc) = '0') then
        dlc <= std_logic_vector(unsigned(dl)-X"0001");  -- preset counter
      else                                              -- decrement counter
        dlc <= std_logic_vector(unsigned(dlc)-X"0001");
      end if;
    end if;
  end process;

  -- Enable signal generation logic
  processing_29 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      enable <= '0';
    elsif (rising_edge(clk)) then
      if (reduce_or(dl) = '1' and reduce_or(dlc) = '0') then  -- dl>0 & dlc==0
        enable <= '1';
      else
        enable <= '0';
      end if;
    end if;
  end process;

  -- Delaying THRE status for one character cycle after a character is written to an empty fifo.
  processing_30 : process (lcr)
  begin
    case ((lcr(3 downto 0))) is
      when "0000" =>
        -- 6 bits
        block_value <= std_logic_vector(to_unsigned(95, 8));
      when "0100" =>
        -- 6.5 bits
        block_value <= std_logic_vector(to_unsigned(103, 8));
      when "0001" =>
      when "1000" =>
        -- 7 bits
        block_value <= std_logic_vector(to_unsigned(111, 8));
      when "1100" =>
        -- 7.5 bits
        block_value <= std_logic_vector(to_unsigned(119, 8));
      when "0010" =>
      when "0101" =>
      when "1001" =>
        -- 8 bits
        block_value <= std_logic_vector(to_unsigned(127, 8));
      when "0011" =>
      when "0110" =>
      when "1010" =>
      when "1101" =>
        -- 9 bits
        block_value <= std_logic_vector(to_unsigned(143, 8));
      when "0111" =>
      when "1011" =>
      when "1110" =>
        -- 10 bits
        block_value <= std_logic_vector(to_unsigned(159, 8));
      when "1111" =>
        -- 11 bits
        block_value <= std_logic_vector(to_unsigned(175, 8));
      when others =>
        null;
    end case;
  end process;

  -- Counting time of one character minus stop bit
  processing_31 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      block_cnt <= X"00";
    elsif (rising_edge(clk)) then
      if (lsr5r = '1' and fifo_write = '1') then  -- THRE bit set & write to fifo occured
        if (SIM = 1) then
          block_cnt <= X"01";
        else
          block_cnt <= block_value;
        end if;
      elsif (enable = '1' and block_cnt /= X"00") then  -- only work on enable times
        block_cnt <= std_logic_vector(unsigned(block_cnt)-X"01");  -- decrement break counter
      end if;
    end if;
  end process;
  -- always of break condition detection

  -- Generating THRE status enable signal
  thre_set_en <= not reduce_or(block_cnt);

  --  INTERRUPT LOGIC
  rls_int  <= ier(UART_IE_RLS) and (lsr(UART_LS_OE) or lsr(UART_LS_PE) or lsr(UART_LS_FE) or lsr(UART_LS_BI));
  rda_int  <= ier(UART_IE_RDA) and to_stdlogic(rf_count >= '0' & trigger_level);
  thre_int <= ier(UART_IE_THRE) and lsr(UART_LS_TFE);
  ms_int   <= ier(UART_IE_MS) and (reduce_or(msr(3 downto 0)));
  ti_int   <= ier(UART_IE_RDA) and to_stdlogic(counter_t = "0000000000") and reduce_or(rf_count);

  -- delay lines
  processing_32 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      rls_int_d <= '0';
    elsif (rising_edge(clk)) then
      rls_int_d <= rls_int;
    end if;
  end process;

  processing_33 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      rda_int_d <= '0';
    elsif (rising_edge(clk)) then
      rda_int_d <= rda_int;
    end if;
  end process;

  processing_34 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      thre_int_d <= '0';
    elsif (rising_edge(clk)) then
      thre_int_d <= thre_int;
    end if;
  end process;

  processing_35 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      ms_int_d <= '0';
    elsif (rising_edge(clk)) then
      ms_int_d <= ms_int;
    end if;
  end process;

  processing_36 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      ti_int_d <= '0';
    elsif (rising_edge(clk)) then
      ti_int_d <= ti_int;
    end if;
  end process;

  rda_int_rise  <= rda_int and not rda_int_d;
  rls_int_rise  <= rls_int and not rls_int_d;
  thre_int_rise <= thre_int and not thre_int_d;
  ms_int_rise   <= ms_int and not ms_int_d;
  ti_int_rise   <= ti_int and not ti_int_d;

  -- interrupt pending flags assignments
  processing_37 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      rls_int_pnd <= '0';
    elsif (rising_edge(clk)) then
      if (lsr_mask = '1') then
        rls_int_pnd <= '0';             -- reset condition
      elsif (rls_int_rise = '1') then
        rls_int_pnd <= '1';             -- latch condition
      else
        rls_int_pnd <= rls_int_pnd and ier(UART_IE_RLS);  -- default operation: remove if masked
      end if;
    end if;
  end process;

  processing_38 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      rda_int_pnd <= '0';
    elsif (rising_edge(clk)) then
      if ((rf_count = ('0' & trigger_level)) and fifo_read = '1') then
        rda_int_pnd <= '0';             -- reset condition
      elsif (rda_int_rise = '1') then
        rda_int_pnd <= '1';             -- latch condition
      else
        rda_int_pnd <= rda_int_pnd and ier(UART_IE_RDA);  -- default operation: remove if masked
      end if;
    end if;
  end process;

  processing_39 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      thre_int_pnd <= '0';
    elsif (rising_edge(clk)) then
      if (iir_read = '1' and iir(UART_II_IP) = '0' and iir(3 downto 1) = UART_II_THRE) then
        thre_int_pnd <= fifo_write or '0';
      elsif (thre_int_rise = '1') then
        thre_int_pnd <= '1';
      else
        thre_int_pnd <= thre_int_pnd and ier(UART_IE_THRE);
      end if;
    end if;
  end process;

  processing_40 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      ms_int_pnd <= '0';
    elsif (rising_edge(clk)) then
      if (msr_read = '1') then
        ms_int_pnd <= '0';
      elsif (ms_int_rise = '1') then
        ms_int_pnd <= '1';
      else
        ms_int_pnd <= ms_int_pnd and ier(UART_IE_MS);
      end if;
    end if;
  end process;

  processing_41 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      ti_int_pnd <= '0';
    elsif (rising_edge(clk)) then
      if (fifo_read = '1') then
        ti_int_pnd <= '0';
      elsif (ti_int_rise = '1') then
        ti_int_pnd <= '1';
      else
        ti_int_pnd <= ti_int_pnd and ier(UART_IE_RDA);
      end if;
    end if;
  end process;
  -- end of pending flags

  -- INT_O logic
  processing_42 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      int_o <= '0';
    elsif (rising_edge(clk)) then
      if (rls_int_pnd = '1') then
        int_o <= not lsr_mask;
      elsif (rda_int_pnd = '1') then
        int_o <= '1';
      elsif (ti_int_pnd = '1') then
        int_o <= not fifo_read;
      elsif (thre_int_pnd = '1') then
        int_o <= not (fifo_write and iir_read);
      elsif (ms_int_pnd = '1') then     -- if no interrupt are pending
        int_o <= not msr_read;
      else
        int_o <= '0';                   -- if no interrupt are pending
      end if;
    end if;
  end process;

  -- Interrupt Identification register
  processing_43 : process (clk, wb_rst_i)
  begin
    if (wb_rst_i = '1') then
      iir <= X"1";
    elsif (rising_edge(clk)) then
      if (rls_int_pnd = '1') then       -- interrupt is pending
        iir(3 downto 1) <= UART_II_RLS;  -- set identification register to correct value
        iir(UART_II_IP) <= '0';  -- and clear the IIR bit 0 (interrupt pending)
      -- the sequence of conditions determines priority of interrupt identification
      elsif (rda_int = '1') then
        iir(3 downto 1) <= UART_II_RDA;
        iir(UART_II_IP) <= '0';
      elsif (ti_int_pnd = '1') then
        iir(3 downto 1) <= UART_II_TI;
        iir(UART_II_IP) <= '0';
      elsif (thre_int_pnd = '1') then
        iir(3 downto 1) <= UART_II_THRE;
        iir(UART_II_IP) <= '0';
      elsif (ms_int_pnd = '1') then
        iir(3 downto 1) <= UART_II_MS;
        iir(UART_II_IP) <= '0';
      else                              -- no interrupt is pending
        iir(3 downto 1) <= (others => '0');
        iir(UART_II_IP) <= '1';
      end if;
    end if;
  end process;
end RTL;
