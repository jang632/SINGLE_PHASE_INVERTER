library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.finish;

entity tb_top is
end entity tb_top;

architecture Behavioral of tb_top is


  constant CLK_PERIOD       : time := 8 ns;          -- Main clock (e.g., 125 MHz)
  constant SLW_CLK_PERIOD   : time := 100 ns;        -- PI cascade clock (10 MHz)
  constant Ts               : real := 1.0 / 50000.0; -- Sampling period (20 us)
  -- =========================================================================
  -- ======================= CONFIGURATION PARAMETERS ========================
  -- =========================================================================
  
  -- 1. PHYSICAL ELEMENTS OF THE FILTER AND DC-LINK
  constant L1               : real := 2.2 / 10000.0; -- Inverter inductance (H)
  constant R1               : real := 0.1;           -- L1 resistance (Ohm)
  constant L2               : real := 1.1 / 10000.0; -- Grid inductance (H)
  constant R2               : real := 0.1;           -- L2 resistance (Ohm)
  constant Cf               : real := 4.7 / 1000000.0; -- Filter capacitance Cf (F)
  constant Rd               : real := 0.5;           -- Damping resistor (Ohm)
  constant C_DC_VAL         : real := 3.6 / 1000.0;  -- DC-Link capacitance (F)

  -- 2. GRID AND SYSTEM PARAMETERS
  constant NOMINAL_GRID_AMP : real := 39.0;              -- Nominal grid amplitude (V)
  constant NOMINAL_VDC      : real := 48.0;              -- Reference DC-Link voltage (V)
  constant SOGI_K_VAL       : real := 0.25 * sqrt(2.0);  -- SOGI error gain

  -- =========================================================================
  -- ================== END OF CONFIGURATION PARAMETERS ======================
  -- =========================================================================
  
  constant COEFF_WIDTH : integer := 32;
  signal b0_alpha : signed(COEFF_WIDTH - 1 downto 0) := x"000E81B9";  
  signal b1_alpha : signed(COEFF_WIDTH - 1 downto 0) := x"00000000";  
  signal b2_alpha : signed(COEFF_WIDTH - 1 downto 0) := x"FFF17E47";  
  signal b0_beta  : signed(COEFF_WIDTH - 1 downto 0) := x"00000BAB";  
  signal b1_beta  : signed(COEFF_WIDTH - 1 downto 0) := x"00001756";  
  signal b2_beta  : signed(COEFF_WIDTH - 1 downto 0) := x"00000BAB";  
  signal a1       : signed(COEFF_WIDTH - 1 downto 0) := x"1FE2D34E";  
  signal a2       : signed(COEFF_WIDTH - 1 downto 0) := x"F01D0373"; 

  signal clk     : std_logic := '0';
  signal slw_clk : std_logic := '0';
  signal rst     : std_logic := '1';
  signal ce      : std_logic := '1'; 
  
  signal v_dc   : signed(15 downto 0) := (others => '0');
  signal v_ref  : signed(31 downto 0) := (others => '0');
  signal v_grid : signed(15 downto 0) := (others => '0');
  signal i_meas : signed(15 downto 0) := (others => '0');
  signal i_cap  : signed(15 downto 0) := (others => '0');

  signal omega      : signed(31 downto 0);
  signal grid_fault : std_logic;
  signal dc_fault   : std_logic;
  signal v_out      : signed(47 downto 0);
  
  signal relay_dc_s   : std_logic;
  signal relay_dcpc_s : std_logic;
  signal relay_grid_s : std_logic;
  
  signal relay_dc_delayed   : std_logic := '0';
  signal relay_dcpc_delayed : std_logic := '0';
  signal relay_grid_delayed : std_logic := '0';
  
  signal norm : signed(15 downto 0);
  
  signal vdc_filtered : signed(15 downto 0) := (others => '0');
  signal P_IN_S       : signed(15 downto 0) := (others => '0');
  
