library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity parke_transform is
  port (
    clk     : in  std_logic;
    rst     : in  std_logic;
    ce      : in  std_logic;
    v       : in  signed(31 downto 0);
    qv      : in  signed(31 downto 0);
    theta   : in  signed(31 downto 0);
    v_d     : out signed(31 downto 0);
    v_q     : out signed(31 downto 0)
  );
end entity parke_transform;

architecture behavioral of parke_transform is

  signal sin_val : signed(31 downto 0);
  signal cos_val : signed(31 downto 0);

  signal v_d_int : signed(63 downto 0);
  signal v_q_int : signed(63 downto 0);

  signal v_alpha_delayed : signed(31 downto 0);
  signal v_beta_delayed  : signed(31 downto 0);

begin

  u_cordic : entity work.cordic_sin_cos
    generic map (
      iterations => 14,
      WIDTH      => 32,
      OUT_FP     => 28
    )
    port map (
      clk        => clk,
      reset      => rst,
      ce         => ce,
      theta      => theta,
      sin_value  => sin_val,
      cos_value  => cos_val
    );

  u_beta_delay : entity work.shift_register
    generic map (
      DATA_WIDTH => 32,
      DEPTH      => 14
    )
    port map (
      clk        => clk,
      rst        => rst,
      ce         => ce,
      data_in    => qv,
      data_out   => v_beta_delayed
    );

  u_alpha_delay : entity work.shift_register
    generic map (
      DATA_WIDTH => 32,
      DEPTH      => 1
    )
    port map (
      clk        => clk,
      rst        => rst,
      ce         => ce,
      data_in    => v,
      data_out   => v_alpha_delayed
    );

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        v_d_int <= (others => '0');
        v_q_int <= (others => '0');
      elsif ce = '1' then
        v_d_int <= v_alpha_delayed * cos_val + v_beta_delayed * sin_val;
        v_q_int <= v_beta_delayed  * cos_val - v_alpha_delayed * sin_val;
      end if;
    end if;
  end process;

  v_d <= shift_left(v_d_int(63 downto 32), 1);
  v_q <= shift_left(v_q_int(63 downto 32), 1);

end architecture behavioral;