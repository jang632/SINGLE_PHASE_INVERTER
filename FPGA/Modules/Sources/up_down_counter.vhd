library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;
use ieee.numeric_std.all;

entity up_down_counter is
  generic (
    WIDTH : integer := 8
  );
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;
    output : out signed(WIDTH - 1 downto 0)
  );
end entity up_down_counter;

architecture Behavioral of up_down_counter is 
  
  signal counter : signed(WIDTH - 1 downto 0);  
  signal dir     : std_logic;
  
  constant STEP      : integer                    := 1;                      
  constant MAX_COUNT : signed(15 downto 0)        := to_signed(2500, 16);
  constant MIN_COUNT : signed(WIDTH - 1 downto 0) := to_signed(-2500, 16); 
  
begin

  process(clk) 
  begin
    if rising_edge(clk) then
      if rst = '1' then 
        counter <= (others => '0');
        output  <= (others => '0');
        dir     <= '0';
      else
        if dir = '0' then 
          counter <= counter + STEP;
          if counter = MAX_COUNT - STEP then 
            dir <= '1';
          else
            dir <= '0';
          end if;
        elsif dir = '1' then
          counter <= counter - STEP;
          if counter = MIN_COUNT + STEP then 
            dir <= '0';
          else
            dir <= '1';
          end if;
        end if; 
      end if;
      output <= counter; 
    end if;
  end process;   
        
end architecture Behavioral;