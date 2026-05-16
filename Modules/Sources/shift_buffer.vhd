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
    data_out : out t_array(0 to LENGTH - 1)(WIDTH - 1 downto 0)
  );   
end entity shift_buffer;

architecture behavioral of shift_buffer is

  signal data_buffer_s : t_array(0 to LENGTH - 1)(WIDTH - 1 downto 0);

begin
  
  data_out <= data_buffer_s;

  process(clk)
  begin 
    if rising_edge(clk) then 
      if rst = '1' then 
        data_buffer_s <= (others => INIT);
      elsif ce = '1' then
        data_buffer_s(0) <= data_in;
        for i in LENGTH - 1 downto 1 loop
          data_buffer_s(i) <= data_buffer_s(i - 1);
        end loop;
      end if;
    end if;
  end process;

end architecture behavioral;