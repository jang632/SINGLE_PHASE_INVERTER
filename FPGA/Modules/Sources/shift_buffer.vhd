library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pkg is
  type signed_array_t is array (natural range <>) of signed;
end package pkg;

package body pkg is
end package body pkg;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg.all;

entity shift_buffer is
  generic (
    LENGTH : integer                    := 3;
    WIDTH  : integer                    := 8;
    INIT   : signed(WIDTH - 1 downto 0) := (others => '0')
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    ce       : in  std_logic;
    data_in  : in  signed(WIDTH - 1 downto 0);
    data_out : out signed_array_t(0 to LENGTH - 1)(WIDTH - 1 downto 0)
  );   
end entity shift_buffer;

architecture Behavioral of shift_buffer is

  signal shift_reg : signed_array_t(0 to LENGTH - 1)(WIDTH - 1 downto 0);

begin

  process(clk)
  begin 
    if rising_edge(clk) then 
      if rst = '1' then 
        shift_reg <= (others => INIT);
      elsif ce = '1' then
        shift_reg(0) <= data_in;
        for i in LENGTH - 1 downto 1 loop
          shift_reg(i) <= shift_reg(i - 1);
        end loop;
      end if;
    end if;
  end process;

  data_out <= shift_reg;

end architecture Behavioral;