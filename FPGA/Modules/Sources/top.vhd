library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
  port (
    clk          : in  std_logic;
    rst          : in  std_logic;
    ce           : in  std_logic;
    v_dc         : in  signed(15 downto 0); -- fixed point 8
    v_ref        : in  signed(31 downto 0); -- fixed point 16
    v_grid       : in  signed(15 downto 0); -- fixed point 8
    i_meas       : in  signed(15 downto 0); -- fixed point 10
    i_cap        : in  signed(15 downto 0); -- fixed point 10
    b0_alpha     : in  signed(31 downto 0); -- fixed point 28
    b1_alpha     : in  signed(31 downto 0); -- fixed point 28
    b2_alpha     : in  signed(31 downto 0); -- fixed point 28
    b0_beta      : in  signed(31 downto 0); -- fixed point 28
    b1_beta      : in  signed(31 downto 0); -- fixed point 28
    b2_beta      : in  signed(31 downto 0); -- fixed point 28
    a1           : in  signed(31 downto 0); -- fixed point 28
    a2           : in  signed(31 downto 0); -- fixed point 28
    norm         : in  signed(15 downto 0);
    relay_dc     : out std_logic;
    relay_dcpc   : out std_logic;
    relay_grid   : out std_logic;
    omega        : out signed(31 downto 0); -- fixed point 21
    grid_fault   : out std_logic;
    dc_fault     : out std_logic;
    vdc_filtered : out signed(15 downto 0); -- fixed point 8
    v_out        : out signed(47 downto 0);  -- fixed point 29
    pwm_a_low    : out std_logic;
    pwm_a_high   : out std_logic;
    pwm_b_low    : out std_logic;
    pwm_b_high   : out std_logic
  );
end entity top;

architecture Behavioral of top is

  signal grid_error  : std_logic;
  signal dc_error_uv : std_logic;
  signal dc_error_ov : std_logic;

  signal sogi_v      : signed(31 downto 0);
  signal sogi_qv     : signed(31 downto 0);
  
  signal data_out_10mhz : signed(47 downto 0);
  signal data_in_200mhz : signed(47 downto 0);

  signal ce_slow    : std_logic;
  signal ov1        : std_logic;
  
  signal v_pwm_shift : signed(47 downto 0);
  signal v_pwm_slice : signed(15 downto 0);
  signal v_pwm_norm  : signed(31 downto 0);
  signal v_pwm       : signed(15 downto 0);
  
  signal fast_clk    : std_logic;
  signal slow_clk    : std_logic;
  
  signal ce_pwm     : std_logic;
  
  constant FIXED_POINT : integer := 2**8;
  
  constant PRECHARGE_THRESHOLD : signed(15 downto 0) := to_signed(38 * FIXED_POINT, 16);
  constant VDC_FAULT_THRESHOLD : signed(15 downto 0) := to_signed(70 * FIXED_POINT, 16);
  
  type state_t is (POWER_ON, PRECHARGE, RUNNING, FAULT_DC_OV, FAULT_DC_UV, FAULT_GRID, DISCHARGE, RELAY_DELAY);
  signal state      : state_t;
  signal next_state : state_t;

  signal delay_count : signed(15 downto 0);
  signal timer_tick  : std_logic;
  signal timer_count : signed(15 downto 0);
  
  signal rst_pwm : std_logic;
  
  signal r_dc_error_uv : std_logic;
  signal r_dc_error_ov : std_logic;
  signal r_grid_error  : std_logic;

begin

  grid_fault <= r_grid_error;
  dc_fault   <= r_dc_error_uv;
    
  v_out <= data_out_10mhz;
  
  process(fast_clk)
  begin
    if rising_edge(fast_clk) then
      if rst = '1' then
        data_in_200mhz <= (others => '0');
        v_pwm_shift    <= (others => '0');
        v_pwm_slice    <= (others => '0');
        v_pwm_norm     <= (others => '0');
        v_pwm          <= (others => '0');
      elsif ce = '1' then
        data_in_200mhz <= data_out_10mhz;
        v_pwm_shift    <= shift_left(data_in_200mhz, 11);
        v_pwm_slice    <= v_pwm_shift(47 downto 32);
        v_pwm_norm     <= v_pwm_slice * norm;
        v_pwm          <= v_pwm_norm(31 downto 16);
      end if;
    end if;
  end process;
  
   u_pll : entity work.clk_wiz_0
    port map (
      clk_out1 => slow_clk,
      clk_out2 => fast_clk,
      clk_in1  => clk
    );

  u_maf_filter : entity work.maf_filter
    generic map (
      DATA_WIDTH    => 16,
      WINDOW_LENGTH => 500,
      FIXED_POINT   => 8
    )
    port map (
      clk      => slow_clk,
      rst      => rst,
      ce       => ce_slow,
      data_in  => v_dc,
      data_out => vdc_filtered
    );

  u_cascade_control : entity work.cascade_control
    port map (
      clk         => slow_clk,
      rst         => rst,
      ce          => ce_slow,
      v           => sogi_v,
      qv          => sogi_qv,
      v_dc        => v_dc,
      v_ref       => v_ref,
      v_grid      => v_grid,
      i_meas      => i_meas,
      i_cap       => i_cap,
      v_out       => data_out_10mhz,
      grid_error  => r_grid_error,
      dc_error_uv => r_dc_error_uv,
      dc_error_ov => r_dc_error_ov
    );

  u_adaptive_sogi : entity work.adaptive_sogi
    generic map (
      WIDTH => 16
    )
    port map (
      clk      => slow_clk,
      rst      => rst,
      ce       => ce_slow,
      b0_alpha => b0_alpha,
      b1_alpha => b1_alpha,
      b2_alpha => b2_alpha,
      b0_beta  => b0_beta,
      b1_beta  => b1_beta,
      b2_beta  => b2_beta,
      a1       => a1,
      a2       => a2,
      v_n      => v_grid,
      v        => sogi_v,
      qv       => sogi_qv
    );
        
  u_fll : entity work.fll
    port map (
      clk   => slow_clk,
      rst   => rst,
      ce    => ce_slow,
      v     => sogi_v,
      qv    => sogi_qv,
      v_n   => v_grid,
      omega => omega
    );

  rst_pwm <= not ce_pwm;   
 
  u_spwm : entity work.spwm
    port map (
      clk    => fast_clk,
      rst    => rst_pwm,
      v_ref  => v_pwm,
      a_low  => pwm_a_low,
      a_high => pwm_a_high,
      b_low  => pwm_b_low,
      b_high => pwm_b_high
    );
    
  u_relay_controller : entity work.relay_controller
    port map (
      clk         => slow_clk,
      rst         => rst,
      ce          => ce,
      v_dc        => v_dc,
      dc_error_uv => r_dc_error_uv,
      dc_error_ov => r_dc_error_ov,
      grid_error  => r_grid_error,
      ce_pwm      => ce_pwm,
      relay_dc    => relay_dc,
      relay_dcpc  => relay_dcpc,
      relay_grid  => relay_grid
    );
   
  u_enable_generator : entity work.enable_generator
    generic map (
      COUNT => 200
    )
    port map (
      clk        => slow_clk,
      rst        => rst,
      ce         => ce,
      enable_out => ce_slow
    );
    
end architecture Behavioral;