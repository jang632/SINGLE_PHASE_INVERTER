library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity cordic_mag is
  generic (
    ITERATIONS : integer := 16
  );
  port (
    clk       : in  std_logic;
    reset     : in  std_logic;
    ce        : in  std_logic;
    x         : in  signed(31 downto 0);
    y         : in  signed(31 downto 0);
    magnitude : out signed(31 downto 0)
  );
end entity cordic_mag;

architecture Behavioral of cordic_mag is

  type cordic_data_t is record
    y : signed(33 downto 0);
    x : signed(33 downto 0);
  end record cordic_data_t;

  type cordic_pipe_t is array (0 to ITERATIONS - 1) of cordic_data_t;
  signal pipeline : cordic_pipe_t;

  signal x_reg : signed(33 downto 0);
  signal y_reg : signed(33 downto 0);

  signal mult_reg : signed(66 downto 0);
  
  constant FIXED_POINT_REAL : real := 2.0**28;
  constant CORDIC_CONST     : signed(31 downto 0) := to_signed(integer(0.60725293500 * FIXED_POINT_REAL), 32);

begin

  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        x_reg <= (others => '0');
        y_reg <= (others => '0');
      elsif ce = '1' then
        x_reg <= abs(resize(x, 34));
        y_reg <= abs(resize(y, 34));
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        pipeline <= (others => (y => (others => '0'), x => (others => '0')));
      elsif ce = '1' then
        pipeline(0).y <= y_reg;
        pipeline(0).x <= x_reg;
        
        for i in 0 to ITERATIONS - 2 loop
          if pipeline(i).y < 0 then
            pipeline(i + 1).y <= pipeline(i).y + shift_right(pipeline(i).x, i);
            pipeline(i + 1).x <= pipeline(i).x - shift_right(pipeline(i).y, i);
          else
            pipeline(i + 1).y <= pipeline(i).y - shift_right(pipeline(i).x, i);
            pipeline(i + 1).x <= pipeline(i).x + shift_right(pipeline(i).y, i);
          end if;
        end loop;
      end if;
    end if;
  end process;

  process(clk)
    variable mult_reg_shift : signed(66 downto 0);
  begin
    if rising_edge(clk) then
      if reset = '1' then
        mult_reg  <= (others => '0');
        magnitude <= (others => '0');
      elsif ce = '1' then
        mult_reg       <= resize(pipeline(ITERATIONS - 1).x, 35) * CORDIC_CONST;
        mult_reg_shift := shift_left(mult_reg, 2);
        magnitude      <= mult_reg_shift(63 downto 32);
      end if;
    end if;
  end process;

end architecture Behavioral;