library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pkg is
  type t_array is array (natural range <>) of signed;
end package pkg;

package body pkg is
end package body pkg;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg.all;

entity pi_controller is
  generic (
    INIT        : signed(66 downto 0);
    SATURATION  : signed(66 downto 0);
    FP_DATA_IN  : integer;
    FP_COEFF    : integer;
    FP_DATA_OUT : integer
  );
  port (
    clk         : in  std_logic;
    rst         : in  std_logic;
    ce          : in  std_logic;
    b0          : in  signed(31 downto 0);
    b1          : in  signed(31 downto 0);
    data_in     : in  signed(31 downto 0); 
    data_out    : out signed(31 downto 0)
  );
end entity pi_controller;

architecture behavioral of pi_controller is

  signal d_data_in : signed(31 downto 0);
  signal u         : signed(66 downto 0);

begin

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then 
        d_data_in <= (others => '0');
      elsif ce = '1' then
        d_data_in <= data_in;
      end if;
    end if;
  end process;

  process(clk)
    variable t0     : signed(63 downto 0);
    variable t1     : signed(63 downto 0);
    variable u_temp : signed(66 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        u <= INIT;
      elsif ce = '1' then
        t0     := b0 * data_in;   -- FP_DATA + FP_COEFF = 44
        t1     := b1 * d_data_in; -- FP_DATA + FP_COEFF = 44
        u_temp := u + t0 + t1;    -- FP_DATA + FP_COEFF = 44, FP_DATA_OUT-(FP_DATA + FP_COEFF-32) = 12
                                       
        if u_temp > SATURATION then
          u <= SATURATION;
        elsif u_temp < 0 then
          u <= (others => '0');
        else
          u <= u_temp;
        end if;                  
      end if;
    end if;
  end process;

  data_out <= shift_left(u(66 downto 35), FP_DATA_OUT - (FP_DATA_IN + FP_COEFF - 35));

end architecture behavioral;