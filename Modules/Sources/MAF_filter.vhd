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

architecture behavioral of maf_filter is

  signal s     : signed(DATA_WIDTH + 8 downto 0);
  signal x_mem : t_array(0 to WINDOW_LENGTH - 1)(DATA_WIDTH - 1 downto 0);
  
  constant ONE_OVER_N : signed(DATA_WIDTH - 1 downto 0) := to_signed(integer((2.0**16 / real(WINDOW_LENGTH))), DATA_WIDTH);
  constant INIT       : signed(DATA_WIDTH - 1 downto 0) := shift_left(to_signed(48, 16), 8);

begin
  
  u_shift_buffer : entity work.shift_buffer
    generic map (
      LENGTH   => WINDOW_LENGTH,
      WIDTH    => DATA_WIDTH,
      INIT     => INIT
    )
    port map (
      clk      => clk,
      rst      => rst,
      ce       => ce,
      data_in  => data_in,
      data_out => x_mem
    );

  process(clk)
    variable v0 : signed(2 * DATA_WIDTH + 8 downto 0);
    variable v1 : signed(2 * DATA_WIDTH + 8 downto 0);
  begin
    if rising_edge(clk) then 
      if rst = '1' then 
        s        <= shift_left(to_signed(24000, 25), 8);
        v0       := (others => '0');
        v1       := (others => '0');
        data_out <= shift_left(to_signed(48, 16), 8);
      elsif ce = '1' then
        s        <= s + resize(data_in, DATA_WIDTH + 9) - resize(x_mem(WINDOW_LENGTH - 1), DATA_WIDTH + 9); -- fixed point 9
        v0       := s * ONE_OVER_N;                                                                         -- fixed point 25
        v1       := shift_left(v0, FIXED_POINT + 1);                                                        -- fixed point 34
        data_out <= v1(2 * DATA_WIDTH + 8 downto DATA_WIDTH + 9);
      end if;
    end if;
  end process;

end architecture behavioral;