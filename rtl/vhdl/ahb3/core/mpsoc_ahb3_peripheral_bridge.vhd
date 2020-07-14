-- Converted from verilog/mpsoc_gpio/mpsoc_ahb3_peripheral_bridge.sv
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
--              General Purpose Input Output Bridge                           //
--              AMBA3 AHB-Lite Bus Interface                                  //
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

entity mpsoc_ahb3_peripheral_bridge is
  generic (
    HADDR_SIZE : integer := 32;
    HDATA_SIZE : integer := 32;
    PADDR_SIZE : integer := 10;
    PDATA_SIZE : integer := 8;
    SYNC_DEPTH : integer := 3
  );
  port (
    --AHB Slave Interface
    HRESETn       : in  std_logic;
    HCLK          : in  std_logic;
    HSEL          : in  std_logic;
    HADDR         : in  std_logic_vector(HADDR_SIZE-1 downto 0);
    HWDATA        : in  std_logic_vector(HDATA_SIZE-1 downto 0);
    HRDATA        : out std_logic_vector(HDATA_SIZE-1 downto 0);
    HWRITE        : in  std_logic;
    HSIZE         : in  std_logic_vector(2 downto 0);
    HBURST        : in  std_logic_vector(2 downto 0);
    HPROT         : in  std_logic_vector(3 downto 0);
    HTRANS        : in  std_logic_vector(1 downto 0);
    HMASTLOCK     : in  std_logic;
    HREADYOUT     : out std_logic;
    HREADY        : in  std_logic;
    HRESP         : out std_logic;

    --APB Master Interface
    PRESETn       : in  std_logic;
    PCLK          : in  std_logic;
    PSEL          : out std_logic;
    PENABLE       : out std_logic;
    PPROT         : out std_logic_vector(2 downto 0);
    PWRITE        : out std_logic;
    PSTRB         : out std_logic;
    PADDR         : out std_logic_vector(PADDR_SIZE-1 downto 0);
    PWDATA        : out std_logic_vector(PDATA_SIZE-1 downto 0);
    PRDATA        : in  std_logic_vector(PDATA_SIZE-1 downto 0);
    PREADY        : in  std_logic;
    PSLVERR       : in  std_logic
  );
end mpsoc_ahb3_peripheral_bridge;

