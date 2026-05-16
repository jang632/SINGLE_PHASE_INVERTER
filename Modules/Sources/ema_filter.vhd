library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ema_filter is
  generic (
    INIT     : signed(31 downto 0);
    STRENGTH : integer
  );
  port (
    clk      : in  std_logic;
    reset    : in  std_logic;
    ce       : in  std_logic;
    data_in  : in  signed(31 downto 0);
    data_out : out signed(31 downto 0)
  );
end entity ema_filter;

architecture Behavioral of ema_filter is

  signal ema_val : signed(31 downto 0) := INIT;

begin
  
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        ema_val <= INIT;
      elsif ce = '1' then
        ema_val <= ema_val + shift_right(data_in - ema_val, STRENGTH);
      end if;
    end if;
  end process;
  
  data_out <= ema_val;

end architecture Behavioral;