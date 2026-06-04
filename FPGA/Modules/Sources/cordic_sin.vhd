library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cordic_sin_cos is
  generic (
    ITERATIONS : integer;
    WIDTH      : integer := 16;
    OUT_FP     : integer := 14
  );
  port (
    clk       : in  std_logic;
    reset     : in  std_logic;
    ce        : in  std_logic;
    theta     : in  signed(31 downto 0);
    sin_value : out signed(WIDTH - 1 downto 0);
    cos_value : out signed(WIDTH - 1 downto 0)
  );
end entity cordic_sin_cos;

architecture Behavioral of cordic_sin_cos is

  type cordic_data_t is record
    theta    : signed(31 downto 0);
    sin_val  : signed(WIDTH - 1 downto 0);
    cos_val  : signed(WIDTH - 1 downto 0);
    quadrant : std_logic_vector(1 downto 0);
  end record cordic_data_t;

  type cordic_pipe_t is array (0 to 15) of cordic_data_t;
  signal pipeline : cordic_pipe_t;
  
  constant FIXED_POINT_REAL : real := 2.0**28;
  constant FIXED_POINT_OUT   : real := 2.0**OUT_FP;

  constant PI_OVER_2       : signed(31 downto 0)        := to_signed(integer(1.57079632679 * FIXED_POINT_REAL), 32);
  constant PI              : signed(31 downto 0)        := to_signed(integer(3.14159265359 * FIXED_POINT_REAL), 32);
  constant THREE_PI_OVER_2 : signed(31 downto 0)        := to_signed(integer(4.71238898038 * FIXED_POINT_REAL), 32);
  constant TWO_PI          : signed(31 downto 0)        := to_signed(integer(6.28318530718 * FIXED_POINT_REAL), 32);
  
  constant CORDIC_CONST    : signed(WIDTH - 1 downto 0) := to_signed(integer(0.60725293500 * FIXED_POINT_OUT),   WIDTH);

  type angle_array_t is array (0 to 15) of signed(31 downto 0);

  constant ANGLES : angle_array_t := (
    0  => to_signed(integer(0.78539816339744830 * FIXED_POINT_REAL), 32),
    1  => to_signed(integer(0.46364760900080610 * FIXED_POINT_REAL), 32),
    2  => to_signed(integer(0.24497866312686414 * FIXED_POINT_REAL), 32),
    3  => to_signed(integer(0.12435499454676144 * FIXED_POINT_REAL), 32),
    4  => to_signed(integer(0.06241880999595735 * FIXED_POINT_REAL), 32),
    5  => to_signed(integer(0.03123983343026828 * FIXED_POINT_REAL), 32),
    6  => to_signed(integer(0.01562372862047683 * FIXED_POINT_REAL), 32),
    7  => to_signed(integer(0.00781234106010111 * FIXED_POINT_REAL), 32),
    8  => to_signed(integer(0.00390623013196697 * FIXED_POINT_REAL), 32),
    9  => to_signed(integer(0.00195312251647882 * FIXED_POINT_REAL), 32),
    10 => to_signed(integer(0.00097656218955932 * FIXED_POINT_REAL), 32),
    11 => to_signed(integer(0.00048828121119490 * FIXED_POINT_REAL), 32),
    12 => to_signed(integer(0.00024414062014936 * FIXED_POINT_REAL), 32),
    13 => to_signed(integer(0.00012207031189367 * FIXED_POINT_REAL), 32),
    14 => to_signed(integer(0.00006103515617421 * FIXED_POINT_REAL), 32),
    15 => to_signed(integer(0.00003051757811553 * FIXED_POINT_REAL), 32)
  );

begin

  process(clk)
  begin 
    if rising_edge(clk) then
      if reset = '1' then
        pipeline <= (others => (theta => (others => '0'), sin_val => (others => '0'), cos_val => (others => '0'), quadrant => (others => '0')));
      elsif ce = '1' then
        if theta < PI_OVER_2 then
          pipeline(0).theta    <= theta;
          pipeline(0).quadrant <= "00";
        elsif theta <= PI then
          pipeline(0).theta    <= PI - theta;
          pipeline(0).quadrant <= "01";
        elsif theta <= THREE_PI_OVER_2 then
          pipeline(0).theta    <= theta - PI;
          pipeline(0).quadrant <= "10";
        elsif theta <= TWO_PI then
          pipeline(0).theta    <= TWO_PI - theta;
          pipeline(0).quadrant <= "11";
        else
          pipeline(0).theta    <= (others => '0');
          pipeline(0).quadrant <= "00";
        end if;

        pipeline(0).cos_val <= CORDIC_CONST;
        pipeline(0).sin_val <= (others => '0');

        for i in 0 to ITERATIONS - 2 loop
          if pipeline(i).theta < 0 then
            pipeline(i + 1).cos_val  <= pipeline(i).cos_val + shift_right(pipeline(i).sin_val, i);
            pipeline(i + 1).sin_val  <= pipeline(i).sin_val - shift_right(pipeline(i).cos_val, i);
            pipeline(i + 1).quadrant <= pipeline(i).quadrant;
            pipeline(i + 1).theta    <= pipeline(i).theta + ANGLES(i);
          else
            pipeline(i + 1).sin_val  <= pipeline(i).sin_val + shift_right(pipeline(i).cos_val, i);
            pipeline(i + 1).cos_val  <= pipeline(i).cos_val - shift_right(pipeline(i).sin_val, i);
            pipeline(i + 1).quadrant <= pipeline(i).quadrant;
            pipeline(i + 1).theta    <= pipeline(i).theta - ANGLES(i);
          end if;
        end loop;
      end if;
    end if;
  end process;

  process(pipeline(ITERATIONS - 1).sin_val, pipeline(ITERATIONS - 1).cos_val, pipeline(ITERATIONS - 1).quadrant)
  begin
    case pipeline(ITERATIONS - 1).quadrant is
      when "00" =>
        sin_value <=  pipeline(ITERATIONS - 1).sin_val;
        cos_value <=  pipeline(ITERATIONS - 1).cos_val;
      when "01" =>
        sin_value <=  pipeline(ITERATIONS - 1).sin_val;
        cos_value <= -pipeline(ITERATIONS - 1).cos_val;
      when "10" =>
        sin_value <= -pipeline(ITERATIONS - 1).sin_val;
        cos_value <= -pipeline(ITERATIONS - 1).cos_val;
      when others =>
        sin_value <= -pipeline(ITERATIONS - 1).sin_val;
        cos_value <=  pipeline(ITERATIONS - 1).cos_val;
    end case;
  end process;

end architecture Behavioral;