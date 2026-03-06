
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package pkg is
  type t_array is array (natural range <>) of signed;
end package;

package body pkg is
end package body;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.pkg.all;

entity shift_buffer is
generic(
    LENGTH : integer := 3;
    WIDTH  : integer := 8
);
port(
    clk      : in std_logic;
    rst      : in std_logic;
    ce       : in std_logic;
    data_in  : in signed(WIDTH-1 downto 0);
    data_out : out t_array(0 to LENGTH-1)(WIDTH-1 downto 0)
);   
end shift_buffer;

architecture Behavioral of shift_buffer is
    signal data_buffer : t_array(0 to LENGTH-1)(WIDTH-1 downto 0);
begin
    
    data_out <= data_buffer;

    PROCESS(clk)
    BEGIN 
        if(rising_edge(clk)) then 
            if(rst = '1') then 
                data_buffer <= (OTHERS => (OTHERS => '0'));
            else
                if(ce = '1') then
                    data_buffer(0) <= data_in;
                    for i in LENGTH-1 downto 1 loop
                      data_buffer(i) <= data_buffer(i-1);
                    end loop;
                end if;
            end if;
        end if;
    END PROCESS;
end Behavioral;
