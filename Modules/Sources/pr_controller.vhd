library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.pkg.all;

entity pr_controller is
  generic (
    KP : signed(21 downto 0); -- fixed point 19
    B0 : signed(21 downto 0); -- fixed point 19
    A0 : signed(21 downto 0); -- fixed point 19
    A1 : signed(21 downto 0)  -- fixed point 19
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    ce       : in  std_logic;
    error    : in  signed(16 downto 0); -- fixed point 10
    data_out : out signed(43 downto 0)  -- fixed point 29
  );
end entity pr_controller;

architecture behavioral of pr_controller is

  constant coeff_length : integer := KP'length;
  constant error_length : integer := error'length;
  constant yr_length    : integer := coeff_length + error_length + 2;

  constant coeff_fp     : integer := 19;
  constant yr_slice     : integer := 41;
  constant DEPTH_e      : integer := 2;

  constant SATURATION_u_pr : signed(43 downto 0) := shift_left(to_signed(25, 44), 31);

  signal yp      : signed(error_length + coeff_length downto 0);
  signal yr      : signed(yr_length - 1 downto 0);
  signal d_yr    : signed(yr_length - 1 downto 0);
  signal u_pr    : signed(yr_length downto 0);
  signal d_error : t_array(0 to DEPTH_e - 1)(error_length - 1 downto 0); -- fixed point 10

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

  u_shift_buffer : entity work.shift_buffer
    generic map (
      LENGTH   => DEPTH_e,
      WIDTH    => error_length
    )
    port map (
      clk      => clk,
      rst      => rst,
      ce       => ce,
      data_in  => error,
      data_out => d_error
    );

  process(clk)
    variable v1 : signed(yr_slice + coeff_length downto 0);
    variable v2 : signed(yr_slice + coeff_length downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        yp       <= (others => '0');
        yr       <= (others => '0');
        u_pr     <= (others => '0');
        d_yr     <= (others => '0');
        data_out <= (others => '0');
      elsif ce = '1' then
        d_yr <= yr;
        yp   <= resize(error, error_length + 1) * KP; -- fixed point 29

        v1   := resize(A0, coeff_length + 1) * resize(yr,   yr_slice); -- fixed point 48
        v2   := resize(A1, coeff_length + 1) * resize(d_yr, yr_slice); -- fixed point 48

        yr   <= resize(B0, coeff_length + 1) * (resize(error, error_length + 1) - resize(d_error(1), error_length + 1))
                - resize(shift_right(v1, coeff_fp), yr_length)
                - resize(shift_right(v2, coeff_fp), yr_length); -- fixed point 29

        u_pr <= resize(yp, yr_length + 1) + resize(yr, yr_length + 1); -- fixed point 29

        data_out <= truncate(data_in => resize(u_pr, 44), limit => SATURATION_u_pr);
      end if;
    end if;
  end process;

end architecture behavioral;