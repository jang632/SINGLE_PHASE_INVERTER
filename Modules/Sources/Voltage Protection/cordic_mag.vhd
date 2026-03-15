library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cordic_mag is
    generic (
        iterations : integer := 16
    );
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        ce        : in  std_logic;
        x         : in  signed(31 downto 0);
        y         : in  signed(31 downto 0);
        magnitude : out signed(31 downto 0)
    );
end cordic_mag;

architecture Behavioral of cordic_mag is

    type pipelined_io is record
        pip_y : signed(33 downto 0);
        pip_x : signed(33 downto 0);
    end record;

    type pipe_stages is array (0 to iterations - 1) of pipelined_io;
    signal pipeline : pipe_stages;

    signal x_reg : signed(33 downto 0);
    signal y_reg : signed(33 downto 0);

    signal mult_reg : signed(66 downto 0);

    constant CORDIC_CONST : signed(31 downto 0) := x"09B74EDB";

begin

    process(clk)
    begin
        if(rising_edge(clk)) then
            if(reset = '1') then
                x_reg <= (others => '0');
                y_reg <= (others => '0');
            elsif(ce = '1') then
                x_reg <= abs(resize(x, 34));
                y_reg <= abs(resize(y, 34));
            end if;
        end if;
    end process;

    process(clk)
    begin
        if(rising_edge(clk)) then
            if(reset = '1') then
                pipeline <= (others => (pip_y => (others => '0'), pip_x => (others => '0')));
            elsif(ce = '1') then
                pipeline(0).pip_y <= y_reg;
                pipeline(0).pip_x <= x_reg;
                
                for i in 0 to iterations - 2 loop
                    if(pipeline(i).pip_y < 0) then
                        pipeline(i+1).pip_y <= pipeline(i).pip_y + shift_right(pipeline(i).pip_x, i);
                        pipeline(i+1).pip_x <= pipeline(i).pip_x - shift_right(pipeline(i).pip_y, i);
                    else
                        pipeline(i+1).pip_y <= pipeline(i).pip_y - shift_right(pipeline(i).pip_x, i);
                        pipeline(i+1).pip_x <= pipeline(i).pip_x + shift_right(pipeline(i).pip_y, i);
                    end if;
                end loop;
            end if;
        end if;
    end process;

    process(clk)
        variable mult_reg_shift : signed(66 downto 0);
    begin
        if(rising_edge(clk)) then
            if(reset = '1') then
                mult_reg  <= (others => '0');
                magnitude <= (others => '0');
            elsif(ce = '1') then
                mult_reg       <= resize(pipeline(iterations - 1).pip_x, 35) * CORDIC_CONST;
                mult_reg_shift := shift_left(mult_reg, 2);
                magnitude      <= mult_reg_shift(63 downto 32);
            end if;
        end if;
    end process;

end Behavioral;