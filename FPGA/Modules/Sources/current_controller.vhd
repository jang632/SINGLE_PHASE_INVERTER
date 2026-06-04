library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.pkg.all;

entity current_controller is
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;
    ce     : in  std_logic;
    theta  : in  signed(31 downto 0); -- fixed point 28
    v_dc   : in  signed(15 downto 0); -- fixed point 8
    v_ref  : in  signed(31 downto 0); -- fixed point 16
    v_grid : in  signed(15 downto 0); -- fixed point 8
    i_meas : in  signed(15 downto 0); -- fixed point 10
    i_cap  : in  signed(15 downto 0); -- fixed point 10
    v_out  : out signed(47 downto 0)  -- fixed point 29
  );
end entity current_controller;

architecture Behavioral of current_controller is

  constant SATURATION_VAL : signed(66 downto 0) := shift_left(to_signed(20, 67), 44);
  constant INIT_VAL       : signed(66 downto 0) := shift_left(to_signed(0, 67), 44);
  
  constant FIXED_POINT_REAL : real := 2.0**28;

  constant B0 : signed(31 downto 0) := to_signed(integer( 0.60025000 * FIXED_POINT_REAL), 32);
  constant B1 : signed(31 downto 0) := to_signed(integer(-0.59975000 * FIXED_POINT_REAL), 32);

  signal v_dc_error   : signed(31 downto 0); -- fixed point 16
  signal i_ref        : signed(31 downto 0); -- fixed point 10
  signal i_ref_sliced : signed(15 downto 0); -- fixed point 10

  signal sin_val      : signed(15 downto 0); -- fixed point 14
  signal v_dc_maf     : signed(15 downto 0); -- fixed point 6

begin

  u_maf_filter : entity work.maf_filter
    generic map (
      DATA_WIDTH    => 16,
      WINDOW_LENGTH => 500,
      FIXED_POINT   => 8
    )
    port map (
      clk      => clk,
      rst      => rst,
      ce       => ce,
      data_in  => v_dc,
      data_out => v_dc_maf
    );

  u_cordic_sin_cos : entity work.cordic_sin_cos
    generic map (
      ITERATIONS => 16,
      WIDTH      => 16,
      OUT_FP     => 14
    )
    port map (
      clk       => clk,
      reset     => rst,
      ce        => ce,
      theta     => theta,
      sin_value => sin_val,
      cos_value => open
    );

  u_pi_controller : entity work.pi_controller
    generic map (
      INIT        => INIT_VAL,
      SATURATION  => SATURATION_VAL,
      FP_DATA_IN  => 16,
      FP_COEFF    => 28,
      FP_DATA_OUT => 10
    )
    port map (
      clk      => clk,
      rst      => rst,
      ce       => ce,
      b0       => B0,
      b1       => B1,
      data_in  => v_dc_error,
      data_out => i_ref
    );

  u_inner_current_loop : entity work.inner_current_loop
    port map (
      clk    => clk,
      rst    => rst,
      ce     => ce,
      i_ref  => i_ref_sliced,
      i_meas => i_meas,
      i_cap  => i_cap,
      v_grid => v_grid,
      v_out  => v_out
    );
  
  process(clk)
    variable i_ref_mult : signed(47 downto 0);
  begin
    if rising_edge(clk) then 
      if rst = '1' then 
        v_dc_error   <= (others => '0');
        i_ref_sliced <= (others => '0');
        i_ref_mult   := (others => '0');
      elsif ce = '1' then
        v_dc_error   <= shift_left(resize(v_dc_maf, 32), 8) - v_ref; -- fixed point 16        
        i_ref_mult   := shift_left(i_ref * sin_val, 18);             -- fixed point 42
        i_ref_sliced <= i_ref_mult(47 downto 32);                    -- fixed point 10
      end if;
    end if;
  end process;

end architecture Behavioral;