begin

  uut : entity work.top
    port map (
      clk          => clk,
      rst          => rst,
      ce           => ce,
      v_dc         => v_dc,
      v_ref        => v_ref,
      v_grid       => v_grid,
      i_meas       => i_meas,
      i_cap        => i_cap,
      b0_alpha     => b0_alpha,
      b1_alpha     => b1_alpha,
      b2_alpha     => b2_alpha,
      b0_beta      => b0_beta,
      b1_beta      => b1_beta,
      b2_beta      => b2_beta,
      a1           => a1,
      a2           => a2,
      norm         => norm,
      relay_dc     => relay_dc_s,
      relay_dcpc   => relay_dcpc_s,
      relay_grid   => relay_grid_s,
      omega        => omega,
      grid_fault   => grid_fault,
      dc_fault     => dc_fault,
      vdc_filtered => vdc_filtered,
      v_out        => v_out,
      pwm_a_low    => open,
      pwm_a_high   => open,
      pwm_b_low    => open,
      pwm_b_high   => open
    );

  relay_dc_delayed   <= relay_dc_s   after 10 ms;
  relay_dcpc_delayed <= relay_dcpc_s after 10 ms;
  relay_grid_delayed <= relay_grid_s after 10 ms;

  clk_process : process
  begin
    clk <= '0';
    wait for CLK_PERIOD / 2;
    clk <= '1';
    wait for CLK_PERIOD / 2;
  end process;
  
  slw_clk_process : process
  begin
    slw_clk <= '0';
    wait for SLW_CLK_PERIOD / 2;
    slw_clk <= '1';
    wait for SLW_CLK_PERIOD / 2;
  end process;

  stim_proc : process

    function to_real_scaled(val : signed(47 downto 0); scale : real) return real is
      variable tmp : real := 0.0;
    begin
      for i in 0 to 46 loop
        if val(i) = '1' then
          tmp := tmp + (2.0**i);
        end if;
      end loop;
      if val(47) = '1' then
        tmp := tmp - (2.0**47); 
      end if;
      return tmp / scale;
    end function to_real_scaled;

    variable n : integer := 0;
    
    variable I_L1_k     : real := 0.0; 
    variable I_L2_k     : real := 0.0;
    variable V_cf_k     : real := 0.0;
    variable V_C_branch : real := 0.0;
    
    variable u_inv_real  : real := 0.0;
    variable v_grid_real : real := 0.0;
    
    variable P_out : real := 0.0;
    variable I_cap : real := 0.0;
    
    variable V_dc_meas : real := 0.0; 
    
    variable P_in       : real := 0.0;
    variable P_in_avail : real := 0.0; 
    variable C_dc       : real := C_DC_VAL;
    
    variable theta_var  : real := 0.0;
    variable TWO_PI     : real := 2.0 * math_pi;
  -- =========================================================================
  -- ======================= SIMULATION SCENARIO (FREQUENCY DISTORTION) ======
  -- =========================================================================
    variable THETA_STEP : real := 2.0 * math_pi * 52.0 * Ts; -- Grid frequency
  -- =========================================================================
    
    variable pwm_enabled : boolean := false;
    variable grid_amp    : real := NOMINAL_GRID_AMP;
    
    variable w0                               : real;
    variable K_val                            : real := SOGI_K_VAL;
    variable x, y, D, inv_D, ky               : real;
    variable v_b0_alpha, v_b2_alpha           : real;
    variable v_b0_beta, v_b1_beta, v_b2_beta  : real;
    variable v_a1, v_a2                       : real;
    constant SCALE_Q28                        : real := 2.0**28;
    
    variable norm_factor : real;

    constant MS_ITER : integer := 50;
    
  begin   
    rst <= '1';
    ce  <= '1'; 
    wait for 40 us;
    
    wait until rising_edge(clk);
    rst <= '0';
    
    v_ref <= to_signed(integer(NOMINAL_VDC * 2.0**16), 32); 
    
    while n < 7600 * MS_ITER loop
    
      for i in 1 to 200 loop
        wait until rising_edge(slw_clk);
      end loop;

      if n mod 250 = 0 then
        w0 := real(to_integer(omega)) / 2.0**21; 
        
        if w0 < 50.0 then
          w0 := 2.0 * math_pi * 50.0;
        end if;
        
        x     := 2.0 * K_val * w0 * Ts;
        y     := (w0 * Ts)**2;
        D     := 4.0 + x + y;
        inv_D := 1.0 / D;
        ky    := K_val * y;
    
        v_b0_alpha :=  x * inv_D;
        v_b2_alpha := -x * inv_D;
        v_b0_beta  :=  ky * inv_D;
        v_b1_beta  :=  2.0 * ky * inv_D;
        v_b2_beta  :=  ky * inv_D;
        v_a1       :=  (8.0 - 2.0 * y) * inv_D;
        v_a2       := -(4.0 - x + y) * inv_D;
    
        b0_alpha <= to_signed(integer(v_b0_alpha * SCALE_Q28), 32);
        b1_alpha <= to_signed(integer(0.0), 32); 
        b2_alpha <= to_signed(integer(v_b2_alpha * SCALE_Q28), 32);
        b0_beta  <= to_signed(integer(v_b0_beta  * SCALE_Q28), 32);
        b1_beta  <= to_signed(integer(v_b1_beta  * SCALE_Q28), 32);
        b2_beta  <= to_signed(integer(v_b2_beta  * SCALE_Q28), 32);
        a1       <= to_signed(integer(v_a1       * SCALE_Q28), 32);
        a2       <= to_signed(integer(v_a2       * SCALE_Q28), 32);
      end if;
      
      -- =======================================================================
      -- ================= SIMULATION SCENARIO (DC POWER) ======================
      -- =======================================================================
      if n < 400 * MS_ITER then  -- Value next to MS_ITER is expressed in ms
        P_in_avail := 0.0; 
      elsif n < 600 * MS_ITER then
        P_in_avail := 300.0;
      elsif n < 800 * MS_ITER then
        P_in_avail := 200.0;  
      elsif n < 1000 * MS_ITER then
        P_in_avail := 300.0; 
      elsif n < 1200 * MS_ITER then
        P_in_avail := 100.0;   
      elsif n < 2200 * MS_ITER then
        P_in_avail := 300.0;
      elsif n < 2400 * MS_ITER then
        P_in_avail := 50.0;
      elsif n < 2600 * MS_ITER then
        P_in_avail := 300.0;
      else
        P_in_avail := 20.0; 
      end if;
      -- =======================================================================
      
      if relay_dc_delayed = '1' then
        P_in := P_in_avail; 
      elsif relay_dcpc_delayed = '1' then
        if V_dc_meas < NOMINAL_VDC then
          P_in := 15.0; 
        else
          P_in := 0.0;
        end if;
      else
        P_in := 0.0; 
      end if;
      
      P_IN_S <= to_signed(integer(2.0**4 * P_in), 16);

      if V_dc_meas > 70.0 then
        P_in := 0.0; 
      end if;

      if grid_fault = '1' then
        P_in := 0.0;
      end if;

      theta_var := theta_var + THETA_STEP;
      if theta_var >= TWO_PI then
        theta_var := theta_var - TWO_PI;
      end if;
      
      -- =======================================================================
      -- ================= SIMULATION SCENARIO (AC GRID) =======================
      -- =======================================================================
      if n >= 1400 * MS_ITER and n < 1500 * MS_ITER then   -- Value next to MS_ITER is expressed in ms
        grid_amp := NOMINAL_GRID_AMP * 1.2; 
      elsif n >= 1650 * MS_ITER and n < 1750 * MS_ITER then
        grid_amp := NOMINAL_GRID_AMP * 0.75;
      else
        grid_amp := NOMINAL_GRID_AMP;        
      end if;
      -- =======================================================================
      
      if to_integer(vdc_filtered) < 256 then
        norm_factor := 640000.0 / 256.0;
      else
        norm_factor := 640000.0 / real(to_integer(vdc_filtered));
      end if;
      
      norm <= to_signed(integer(2.0**8 * norm_factor), 16);
      
      
  -- =========================================================================
  -- ======================= SIMULATION SCENARIO (HARMONICS DISTORTION) ======
  -- =========================================================================
      v_grid_real := grid_amp * (sin(theta_var)) + grid_amp * 0.12 * sin(3.0 * theta_var) + grid_amp * 0.1 * sin(5.0 * theta_var); -- Grid harmonics
  -- =========================================================================
      v_grid      <= to_signed(integer(v_grid_real * 2.0**8), 16);
      v_dc        <= to_signed(integer(V_dc_meas * 2.0**8), 16);
      
      u_inv_real := to_real_scaled(v_out, 2.0**29);
      
      if relay_grid_delayed = '0' then
        u_inv_real  := 0.0;   
        pwm_enabled := false; 
      elsif u_inv_real /= 0.0 then
        pwm_enabled := true;
      else
        pwm_enabled := false; 
      end if;

      if grid_fault = '1' then
        pwm_enabled := false;
      end if;

      if not pwm_enabled then
        I_L1_k := 0.0;
        I_L2_k := 0.0;
        V_cf_k := v_grid_real; 
        P_out  := 0.0;
        i_meas <= (others => '0'); 
      else
        if dc_fault = '1' then
          I_L1_k := 0.0; 
          P_out  := 0.0;
        else
          if u_inv_real > V_dc_meas then
            u_inv_real := V_dc_meas;
          elsif u_inv_real < -V_dc_meas then
            u_inv_real := -V_dc_meas;
          end if;
          P_out := u_inv_real * I_L1_k;
        end if;

        for sub in 1 to 10 loop
          V_C_branch := V_cf_k + Rd * (I_L1_k - I_L2_k);
              
          if dc_fault = '0' then
            I_L1_k := I_L1_k + (Ts / 10.0) * (u_inv_real - I_L1_k * R1 - V_C_branch) / L1;
          end if;
          
          I_L2_k := I_L2_k + (Ts / 10.0) * (V_C_branch - I_L2_k * R2 - v_grid_real) / L2;
          V_cf_k := V_cf_k + (Ts / 10.0) * (I_L1_k - I_L2_k) / Cf;
        end loop;
      
        i_meas <= to_signed(integer(I_L2_k * 2.0**10), 16);
      end if;
      
      if V_dc_meas < 1.0 then
        I_cap := (P_in - P_out) / 1.0; 
      else
        I_cap := (P_in - P_out) / V_dc_meas;
      end if;
      
      V_dc_meas := V_dc_meas + (I_cap / C_dc) * Ts;
      
      n := n + 1;
      
    end loop;
    
    finish;
    wait;
  end process;
  
end architecture Behavioral;