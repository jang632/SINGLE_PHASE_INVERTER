library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ema_filter IS
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        ce       : in  std_logic;
        data_in  : in  signed(31 downto 0);
        data_out : out signed (31 downto 0)
    );
end ema_filter;

architecture Behavioral of ema_filter is

    type pipeline is array (0 to 1) of signed(31 downto 0);
    signal ema_val : signed(31 downto 0) := (others => '0');

begin
    process(clk)
    begin
        if(reset = '1') then
            ema_val  <= (others => '0');
            data_out <= (others => '0');
        elsif rising_edge(clk) then
            if(ce = '1') then
                ema_val  <= ema_val + shift_right(data_in - ema_val, 9);
                data_out <= ema_val;
            end if;
        end if;
    end process;

end Behavioral;
