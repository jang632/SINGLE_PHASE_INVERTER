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

entity pi_controller is
port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    ce       : in  std_logic;
    b0       : in  signed(31 downto 0);
    b1       : in  signed(31 downto 0);
    data_in  : in  signed(31 downto 0);
    data_out : out signed(31 downto 0)
);
end pi_controller;

architecture behavioral of pi_controller is

    signal d_data_in : signed(31 downto 0);
    signal u         : signed(63 downto 0);

    constant W0         : signed(63 downto 0) := x"0013a28c59d544a7";

begin

    process(clk)
    begin
        if (rising_edge(clk)) then
            if (rst = '1') then 
                d_data_in <= (others => '0');
            else
                if (ce = '1') then
                    d_data_in <= data_in;
                end if;
            end if;
        end if;
    end process;

    process(clk)
        variable t0 : signed(63 downto 0);
        variable t1 : signed(63 downto 0);
        variable t3 : signed(63 downto 0);
    begin
        if (rising_edge(clk)) then
            if (rst = '1') then
                u <= W0;
            else
                if (ce = '1') then
                    t0 := b0 * data_in;
                    t1 := b1 * d_data_in;
                    u  <= u + t0 + t1;
                end if;
            end if;
        end if;
    end process;

    data_out <= shift_left(u(63 downto 32), 8);

end behavioral;