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

architecture Behavioral of pr_controller is

  constant COEFF_LENGTH : integer := KP'length;
  constant ERROR_LENGTH : integer := error'length;
  constant YR_LENGTH    : integer := COEFF_LENGTH + ERROR_LENGTH + 2;

  constant COEFF_FP : integer := 19;
  constant YR_SLICE : integer := 41;
  constant DEPTH_E  : integer := 2;

  constant SATURATION_U_PR : signed(43 downto 0) := shift_left(to_signed(25, 44), 31);

  signal p_term         : signed(ERROR_LENGTH + COEFF_LENGTH downto 0);
  signal r_term         : signed(YR_LENGTH - 1 downto 0);
  signal r_term_delayed : signed(YR_LENGTH - 1 downto 0);
  signal pr_sum         : signed(YR_LENGTH downto 0);
  signal error_history  : t_array(0 to DEPTH_E - 1)(ERROR_LENGTH - 1 downto 0); -- fixed point 10

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
      LENGTH   => DEPTH_E,
      WIDTH    => ERROR_LENGTH
    )
    port map (
      clk      => clk,
      rst      => rst,
      ce       => ce,
      data_in  => error,
      data_out => error_history
    );

  process(clk)
    variable term_a0 : signed(YR_SLICE + COEFF_LENGTH downto 0);
    variable term_a1 : signed(YR_SLICE + COEFF_LENGTH downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        p_term         <= (others => '0');
        r_term         <= (others => '0');
        pr_sum         <= (others => '0');
        r_term_delayed <= (others => '0');
        data_out       <= (others => '0');
      elsif ce = '1' then
        r_term_delayed <= r_term;
        p_term         <= resize(error, ERROR_LENGTH + 1) * KP; -- fixed point 29

        term_a0 := resize(A0, COEFF_LENGTH + 1) * resize(r_term,         YR_SLICE); -- fixed point 48
        term_a1 := resize(A1, COEFF_LENGTH + 1) * resize(r_term_delayed, YR_SLICE); -- fixed point 48

        r_term <= resize(B0, COEFF_LENGTH + 1) * (resize(error, ERROR_LENGTH + 1) - resize(error_history(1), ERROR_LENGTH + 1))
                  - resize(shift_right(term_a0, COEFF_FP), YR_LENGTH)
                  - resize(shift_right(term_a1, COEFF_FP), YR_LENGTH); -- fixed point 29

        pr_sum <= resize(p_term, YR_LENGTH + 1) + resize(r_term, YR_LENGTH + 1); -- fixed point 29

        data_out <= truncate(data_in => resize(pr_sum, 44), limit => SATURATION_U_PR);
      end if;
    end if;
  end process;

end architecture Behavioral;