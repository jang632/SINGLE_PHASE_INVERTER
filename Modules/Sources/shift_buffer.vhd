library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;


library work;
use work.pkg.all;

entity shift_buffer is
    generic(
        DATA_WIDTH  : integer := 32;
        FIXED_POINT : integer := 16;
        INIT        : real := 0.0;
        DEPTH       : integer := 4
    );
    port(
        clk      : in  std_logic;
        rst      : in  std_logic;
        ce       : in  std_logic;
        data_in  : in  signed(DATA_WIDTH-1 downto 0);
        data_out : out t_array(0 to DEPTH-1)(DATA_WIDTH-1 downto 0)
    );
end shift_buffer;

architecture Behavioral of shift_buffer is
    signal r_data_out : t_array(0 to DEPTH-1)(DATA_WIDTH-1 downto 0) := (others => (others => '0'));
    constant val_init : signed(DATA_WIDTH-1 downto 0) := to_signed(integer(INIT*2.0**(FIXED_POINT)),DATA_WIDTH);
begin

process(clk)
    variable i : integer;
begin
    if(rising_edge(clk)) then 
        if(rst = '1') then
            for i in DEPTH-1 downto 0 loop
                r_data_out(i) <= val_init;
            end loop;
        else
            if(ce = '1') then
                r_data_out(0) <= data_in;
                for i in DEPTH-1 downto 1 loop
                    r_data_out(i) <= r_data_out(i-1);
                end loop;
            end if;
        end if;
    end if;
end process;

data_out <= r_data_out;

end Behavioral;
