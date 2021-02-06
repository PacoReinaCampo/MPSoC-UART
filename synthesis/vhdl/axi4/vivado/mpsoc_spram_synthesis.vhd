-- Converted from mpsoc_spram_synthesis.sv
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
--              PU-RISCV                                                      //
--              Synthesis                                                     //
--              AMBA4 AXI-Lite Bus Interface                                  //
--                                                                            //
--//////////////////////////////////////////////////////////////////////////////

-- Copyright (c) 2017-2018 by the author(s)
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

entity mpsoc_spram_synthesis is
  generic (
    AXI_ID_WIDTH   : integer := 10;
    AXI_ADDR_WIDTH : integer := 32;
    AXI_DATA_WIDTH : integer := 16;
    AXI_STRB_WIDTH : integer := 8;
    AXI_USER_WIDTH : integer := 10
    );
  port (
    HRESETn : in std_logic;
    HCLK    : in std_logic;

    req_o  : out std_logic;
    we_o   : out std_logic;
    addr_o : out std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
    be_o   : out std_logic_vector(AXI_DATA_WIDTH/8-1 downto 0);
    data_o : out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
    data_i : in  std_logic_vector(AXI_DATA_WIDTH-1 downto 0)
    );
end mpsoc_spram_synthesis;

architecture RTL of mpsoc_spram_synthesis is
  component mpsoc_axi4_spram
    generic (
      AXI_ID_WIDTH   : integer := 10;
      AXI_ADDR_WIDTH : integer := 64;
      AXI_DATA_WIDTH : integer := 64;
      AXI_STRB_WIDTH : integer := 8;
      AXI_USER_WIDTH : integer := 10
      );
    port (
      clk_i  : in std_logic;            -- Clock
      rst_ni : in std_logic;            -- Asynchronous reset active low

      axi_aw_id     : in  std_logic_vector(AXI_ID_WIDTH-1 downto 0);
      axi_aw_addr   : in  std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
      axi_aw_len    : in  std_logic_vector(7 downto 0);
      axi_aw_size   : in  std_logic_vector(2 downto 0);
      axi_aw_burst  : in  std_logic_vector(1 downto 0);
      axi_aw_lock   : in  std_logic;
      axi_aw_cache  : in  std_logic_vector(3 downto 0);
      axi_aw_prot   : in  std_logic_vector(2 downto 0);
      axi_aw_qos    : in  std_logic_vector(3 downto 0);
      axi_aw_region : in  std_logic_vector(3 downto 0);
      axi_aw_user   : in  std_logic_vector(AXI_USER_WIDTH-1 downto 0);
      axi_aw_valid  : in  std_logic;
      axi_aw_ready  : out std_logic;

      axi_ar_id     : in  std_logic_vector(AXI_ID_WIDTH-1 downto 0);
      axi_ar_addr   : in  std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
      axi_ar_len    : in  std_logic_vector(7 downto 0);
      axi_ar_size   : in  std_logic_vector(2 downto 0);
      axi_ar_burst  : in  std_logic_vector(1 downto 0);
      axi_ar_lock   : in  std_logic;
      axi_ar_cache  : in  std_logic_vector(3 downto 0);
      axi_ar_prot   : in  std_logic_vector(2 downto 0);
      axi_ar_qos    : in  std_logic_vector(3 downto 0);
      axi_ar_region : in  std_logic_vector(3 downto 0);
      axi_ar_user   : in  std_logic_vector(AXI_USER_WIDTH-1 downto 0);
      axi_ar_valid  : in  std_logic;
      axi_ar_ready  : out std_logic;

      axi_w_data  : in  std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
      axi_w_strb  : in  std_logic_vector(AXI_STRB_WIDTH-1 downto 0);
      axi_w_last  : in  std_logic;
      axi_w_user  : in  std_logic_vector(AXI_USER_WIDTH-1 downto 0);
      axi_w_valid : in  std_logic;
      axi_w_ready : out std_logic;

      axi_r_id    : out std_logic_vector(AXI_ID_WIDTH-1 downto 0);
      axi_r_data  : out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
      axi_r_resp  : out std_logic_vector(1 downto 0);
      axi_r_last  : out std_logic;
      axi_r_user  : out std_logic_vector(AXI_USER_WIDTH-1 downto 0);
      axi_r_valid : out std_logic;
      axi_r_ready : in  std_logic;

      axi_b_id    : out std_logic_vector(AXI_ID_WIDTH-1 downto 0);
      axi_b_resp  : out std_logic_vector(1 downto 0);
      axi_b_user  : out std_logic_vector(AXI_USER_WIDTH-1 downto 0);
      axi_b_valid : out std_logic;
      axi_b_ready : in  std_logic;

      req_o  : out std_logic;
      we_o   : out std_logic;
      addr_o : out std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
      be_o   : out std_logic_vector(AXI_DATA_WIDTH/8-1 downto 0);
      data_o : out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
      data_i : in  std_logic_vector(AXI_DATA_WIDTH-1 downto 0)
      );
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  -- AXI4 Instruction
  signal axi4_ins_aw_id     : std_logic_vector(AXI_ID_WIDTH-1 downto 0);
  signal axi4_ins_aw_addr   : std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
  signal axi4_ins_aw_len    : std_logic_vector(7 downto 0);
  signal axi4_ins_aw_size   : std_logic_vector(2 downto 0);
  signal axi4_ins_aw_burst  : std_logic_vector(1 downto 0);
  signal axi4_ins_aw_lock   : std_logic;
  signal axi4_ins_aw_cache  : std_logic_vector(3 downto 0);
  signal axi4_ins_aw_prot   : std_logic_vector(2 downto 0);
  signal axi4_ins_aw_qos    : std_logic_vector(3 downto 0);
  signal axi4_ins_aw_region : std_logic_vector(3 downto 0);
  signal axi4_ins_aw_user   : std_logic_vector(AXI_USER_WIDTH-1 downto 0);
  signal axi4_ins_aw_valid  : std_logic;
  signal axi4_ins_aw_ready  : std_logic;

  signal axi4_ins_ar_id     : std_logic_vector(AXI_ID_WIDTH-1 downto 0);
  signal axi4_ins_ar_addr   : std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
  signal axi4_ins_ar_len    : std_logic_vector(7 downto 0);
  signal axi4_ins_ar_size   : std_logic_vector(2 downto 0);
  signal axi4_ins_ar_burst  : std_logic_vector(1 downto 0);
  signal axi4_ins_ar_lock   : std_logic;
  signal axi4_ins_ar_cache  : std_logic_vector(3 downto 0);
  signal axi4_ins_ar_prot   : std_logic_vector(2 downto 0);
  signal axi4_ins_ar_qos    : std_logic_vector(3 downto 0);
  signal axi4_ins_ar_region : std_logic_vector(3 downto 0);
  signal axi4_ins_ar_user   : std_logic_vector(AXI_USER_WIDTH-1 downto 0);
  signal axi4_ins_ar_valid  : std_logic;
  signal axi4_ins_ar_ready  : std_logic;

  signal axi4_ins_w_data  : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
  signal axi4_ins_w_strb  : std_logic_vector(AXI_STRB_WIDTH-1 downto 0);
  signal axi4_ins_w_last  : std_logic;
  signal axi4_ins_w_user  : std_logic_vector(AXI_USER_WIDTH-1 downto 0);
  signal axi4_ins_w_valid : std_logic;
  signal axi4_ins_w_ready : std_logic;

  signal axi4_ins_r_id    : std_logic_vector(AXI_ID_WIDTH-1 downto 0);
  signal axi4_ins_r_data  : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
  signal axi4_ins_r_resp  : std_logic_vector(1 downto 0);
  signal axi4_ins_r_last  : std_logic;
  signal axi4_ins_r_user  : std_logic_vector(AXI_USER_WIDTH-1 downto 0);
  signal axi4_ins_r_valid : std_logic;
  signal axi4_ins_r_ready : std_logic;

  signal axi4_ins_b_id    : std_logic_vector(AXI_ID_WIDTH-1 downto 0);
  signal axi4_ins_b_resp  : std_logic_vector(1 downto 0);
  signal axi4_ins_b_user  : std_logic_vector(AXI_USER_WIDTH-1 downto 0);
  signal axi4_ins_b_valid : std_logic;
  signal axi4_ins_b_ready : std_logic;

  --AXI4 Data
  signal axi4_dat_aw_id     : std_logic_vector(AXI_ID_WIDTH-1 downto 0);
  signal axi4_dat_aw_addr   : std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
  signal axi4_dat_aw_len    : std_logic_vector(7 downto 0);
  signal axi4_dat_aw_size   : std_logic_vector(2 downto 0);
  signal axi4_dat_aw_burst  : std_logic_vector(1 downto 0);
  signal axi4_dat_aw_lock   : std_logic;
  signal axi4_dat_aw_cache  : std_logic_vector(3 downto 0);
  signal axi4_dat_aw_prot   : std_logic_vector(2 downto 0);
  signal axi4_dat_aw_qos    : std_logic_vector(3 downto 0);
  signal axi4_dat_aw_region : std_logic_vector(3 downto 0);
  signal axi4_dat_aw_user   : std_logic_vector(AXI_USER_WIDTH-1 downto 0);
  signal axi4_dat_aw_valid  : std_logic;
  signal axi4_dat_aw_ready  : std_logic;

  signal axi4_dat_ar_id     : std_logic_vector(AXI_ID_WIDTH-1 downto 0);
  signal axi4_dat_ar_addr   : std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
  signal axi4_dat_ar_len    : std_logic_vector(7 downto 0);
  signal axi4_dat_ar_size   : std_logic_vector(2 downto 0);
  signal axi4_dat_ar_burst  : std_logic_vector(1 downto 0);
  signal axi4_dat_ar_lock   : std_logic;
  signal axi4_dat_ar_cache  : std_logic_vector(3 downto 0);
  signal axi4_dat_ar_prot   : std_logic_vector(2 downto 0);
  signal axi4_dat_ar_qos    : std_logic_vector(3 downto 0);
  signal axi4_dat_ar_region : std_logic_vector(3 downto 0);
  signal axi4_dat_ar_user   : std_logic_vector(AXI_USER_WIDTH-1 downto 0);
  signal axi4_dat_ar_valid  : std_logic;
  signal axi4_dat_ar_ready  : std_logic;

  signal axi4_dat_w_data  : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
  signal axi4_dat_w_strb  : std_logic_vector(AXI_STRB_WIDTH-1 downto 0);
  signal axi4_dat_w_last  : std_logic;
  signal axi4_dat_w_user  : std_logic_vector(AXI_USER_WIDTH-1 downto 0);
  signal axi4_dat_w_valid : std_logic;
  signal axi4_dat_w_ready : std_logic;

  signal axi4_dat_r_id    : std_logic_vector(AXI_ID_WIDTH-1 downto 0);
  signal axi4_dat_r_data  : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
  signal axi4_dat_r_resp  : std_logic_vector(1 downto 0);
  signal axi4_dat_r_last  : std_logic;
  signal axi4_dat_r_user  : std_logic_vector(AXI_USER_WIDTH-1 downto 0);
  signal axi4_dat_r_valid : std_logic;
  signal axi4_dat_r_ready : std_logic;

  signal axi4_dat_b_id    : std_logic_vector(AXI_ID_WIDTH-1 downto 0);
  signal axi4_dat_b_resp  : std_logic_vector(1 downto 0);
  signal axi4_dat_b_user  : std_logic_vector(AXI_USER_WIDTH-1 downto 0);
  signal axi4_dat_b_valid : std_logic;
  signal axi4_dat_b_ready : std_logic;

