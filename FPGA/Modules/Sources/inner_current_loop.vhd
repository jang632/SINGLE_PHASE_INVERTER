library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.pkg.all;

entity inner_current_loop is
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;
    ce     : in  std_logic;
    i_ref  : in  signed(15 downto 0); -- fixed point 10
    i_meas : in  signed(15 downto 0); -- fixed point 10
    i_cap  : in  signed(15 downto 0); -- fixed point 10
    v_grid : in  signed(15 downto 0); -- fixed point 8
    v_out  : out signed(47 downto 0)  -- fixed point 29
  );
end entity inner_current_loop;

architecture Behavioral of inner_current_loop is
  
  constant SATURATION_U_REQ : signed(47 downto 0) := shift_left(to_signed(45, 48), 29);
  
  constant CURRENT_WIDTH : integer := 16;
  constant VOLTAGE_WIDTH : integer := 16;
  
  constant FIXED_POINT_4  : integer := 2**4;
  constant FIXED_POINT_19 : integer := 2**19;

  constant R_V : signed(7 downto 0) := to_signed(integer(1.50000000 * FIXED_POINT_4), 8);

  -- Regulator PR 50 Hz
  constant KP_50HZ : signed(21 downto 0) := to_signed(integer( 0.50000000 * FIXED_POINT_19), 22);
  constant B0_50HZ : signed(21 downto 0) := to_signed(integer( 0.02010094 * FIXED_POINT_19), 22);
  constant A0_50HZ : signed(21 downto 0) := to_signed(integer(-1.99945801 * FIXED_POINT_19), 22);
  constant A1_50HZ : signed(21 downto 0) := to_signed(integer( 0.99949748 * FIXED_POINT_19), 22);

  -- Regulator PR 150 Hz (3. Harmoniczna)
  constant KP_150HZ : signed(21 downto 0) := to_signed(integer( 0.50000000 * FIXED_POINT_19), 22);
  constant B0_150HZ : signed(21 downto 0) := to_signed(integer( 0.01004968 * FIXED_POINT_19), 22);
  constant A0_150HZ : signed(21 downto 0) := to_signed(integer(-1.99914233 * FIXED_POINT_19), 22);
  constant A1_150HZ : signed(21 downto 0) := to_signed(integer( 0.99949752 * FIXED_POINT_19), 22);

  signal error_reg  : signed(CURRENT_WIDTH downto 0) := (others => '0'); -- fixed point 10
  signal u_req      : signed(47 downto 0);
  signal u_pr_50hz  : signed(43 downto 0);
  signal u_pr_150hz : signed(43 downto 0);
  signal v_grid_reg : signed(VOLTAGE_WIDTH - 1 downto 0);

  function truncate(data_in : signed; limit : signed) return signed is 
    variable data_out : signed(data_in'range); 
  begin
    if data_in > limit then
      data_out := limit;
    elsif data_in < -limit then
      data_out := -limit;
    else
      data_out := data_in;
    end if;  
    return data_out;
  end function truncate;
                  
begin

  u_pr_controller_50hz : entity work.pr_controller
    generic map (
      KP => KP_50HZ,
      B0 => B0_50HZ,
      A0 => A0_50HZ,
      A1 => A1_50HZ  
    )
    port map (
      clk      => clk,
      rst      => rst,
      ce       => ce,
      error    => error_reg,
      data_out => u_pr_50hz
    );
    
  u_pr_controller_150hz : entity work.pr_controller
    generic map (
      KP => KP_150HZ,
      B0 => B0_150HZ,
      A0 => A0_150HZ,
      A1 => A1_150HZ  
    )
    port map (
      clk      => clk,
      rst      => rst,
      ce       => ce,
      error    => error_reg,
      data_out => u_pr_150hz
    );

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then   
        error_reg  <= (others => '0'); 
        v_grid_reg <= (others => '0'); 
      elsif ce = '1' then
        error_reg  <= resize(i_ref, CURRENT_WIDTH + 1) - resize(i_meas, CURRENT_WIDTH + 1); -- fixed point 10
        v_grid_reg <= v_grid;                                                               -- fixed point 6
      end if;
    end if;
  end process;
  
  process(clk)
    variable damp_factor : signed(24 downto 0); 
  begin
    if rising_edge(clk) then
      if rst = '1' then   
        u_req <= (others => '0'); 
      elsif ce = '1' then   
        -- damp_factor := resize(R_V, 9) * i_cap;
        -- + shift_left(resize(damp_factor, 48), 23), 15)              
        u_req <= truncate(
          data_in => resize(u_pr_50hz, 48) + resize(u_pr_150hz, 48) + shift_left(resize(v_grid_reg, 48), 21), 
          limit   => SATURATION_U_REQ
        ); -- fixed point 29
      end if;
    end if;
  end process;
  
  v_out <= u_req;
  
end architecture Behavioral;