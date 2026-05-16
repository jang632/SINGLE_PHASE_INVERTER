library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pll is
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;
    ce    : in  std_logic;
    v     : in  signed(31 downto 0);
    qv    : in  signed(31 downto 0);
    error : out signed(31 downto 0);
    omega : out signed(31 downto 0); -- fixed point 20
    phase : out signed(31 downto 0)  -- fixed point 28
  );
end entity pll;

architecture Behavioral of pll is

  type machine is (LOCKING, STABLE);
  signal state : machine;
  
  signal reset  : std_logic := '0';
  signal enable : std_logic;
  
--  signal v          : signed(31 downto 0);
--  signal qv         : signed(31 downto 0);
  signal vd_error   : signed(31 downto 0); -- fixed point 24
  signal vq_voltage : signed(31 downto 0); -- fixed point 24
  signal v_d_ema    : signed(31 downto 0) := (others => '0');

  signal theta           : signed(31 downto 0);
  signal internal_phase  : signed(31 downto 0);
  signal theta_saturated : signed(31 downto 0);
  signal internal_omega  : signed(31 downto 0);
  
  constant Ts : signed(31 downto 0) := x"0000a7c6"; -- fixed point 31

  signal b0 : signed(31 downto 0) := x"210E5DC9"; -- fixed point 20
  signal b1 : signed(31 downto 0) := x"DF152A0B"; -- fixed point 20
  
  constant b0_LOCKING : signed(31 downto 0) := x"1BD46771"; -- fixed point 20
  constant b1_LOCKING : signed(31 downto 0) := x"E44B2DBD"; -- fixed point 20
  constant b0_STABLE  : signed(31 downto 0) := x"0A9BC1DD"; -- fixed point 20
  constant b1_STABLE  : signed(31 downto 0) := x"F56715CE"; -- fixed point 20

  constant vd_error_low   : signed(31 downto 0) := x"0010a3d7"; -- fixed point 24
  constant vd_error_high  : signed(31 downto 0) := x"001851ec"; -- fixed point 24
  constant lock_threshold : unsigned(15 downto 0) := to_unsigned(3000, 16);
  
  constant INIT       : signed(66 downto 0) := shift_left(to_signed(314, 67), 44);
  constant SATURATION : signed(66 downto 0) := shift_left(to_signed(1000, 67), 44);
  
  signal lock_counter : unsigned(15 downto 0) := (others => '0');

begin

  u_parke_transform : entity work.parke_transform
    port map (
      clk     => clk,
      rst     => rst,
      ce      => ce,
      v       => v,
      qv      => qv,
      theta   => internal_phase,
      v_d     => vd_error,
      v_q     => vq_voltage
    );

  u_pi_controller : entity work.pi_controller
    generic map (
      INIT        => INIT,
      SATURATION  => SATURATION,
      FP_DATA_IN  => 24,
      FP_COEFF    => 20,
      FP_DATA_OUT => 20
    )
    port map (
      clk      => clk,
      rst      => rst,
      ce       => ce,
      b0       => b0,
      b1       => b1,
      data_in  => vd_error,
      data_out => internal_omega
    );
  
  u_integrator : entity work.integrator
    port map (
      clk      => clk,
      rst      => rst,
      ce       => ce,
      data_in  => internal_omega,
      data_out => internal_phase
    );
  
  error <= vd_error;
  
  process(clk)
  begin
    if rising_edge(clk) then 
      if rst = '1' then 
        state        <= LOCKING;
        lock_counter <= (others => '0');
      elsif ce = '1' then
        case state is
          when LOCKING => 
            b0 <= b0_LOCKING;
            b1 <= b1_LOCKING;
            
            if abs(vd_error) < vd_error_low then 
              lock_counter <= lock_counter + 1;
            else
              lock_counter <= (others => '0');
            end if;
            
            if lock_counter > lock_threshold then 
              state <= STABLE;
            else
              state <= LOCKING;
            end if;
            
          when STABLE =>
            b0 <= b0_STABLE;
            b1 <= b1_STABLE;
            
            if abs(vd_error) > vd_error_high then 
              state <= LOCKING;
            else
              state <= STABLE;
            end if;
        end case;
      end if;
    end if;
  end process;
  
  phase <= internal_phase;
  omega <= internal_omega;
  
end architecture Behavioral;