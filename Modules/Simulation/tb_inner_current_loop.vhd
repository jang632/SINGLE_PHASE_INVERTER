library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use std.env.finish;

entity tb_inner_current_loop is
end tb_inner_current_loop;

architecture Behavioral of tb_inner_current_loop is

    constant CLK_PERIOD : time := 20 us;

    signal clk    : std_logic := '0';
    signal rst    : std_logic := '0';
    signal en     : std_logic := '0';
    signal i_ref  : signed(15 downto 0) := (others => '0');
    signal i_meas : signed(15 downto 0) := (others => '0');
    signal v_grid : signed(15 downto 0) := (others => '0');
    signal v_dc   : signed(31 downto 0) := (others => '0');
    signal v_ref  : signed(47 downto 0);
    
    signal v_inv : signed(47 downto 0);
    
    constant Ts : real := 1.0/50000.0;
    constant L  : real := 4.2/1000;
    constant R  : real := 0.5;
    constant n  : real := 0.0;

begin

    uut : entity work.inner_current_loop
        port map(
            clk    => clk,
            rst    => rst,
            en     => en,
            i_ref  => i_ref,
            i_meas => i_meas,
            v_grid => v_grid,
            v_dc   => v_dc,
            v_ref  => v_inv
        );

    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
    end process;

   stim_process : process
        variable v_inductor : real:= 0.0;
        variable I_l_k : real := 0.0;
        
        variable t : real := 0.0;
        variable amp : real := 0.0;
        variable n : integer := 0;
        
        variable v_inv_safe : signed(31 downto 0);
        constant RAD_CONV : real := math_pi / 180.0;
        variable phi1     : real := 0.0;
        
    begin
        rst <= '1';
        en  <= '0';
        wait for 40 us;
        rst <= '0';
        en  <= '1';
        
        
        while n < 140000 loop
            if n>40000 then 
                phi1 := 133.0 * RAD_CONV;
            else
                phi1 := 0.0;
            end if;
            
            if n<50000 then 
                amp := 25.0;
            elsif n<90000 then
                amp := 0.0;
            else
                amp := 7.0;
            end if;
            
            wait until rising_edge(clk);
            t := real(n)*Ts;
            
            v_grid <= to_signed(integer(325.0*sin(2.0*50.0*math_pi*t + phi1)*2.0**6),16);
            i_ref  <= to_signed(integer(amp *sin(2.0*50.0*math_pi*t + phi1)*2.0**10),16);
            i_meas <= to_signed(integer(I_l_k*2.0**10),16);
    
            v_inv_safe := resize(shift_right(v_inv, 21), 32);
            v_inductor := real(to_integer(v_inv_safe))/2.0**10 - real(to_integer(v_grid))/2.0**6;
            
            I_l_k      := (I_l_k + (Ts/L)*v_inductor)/(1.0 + (R*Ts)/L);
            n := n+1;
        end loop;
       finish;
        wait;
    end process;

end Behavioral;