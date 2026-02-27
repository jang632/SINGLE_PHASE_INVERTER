library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.finish;

entity tb_maf_filter is
end tb_maf_filter;

architecture behavioral of tb_maf_filter is

    constant DATA_WIDTH    : integer := 32;
    constant WINDOW_LENGTH : integer := 500;
    constant FIXED_POINT   : integer := 16;
    
    constant CLK_PERIOD : time := 20 us;
    constant Ts : real := 1.0/50000.0;

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '0';
    signal ce       : std_logic := '0';
    signal data_in  : signed(DATA_WIDTH-1 downto 0) := (others => '0');
    signal data_out : signed(DATA_WIDTH-1 downto 0);

begin

    uut : entity work.MAF_filter
        generic map (
            DATA_WIDTH    => DATA_WIDTH,
            WINDOW_LENGTH => WINDOW_LENGTH,
            FIXED_POINT   => FIXED_POINT
        )
        port map (
            clk      => clk,
            rst      => rst,
            ce       => ce,
            data_in  => data_in,
            data_out => data_out
        );

    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    stim_proc : process
        variable n : integer := 0;
        variable data : real := 0.0;
        variable t    : real := 0.0;
    begin
        rst <= '1';
        ce  <= '0';
        wait for CLK_PERIOD * 5;
        
        wait until rising_edge(clk);
        rst <= '0';
        ce  <= '1';
        
        while n < 240000 loop
        
            t := real(n)*Ts;
            wait until rising_edge(clk) and ce = '1';
            data := sin(5.0 * 2.0 * math_pi * t) + sin(100.0 * 2.0 * math_pi * t); 
            n := n + 1;
            data_in <= to_signed(integer(data*2.0**FIXED_POINT),DATA_WIDTH);
            
        end loop;

        finish;
        wait;
    end process;

end behavioral;