begin

  --//////////////////////////////////////////////////////////////
  --
  -- Module Body
  --

  --Data AXI4
  data_axi4 : mpsoc_axi4_spram
    generic map (
      AXI_ID_WIDTH   => AXI_ID_WIDTH,
      AXI_ADDR_WIDTH => AXI_ADDR_WIDTH,
      AXI_DATA_WIDTH => AXI_DATA_WIDTH,
      AXI_STRB_WIDTH => AXI_STRB_WIDTH,
      AXI_USER_WIDTH => AXI_USER_WIDTH
      )
    port map (
      clk_i  => HCLK,                   -- Clock
      rst_ni => HRESETn,                -- Asynchronous reset active low

      axi_aw_id     => axi4_dat_aw_id,
      axi_aw_addr   => axi4_dat_aw_addr,
      axi_aw_len    => axi4_dat_aw_len,
      axi_aw_size   => axi4_dat_aw_size,
      axi_aw_burst  => axi4_dat_aw_burst,
      axi_aw_lock   => axi4_dat_aw_lock,
      axi_aw_cache  => axi4_dat_aw_cache,
      axi_aw_prot   => axi4_dat_aw_prot,
      axi_aw_qos    => axi4_dat_aw_qos,
      axi_aw_region => axi4_dat_aw_region,
      axi_aw_user   => axi4_dat_aw_user,
      axi_aw_valid  => axi4_dat_aw_valid,
      axi_aw_ready  => axi4_dat_aw_ready,

      axi_ar_id     => axi4_dat_ar_id,
      axi_ar_addr   => axi4_dat_ar_addr,
      axi_ar_len    => axi4_dat_ar_len,
      axi_ar_size   => axi4_dat_ar_size,
      axi_ar_burst  => axi4_dat_ar_burst,
      axi_ar_lock   => axi4_dat_ar_lock,
      axi_ar_cache  => axi4_dat_ar_cache,
      axi_ar_prot   => axi4_dat_ar_prot,
      axi_ar_qos    => axi4_dat_ar_qos,
      axi_ar_region => axi4_dat_ar_region,
      axi_ar_user   => axi4_dat_ar_user,
      axi_ar_valid  => axi4_dat_ar_valid,
      axi_ar_ready  => axi4_dat_ar_ready,

      axi_w_data  => axi4_dat_w_data,
      axi_w_strb  => axi4_dat_w_strb,
      axi_w_last  => axi4_dat_w_last,
      axi_w_user  => axi4_dat_w_user,
      axi_w_valid => axi4_dat_w_valid,
      axi_w_ready => axi4_dat_w_ready,

      axi_r_id    => axi4_dat_r_id,
      axi_r_data  => axi4_dat_r_data,
      axi_r_resp  => axi4_dat_r_resp,
      axi_r_last  => axi4_dat_r_last,
      axi_r_user  => axi4_dat_r_user,
      axi_r_valid => axi4_dat_r_valid,
      axi_r_ready => axi4_dat_r_ready,

      axi_b_id    => axi4_dat_b_id,
      axi_b_resp  => axi4_dat_b_resp,
      axi_b_user  => axi4_dat_b_user,
      axi_b_valid => axi4_dat_b_valid,
      axi_b_ready => axi4_dat_b_ready,

      req_o  => req_o,
      we_o   => we_o,
      addr_o => addr_o,
      be_o   => be_o,
      data_o => data_o,
      data_i => data_i
      );
end RTL;
