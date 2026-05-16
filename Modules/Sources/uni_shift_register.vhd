library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uni_shift_register is
  generic (
    WIDTH  : integer := 32;
    LENGTH : integer := 15
  );
  port (
    clk      : in  std_logic;
    reset    : in  std_logic;
    ce       : in  std_logic;
    data_in  : in  signed(WIDTH - 1 downto 0);
    data_out : out signed(WIDTH - 1 downto 0)
  );
end entity uni_shift_register;

architecture Behavioral of uni_shift_register is

  type delay_array is array (0 to LENGTH - 1) of signed(WIDTH - 1 downto 0);
  signal delay_line : delay_array := (others => (others => '0'));

begin

  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then 
        delay_line <= (others => (others => '0'));
        data_out   <= (others => '0');
      elsif ce = '1' then
        for i in LENGTH - 1 downto 1 loop
          delay_line(i) <= delay_line(i - 1);
        end loop;
        delay_line(0) <= data_in;
        data_out      <= delay_line(LENGTH - 1);
      end if;
    end if;
  end process;

end architecture Behavioral;