architecture RTL of mpsoc_ahb3_peripheral_bridge is
  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --
  constant ST_AHB_IDLE     : std_logic_vector(1 downto 0) := "00";
  constant ST_AHB_TRANSFER : std_logic_vector(1 downto 0) := "01";
  constant ST_AHB_ERROR    : std_logic_vector(1 downto 0) := "10";

  constant ST_APB_IDLE     : std_logic_vector(1 downto 0) := "00";
  constant ST_APB_SETUP    : std_logic_vector(1 downto 0) := "01";
  constant ST_APB_TRANSFER : std_logic_vector(1 downto 0) := "10";

  --PPROT
  constant PPROT_NORMAL      : std_logic_vector(2 downto 0) := "000";
  constant PPROT_PRIVILEGED  : std_logic_vector(2 downto 0) := "001";
  constant PPROT_SECURE      : std_logic_vector(2 downto 0) := "000";
  constant PPROT_NONSECURE   : std_logic_vector(2 downto 0) := "010";
  constant PPROT_DATA        : std_logic_vector(2 downto 0) := "000";
  constant PPROT_INSTRUCTION : std_logic_vector(2 downto 0) := "100";

  --SYNC_DEPTH
  constant SYNC_DEPTH_MIN : integer := 3;
  constant SYNC_DEPTH_CHK : integer := SYNC_DEPTH;

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  signal ahb_treq      : std_logic;  --transfer request from AHB Statemachine
  signal treq_toggle   : std_logic;    --toggle-signal-version
  signal treq_sync     : std_logic_vector(SYNC_DEPTH_CHK-1 downto 0);  --synchronized transfer request
  signal apb_treq_strb : std_logic;  --transfer request strobe to APB Statemachine

  signal apb_tack      : std_logic;  --transfer acknowledge from APB Statemachine
  signal tack_toggle   : std_logic;  --toggle-signal-version
  signal tack_sync     : std_logic_vector(SYNC_DEPTH_CHK-1 downto 0);  --synchronized transfer acknowledge
  signal ahb_tack_strb : std_logic;  --transfer acknowledge strobe to AHB Statemachine

  --store AHB data locally (pipelined bus)
  signal ahb_haddr  : std_logic_vector(HADDR_SIZE-1 downto 0);
  signal ahb_hwdata : std_logic_vector(HDATA_SIZE-1 downto 0);
  signal ahb_hwrite : std_logic;
  signal ahb_hsize  : std_logic_vector(2 downto 0);
  signal ahb_hprot  : std_logic_vector(3 downto 0);

  signal latch_ahb_hwdata : std_logic;

  --store APB data locally
  signal apb_prdata  : std_logic_vector(HDATA_SIZE-1 downto 0);
  signal apb_pslverr : std_logic;

  --State machines
  signal ahb_fsm : std_logic_vector(1 downto 0);
  signal apb_fsm : std_logic_vector(1 downto 0);

  --number of transfer cycles (AMBA-beats) on APB interface
  signal apb_beat_cnt : std_logic_vector(6 downto 0);

  --running offset in HWDATA
  signal apb_beat_data_offset : std_logic_vector(9 downto 0);

  signal SPADDR : std_logic_vector(PADDR_SIZE-1 downto 0);

  --////////////////////////////////////////////////////////////////
  --
  -- Tasks
  --

  --////////////////////////////////////////////////////////////////
  --
  -- Functions
  --
  function apb_beats (
    hsize : std_logic_vector(2 downto 0)
  ) return std_logic_vector is
    variable apb_beats_return : std_logic_vector(6 downto 0);
  begin
    case (hsize) is
      when HSIZE_B1024 =>
        apb_beats_return := std_logic_vector(to_unsigned(1023/PDATA_SIZE, 7));
      when HSIZE_B512 =>
        apb_beats_return := std_logic_vector(to_unsigned(0511/PDATA_SIZE, 7));
      when HSIZE_B256 =>
        apb_beats_return := std_logic_vector(to_unsigned(0255/PDATA_SIZE, 7));
      when HSIZE_B128 =>
        apb_beats_return := std_logic_vector(to_unsigned(0127/PDATA_SIZE, 7));
      when HSIZE_DWORD =>
        apb_beats_return := std_logic_vector(to_unsigned(0063/PDATA_SIZE, 7));
      when HSIZE_WORD =>
        apb_beats_return := std_logic_vector(to_unsigned(0031/PDATA_SIZE, 7));
      when HSIZE_HWORD =>
        apb_beats_return := std_logic_vector(to_unsigned(0015/PDATA_SIZE, 7));
      when others =>
        apb_beats_return := std_logic_vector(to_unsigned(0007/PDATA_SIZE, 7));
    end case;
    return apb_beats_return;
  end apb_beats;  --apb_beats

  function address_mask (
    data_size : integer
  ) return std_logic_vector is
    variable address_mask_return : std_logic_vector (6 downto 0);
  begin
    --Which bits in HADDR should be taken into account?
    case ((data_size)) is
      when 1024 =>
        address_mask_return := "1111111";
      when 0512 =>
        address_mask_return := "0111111";
      when 0256 =>
        address_mask_return := "0011111";
      when 0128 =>
        address_mask_return := "0001111";
      when 0064 =>
        address_mask_return := "0000111";
      when 0032 =>
        address_mask_return := "0000011";
      when 0016 =>
        address_mask_return := "0000001";
      when others =>
        address_mask_return := "0000000";
    end case;
    return address_mask_return;
  end address_mask;  --address_mask

  function data_offset (
    haddr : std_logic_vector(HADDR_SIZE-1 downto 0)
  ) return std_logic_vector is
    variable haddr_masked       : std_logic_vector(6 downto 0);
    variable data_offset_return : std_logic_vector (9 downto 0);
  begin
    --Generate masked address
    haddr_masked := haddr and address_mask(HDATA_SIZE);

    --calculate bit-offset
    data_offset_return := std_logic_vector(to_unsigned(8, 3)*unsigned(haddr_masked));
    return data_offset_return;
  end data_offset;  --data_offset

  function pstrbf (
    hsize : std_logic_vector(2 downto 0);
    paddr : std_logic_vector(PADDR_SIZE-1 downto 0)
  ) return std_logic is
    variable full_pstrb   : std_logic_vector(127 downto 0);
    variable paddr_masked : std_logic_vector(6 downto 0);
    variable pstrb_return : std_logic_vector (PDATA_SIZE/8-1 downto 0);
  begin
    --get number of active lanes for a 1024bit databus (max width) for this HSIZE
    case (hsize) is
      when HSIZE_B1024 =>
        full_pstrb := X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF";
      when HSIZE_B512 =>
        full_pstrb := X"0000000000000000FFFFFFFFFFFFFFFF";
      when HSIZE_B256 =>
        full_pstrb := X"000000000000000000000000FFFFFFFF";
      when HSIZE_B128 =>
        full_pstrb := X"0000000000000000000000000000FFFF";
      when HSIZE_DWORD =>
        full_pstrb := X"000000000000000000000000000000FF";
      when HSIZE_WORD =>
        full_pstrb := X"0000000000000000000000000000000F";
      when HSIZE_HWORD =>
        full_pstrb := X"00000000000000000000000000000003";
      when others =>
        full_pstrb := X"00000000000000000000000000000001";
    end case;
    --generate masked address
    paddr_masked := paddr and address_mask(PDATA_SIZE);

    --create PSTRB
    pstrb_return := std_logic_vector(unsigned(full_pstrb(PDATA_SIZE/8-1 downto 0)) sll to_integer(unsigned(paddr_masked)));
    return pstrb_return(0);
  end pstrbf;  --pstrbf

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --

  --AHB Statemachine
  processing_0 : process (HCLK, HRESETn)
  begin
    if (HRESETn = '0') then
      ahb_fsm <= ST_AHB_IDLE;

      HREADYOUT <= '1';
      HRESP     <= HRESP_OKAY;

      ahb_treq   <= '0';
      ahb_haddr  <= (others => '0');
      ahb_hwrite <= '0';
      ahb_hprot  <= (others => '0');
      ahb_hsize  <= (others => '0');
    elsif (rising_edge(HCLK)) then
      ahb_treq <= '0';                  --1 cycle strobe signal

      case (ahb_fsm) is
        when ST_AHB_IDLE =>
          --store basic parameters
          ahb_haddr  <= HADDR;
          ahb_hwrite <= HWRITE;
          ahb_hprot  <= HPROT;
          ahb_hsize  <= HSIZE;

          if (HSEL = '1' and HREADY = '1') then
            --This (slave) is selected ... what kind of transfer is this?
            case (HTRANS) is
              when HTRANS_IDLE =>
                ahb_fsm   <= ST_AHB_IDLE;
                HREADYOUT <= '1';
                HRESP     <= HRESP_OKAY;
              when HTRANS_BUSY =>
                ahb_fsm   <= ST_AHB_IDLE;
                HREADYOUT <= '1';
                HRESP     <= HRESP_OKAY;
              when HTRANS_NONSEQ =>
                ahb_fsm   <= ST_AHB_TRANSFER;
                HREADYOUT <= '0';  --hold off master
                HRESP     <= HRESP_OKAY;
                ahb_treq  <= '1';  --request data transfer
              when HTRANS_SEQ =>
                ahb_fsm   <= ST_AHB_TRANSFER;
                HREADYOUT <= '0';  --hold off master
                HRESP     <= HRESP_OKAY;
                ahb_treq  <= '1';  --request data transfer
              when others =>
                null;
            end case;  --HTRANS
          else
            ahb_fsm   <= ST_AHB_IDLE;
            HREADYOUT <= '1';
            HRESP     <= HRESP_OKAY;
          end if;
        when ST_AHB_TRANSFER =>
          if (ahb_tack_strb = '1') then
            --  * APB acknowledged transfer. Current transfer done
            --  * Check AHB bus to determine if another transfer is pending

            --assign read data
            HRDATA <= apb_prdata;

            --indicate transfer done. Normally HREADYOUT = '1', HRESP=OKAY
            --HRESP=ERROR requires 2 cycles
            if (apb_pslverr = '1') then
              HREADYOUT <= '0';
              HRESP     <= HRESP_ERROR;
              ahb_fsm   <= ST_AHB_ERROR;
            else
              HREADYOUT <= '1';
              HRESP     <= HRESP_OKAY;
              ahb_fsm   <= ST_AHB_IDLE;
            end if;
          else
            HREADYOUT <= '0';  --transfer still in progress
          end if;
        when ST_AHB_ERROR =>
          --2nd cycle of error response
          ahb_fsm   <= ST_AHB_IDLE;
          HREADYOUT <= '1';
        when others =>
          null;
      end case;  --ahb_fsm
    end if;
  end process;

  processing_1 : process (HCLK)
  begin
    if (rising_edge(HCLK)) then
      latch_ahb_hwdata <= HSEL and HREADY and HWRITE and (to_stdlogic(HTRANS = HTRANS_NONSEQ) or to_stdlogic(HTRANS = HTRANS_SEQ));
    end if;
  end process;

  processing_2 : process (HCLK)
  begin
    if (rising_edge(HCLK)) then
      if (latch_ahb_hwdata = '1') then
        ahb_hwdata <= HWDATA;
      end if;
    end if;
  end process;

  --Clock domain crossing ...

  --AHB -> APB
  processing_3 : process (HCLK, HRESETn)
  begin
    if (HRESETn = '0') then
      treq_toggle <= '0';
    elsif (rising_edge(HCLK)) then
      if (ahb_treq = '1') then
        treq_toggle <= not treq_toggle;
      end if;
    end if;
  end process;

  processing_4 : process (PCLK, PRESETn)
  begin
    if (PRESETn = '0') then
      treq_sync <= (others => '0');
    elsif (rising_edge(PCLK)) then
      treq_sync <= (treq_sync(SYNC_DEPTH-2 downto 0) & treq_toggle);
    end if;
  end process;

  apb_treq_strb <= treq_sync(SYNC_DEPTH-1) xor treq_sync(SYNC_DEPTH-2);

  --APB -> AHB
  processing_5 : process (PCLK, PRESETn)
  begin
    if (PRESETn = '0') then
      tack_toggle <= '0';
    elsif (rising_edge(PCLK)) then
      if (apb_tack = '1') then
        tack_toggle <= not tack_toggle;
      end if;
    end if;
  end process;

  processing_6 : process (HCLK, HRESETn)
  begin
    if (HRESETn = '0') then
      tack_sync <= (others => '0');
    elsif (rising_edge(HCLK)) then
      tack_sync <= (tack_sync(SYNC_DEPTH-2 downto 0) & tack_toggle);
    end if;
  end process;

  ahb_tack_strb <= tack_sync(SYNC_DEPTH-1) xor tack_sync(SYNC_DEPTH-2);

  --APB Statemachine
  processing_7 : process (PCLK, PRESETn)
  begin
    if (PRESETn = '0') then
      apb_fsm  <= ST_APB_IDLE;
      apb_tack <= '0';

      PSEL    <= '0';
      PPROT   <= (others => '0');
      PADDR   <= (others => '0');
      PWRITE  <= '0';
      PENABLE <= '0';
      PWDATA  <= (others => '0');
      PSTRB   <= '0';
    elsif (rising_edge(PCLK)) then
      apb_tack <= '0';

      case (apb_fsm) is
        when ST_APB_IDLE =>
          if (apb_treq_strb = '1') then
            apb_fsm <= ST_APB_SETUP;

            PSEL    <= '1';
            PENABLE <= '0';
            if ((ahb_hprot and HPROT_DATA) = "1111") then
              PPROT <= PPROT_DATA;
            elsif ((ahb_hprot and HPROT_PRIVILEGED) = "1111") then
              PPROT <= PPROT_PRIVILEGED;
            else
              PPROT <= PPROT_NORMAL;
            end if;
            PADDR  <= ahb_haddr(PADDR_SIZE-1 downto 0);
            PWRITE <= ahb_hwrite;
            PWDATA <= std_logic_vector(unsigned(ahb_hwdata) srl to_integer(unsigned(data_offset(ahb_haddr))));
            PSTRB  <= ahb_hwrite and pstrbf(ahb_hsize, ahb_haddr(PADDR_SIZE-1 downto 0));  --TODO: check/sim

            apb_prdata           <= (others => '0');  --clear prdata
            apb_beat_cnt         <= apb_beats(ahb_hsize);
            apb_beat_data_offset <= std_logic_vector(unsigned(data_offset(ahb_haddr))+to_unsigned(PDATA_SIZE, HADDR_SIZE));  --for the NEXT transfer
          end if;
        when ST_APB_SETUP =>
          --retain all signals and assert PENABLE
          apb_fsm <= ST_APB_TRANSFER;
          PENABLE <= '1';
        when ST_APB_TRANSFER =>
          if (PREADY = '1') then
            apb_beat_cnt         <= std_logic_vector(unsigned(apb_beat_cnt)-"0000001");
            apb_beat_data_offset <= std_logic_vector(unsigned(apb_beat_data_offset)+to_unsigned(PDATA_SIZE, HADDR_SIZE));

            apb_prdata <= std_logic_vector(unsigned(apb_prdata) sll PDATA_SIZE) or
                          std_logic_vector(unsigned(PRDATA) sll to_integer(unsigned(data_offset(ahb_haddr))));  --TODO: check/sim
            apb_pslverr <= PSLVERR;

            PENABLE <= '0';

            if (PSLVERR = '1' or reduce_nor(apb_beat_cnt) = '1') then
            --  * Transfer complete
            --  * Go back to IDLE
            --  * Signal AHB fsm, transfer complete
              apb_fsm  <= ST_APB_IDLE;
              apb_tack <= '1';
              PSEL     <= '0';
            else
            --  * More beats in current transfer
            --  * Setup next address and data
              apb_fsm <= ST_APB_SETUP;
              SPADDR  <= std_logic_vector(unsigned(SPADDR)+to_unsigned(2**to_integer(unsigned(ahb_hsize)), PADDR_SIZE));
              PADDR   <= SPADDR;
              PWDATA  <= std_logic_vector(unsigned(ahb_hwdata) srl to_integer(unsigned(apb_beat_data_offset)));
              PSTRB   <= ahb_hwrite and pstrbf(ahb_hsize, std_logic_vector(unsigned(SPADDR)+to_unsigned(2**to_integer(unsigned(ahb_hsize)), PADDR_SIZE)));
            end if;
          end if;
        when others =>
          null;
      end case;
    end if;
  end process;
end RTL;
