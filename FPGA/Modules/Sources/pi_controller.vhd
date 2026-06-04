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
    clk      : in  std_logic;
    rst      : in  std_logic;
    ce       : in  std_logic;
    b0       : in  signed(31 downto 0);
    b1       : in  signed(31 downto 0);
    data_in  : in  signed(31 downto 0); 
    data_out : out signed(31 downto 0)
  );
end entity pi_controller;

architecture Behavioral of pi_controller is

  signal data_in_d : signed(31 downto 0);
  signal u_reg     : signed(66 downto 0);

begin

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then 
        data_in_d <= (others => '0');
      elsif ce = '1' then
        data_in_d <= data_in;
      end if;
    end if;
  end process;

  process(clk)
    variable term0  : signed(63 downto 0);
    variable term1  : signed(63 downto 0);
    variable u_next : signed(66 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        u_reg    <= INIT;
        data_out <= (others => '0');
      elsif ce = '1' then
        term0  := b0 * data_in;          -- FP_DATA + FP_COEFF = 44
        term1  := b1 * data_in_d;        -- FP_DATA + FP_COEFF = 44
        u_next := u_reg + term0 + term1; -- FP_DATA + FP_COEFF = 44, FP_DATA_OUT-(FP_DATA + FP_COEFF-32) = 12
                                       
        if u_next > SATURATION then
          u_reg <= SATURATION;
        elsif u_next < 0 then
          u_reg <= (others => '0');
        else
          u_reg <= u_next;
        end if;  
        
        data_out <= shift_left(u_reg(66 downto 35), FP_DATA_OUT - (FP_DATA_IN + FP_COEFF - 35));                
      end if;
    end if;
  end process;

  --data_out <= shift_left(u_reg(66 downto 35), FP_DATA_OUT - (FP_DATA_IN + FP_COEFF - 35));

end architecture Behavioral;