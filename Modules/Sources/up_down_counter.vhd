library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.MATH_REAL.ALL;
use IEEE.NUMERIC_STD.ALL;

entity up_down_counter is
    generic (
        WIDTH             : integer := 8;
        MAX_RANGE         : integer := 126;
        CARRIER_FREQUENCY : integer := 20000;
        CLK_FREQ          : integer := 50000000
    );
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        output : out signed(WIDTH-1 downto 0)
    );
end up_down_counter;

architecture Behavioral of up_down_counter is 
    signal counter : signed(WIDTH-1 downto 0);  
    signal dir     : std_logic;
    
    constant step      : integer                  := (2*MAX_RANGE*CARRIER_FREQUENCY)/CLK_FREQ;                     
    constant MAX_COUNT : signed(15 downto 0)      := to_signed((MAX_RANGE/step)*step, WIDTH);
    constant MIN_COUNT : signed(WIDTH-1 downto 0) := -MAX_COUNT; 
begin
    PROCESS(clk) 
    begin
        if rising_edge(clk) then
            if rst = '1' then 
                counter <= (OTHERS => '0');
                output  <= (OTHERS => '0');
                dir     <= '0';
            else
                if dir = '0' then 
                    counter <= counter + step;
                    if counter = MAX_COUNT-step then 
                        dir <= '1';
                    else
                        dir <= '0';
                    end if;
                elsif dir = '1' then
                    counter <= counter - step;
                    if counter = MIN_COUNT+step then 
                        dir <= '0';
                    else
                        dir <= '1';
                    end if;
                end if; 
            end if;
            output <= counter; 
        end if;
    END PROCESS;   
        
end Behavioral;
