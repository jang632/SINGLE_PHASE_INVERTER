library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity fll is
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;
    ce    : in  std_logic;
    v     : in  signed(31 downto 0); -- fixed point 28
    qv    : in  signed(31 downto 0); -- fixed point 28
    v_n   : in  signed(15 downto 0); -- fixed point 6
    omega : out signed(31 downto 0)  -- fixed point 21
  );
end entity fll;

architecture Behavioral of fll is

  signal d_v_n           : signed(15 downto 0);
  
  signal omega_est       : signed(63 downto 0);
  signal omega_raw       : signed(31 downto 0);
  signal omega_est_shift : signed(63 downto 0);

  constant K      : signed(7 downto 0)  := x"02";                -- fixed point 6
  constant W0     : signed(63 downto 0) := x"4e8a316755129c00";  -- fixed point 54
  constant W0_EMA : signed(31 downto 0) := x"274518b4";          -- fixed point 21

begin

  u_shift_register : entity work.shift_register
    generic map (
      DATA_WIDTH => 16,
      DEPTH      => 1
    )
    port map (
      clk      => clk,
      rst      => rst,
      ce       => ce,
      data_in  => v_n,
      data_out => d_v_n
    );

--  u_uni_shift_register : entity work.uni_shift_register
--    generic map (
--      WIDTH  => 16,
--      LENGTH => 1
--    )
--    port map (
--      clk      => clk,
--      reset    => rst,
--      ce       => ce,
--      data_in  => v_n,
--      data_out => d_v_n
--    );

  u_ema_filter : entity work.ema_filter
    generic map (
      INIT     => W0_EMA,
      STRENGTH => 9
    )
    port map (
      clk      => clk,
      reset    => rst,
      ce       => ce,
      data_in  => omega_raw,
      data_out => omega
    );

  process(clk)
    variable err       : signed(32 downto 0);
    variable v_err_fll : signed(65 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        omega_est <= W0;
      elsif ce = '1' then
        err       := shift_left(resize(d_v_n, 33), 13) - resize(v, 33);
        v_err_fll := err * resize(qv, 33);
        omega_est <= omega_est - shift_left(v_err_fll(65 downto 10) * K, 3);
      end if;
    end if;
  end process;

  omega_est_shift <= shift_right(omega_est, 1);
  omega_raw       <= omega_est_shift(63 downto 32);

end architecture Behavioral;