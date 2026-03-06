library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;


library work;
use work.pkg.all;

entity pi_controller is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        ce       : in  std_logic;
        data_in  : in  signed(31 downto 0); -- fp 16
        data_out : out signed(31 downto 0)  -- fp 10
    );
end pi_controller;

architecture Behavioral of pi_controller is

    signal d_data_in : signed(31 downto 0);
    signal v         : signed(64 downto 0);

    constant SATURATION_data_out : signed(31 downto 0) := shift_left(to_signed(25, 32), 10); -- fixed point 10

    constant b0 : signed(31 downto 0) := x"000024b3"; -- fixed point 28, value =  3.5e-5
    constant Kp : signed(31 downto 0) := to_signed(integer((2.0**(28)*0.15)), 32); -- fixed point 28, value =  0.15

    constant W0         : signed(64 downto 0) := shift_left(to_signed(5,65),44);
    constant leak_coeff : signed(31 downto 0) := x"10000000"; -- fixed point 28, value = 0.9995

    function truncate(value_in : signed; limit : signed) return signed is
        variable value_out : signed(value_in'range);
    begin
        if value_in > limit then
            value_out := limit;
        elsif value_in < -limit then
            value_out := -limit;
        else
            value_out := value_in;
        end if;  
        return value_out;
    end function;

begin

    process(clk)
    begin
        if (rising_edge(clk)) then
            if(rst = '1') then 
                d_data_in <= (others => '0');
            else
                if(ce = '1') then
                    d_data_in <= data_in;
                end if;
            end if;
        end if;
    end process;

    process(clk)
        variable t0 : signed(64 downto 0);
        variable u  : signed(64 downto 0);
    begin
        if (rising_edge(clk)) then
            if(rst = '1') then
                v <= W0;
                u := W0;
            else
                if(ce = '1') then
                    t0 := resize(leak_coeff,33)*u(63 downto 32); -- fixed point 40
                    u  := shift_left(t0,4) + b0*(resize(data_in,33)+resize(d_data_in,33)); -- fixed point 44
                    v  <= Kp*resize(data_in,33) + u; -- fixed point 44
                end if;
            end if;
        end if;
    end process;

    data_out <= truncate(value_in => shift_right(v(64 downto 33),1), 
                         limit    => SATURATION_data_out); -- fixed point 44

end Behavioral;