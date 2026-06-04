library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.pkg.all;

entity maf_filter is
  generic (
    DATA_WIDTH    : integer := 16;
    WINDOW_LENGTH : integer := 500;
    FIXED_POINT   : integer := 6
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    ce       : in  std_logic;
    data_in  : in  signed(DATA_WIDTH - 1 downto 0);
    data_out : out signed(DATA_WIDTH - 1 downto 0)
  );
end entity maf_filter;

architecture Behavioral of maf_filter is

  signal acc_reg : signed(DATA_WIDTH + 8 downto 0);
  signal x_mem   : t_array(0 to WINDOW_LENGTH - 1)(DATA_WIDTH - 1 downto 0);
  
  constant ONE_OVER_N : signed(DATA_WIDTH - 1 downto 0) := to_signed(integer(2.0**16 / real(WINDOW_LENGTH)), DATA_WIDTH);
  constant INIT_VAL   : signed(DATA_WIDTH - 1 downto 0) := shift_left(to_signed(48, 16), 8);

begin
  
  u_shift_buffer : entity work.shift_buffer
    generic map (
      LENGTH => WINDOW_LENGTH,
      WIDTH  => DATA_WIDTH,
      INIT   => INIT_VAL
    )
    port map (
      clk      => clk,
      rst      => rst,
      ce       => ce,
      data_in  => data_in,
      data_out => x_mem
    );

  process(clk)
    variable mult_val         : signed(2 * DATA_WIDTH + 8 downto 0);
    variable mult_val_shifted : signed(2 * DATA_WIDTH + 8 downto 0);
  begin
    if rising_edge(clk) then 
      if rst = '1' then 
        acc_reg          <= shift_left(to_signed(24000, 25), 8);
        mult_val         := (others => '0');
        mult_val_shifted := (others => '0');
        data_out         <= shift_left(to_signed(48, 16), 8);
      elsif ce = '1' then
        acc_reg          <= acc_reg + resize(data_in, DATA_WIDTH + 9) - resize(x_mem(WINDOW_LENGTH - 1), DATA_WIDTH + 9); -- fixed point 9
        mult_val         := acc_reg * ONE_OVER_N;                                                                         -- fixed point 25
        mult_val_shifted := shift_left(mult_val, FIXED_POINT + 1);                                                        -- fixed point 34
        data_out         <= mult_val_shifted(2 * DATA_WIDTH + 8 downto DATA_WIDTH + 9);
      end if;
    end if;
  end process;

end architecture Behavioral;