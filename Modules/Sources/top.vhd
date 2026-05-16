library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    ce         : in  std_logic;
    v_dc       : in  signed(15 downto 0); -- fixed point 8
    v_ref      : in  signed(31 downto 0); -- fixed point 16
    v_grid     : in  signed(15 downto 0); -- fixed point 8
    i_meas     : in  signed(15 downto 0); -- fixed point 10
    i_cap      : in  signed(15 downto 0); -- fixed point 10
    b0_alpha   : in  signed(31 downto 0); -- fixed point 28
    b1_alpha   : in  signed(31 downto 0); -- fixed point 28
    b2_alpha   : in  signed(31 downto 0); -- fixed point 28
    b0_beta    : in  signed(31 downto 0); -- fixed point 28
    b1_beta    : in  signed(31 downto 0); -- fixed point 28
    b2_beta    : in  signed(31 downto 0); -- fixed point 28
    a1         : in  signed(31 downto 0); -- fixed point 28
    a2         : in  signed(31 downto 0); -- fixed point 28
    omega      : out signed(31 downto 0); -- fixed point 21
    grid_fault : out std_logic;
    dc_fault   : out std_logic;
    v_out      : out signed(47 downto 0)  -- fixed point 29
  );
end entity top;

architecture Behavioral of top is

  signal grid_error : std_logic;
  signal dc_error   : std_logic;

  signal sogi_v     : signed(31 downto 0);
  signal sogi_qv    : signed(31 downto 0);

  signal ce_slow    : std_logic;

  signal ov1        : std_logic;

begin

  grid_fault <= grid_error;
  dc_fault   <= dc_error;

  u_cascade_control : entity work.cascade_control
    port map (
      clk        => clk,
      rst        => rst,
      ce         => ce_slow,
      v          => sogi_v,
      qv         => sogi_qv,
      v_dc       => v_dc,
      v_ref      => v_ref,
      v_grid     => v_grid,
      i_meas     => i_meas,
      i_cap      => i_cap,
      v_out      => v_out,
      grid_error => grid_error,
      dc_error   => dc_error
    );

  u_adaptive_sogi : entity work.adaptive_sogi
    generic map (
      WIDTH => 16
    )
    port map (
      clk      => clk,
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
      clk   => clk,
      rst   => rst,
      ce    => ce_slow,
      v     => sogi_v,
      qv    => sogi_qv,
      v_n   => v_grid,
      omega => omega
    );

  u_enable_generator : entity work.enable_generator
    generic map (
      COUNT => 200
    )
    port map (
      clk        => clk,
      rst        => rst,
      ce         => ce,
      enable_out => ce_slow
    );

end architecture Behavioral;