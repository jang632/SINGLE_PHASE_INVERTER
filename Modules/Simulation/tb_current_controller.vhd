library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use std.env.finish;

entity tb_current_controller is
end tb_current_controller;

architecture Behavioral of tb_current_controller is

    component current_controller
        port(
            clk    : in  std_logic;
            rst    : in  std_logic;
            ce     : in  std_logic;
            theta  : in  signed(31 downto 0);
            v_dc   : in  signed(15 downto 0);
            v_ref  : in  signed(31 downto 0);
            v_grid : in  signed(15 downto 0);
            i_meas : in  signed(15 downto 0);
            v_out  : out signed(47 downto 0)
        );
    end component;

    signal clk    : std_logic := '0';
    signal rst    : std_logic := '1';
    signal ce     : std_logic := '0';
    
    signal theta  : signed(31 downto 0) := (others => '0');
    signal v_dc   : signed(15 downto 0) := (others => '0');
    signal v_ref  : signed(31 downto 0) := (others => '0');
    signal v_grid : signed(15 downto 0) := (others => '0');
    signal i_meas : signed(15 downto 0) := (others => '0');
    
    signal v_out  : signed(47 downto 0);

    constant CLK_PERIOD : time := 20 us;
    constant CE_PERIOD  : time := 20 us;
    
    constant Ts : real := 1.0/50000.0;
    constant L  : real := 4.2/1000;
    constant R  : real := 0.5;
    
begin

    uut: current_controller
        port map (
            clk    => clk,
            rst    => rst,
            ce     => ce,
            theta  => theta,
            v_dc   => v_dc,
            v_ref  => v_ref,
            v_grid => v_grid,
            i_meas => i_meas,
            v_out  => v_out
        );

    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;


   stim_proc: process
        variable n          : integer := 0;
        variable t          : real;
        variable v_inductor : real;
        variable v_inv_safe : signed(47 downto 0);
        variable I_l_k      : real := 0.0; 
        variable P_out      : real := 0.0;
        variable I_cap      : real := 0.0;
        variable V_dc_meas  : real := 380.0; 
        variable P_in       : real := 500.0;
        variable C_dc       : real := 3.0/1000.0;
        
        variable theta_var : real := 0.0;
        variable TWO_PI    : real := 2.0 * math_pi;
        variable THETA_STEP: real := 2.0 * math_pi * 50.0 * Ts;
    begin    
        rst <= '1';
        ce  <= '0';
        wait for 40 us;
        
        wait until rising_edge(clk);
        rst <= '0';
        ce  <= '1';
        
        v_ref <= shift_left(to_signed(400,32),16);
        
        while n < 240000 loop
        
            wait until rising_edge(clk) and ce = '1';
            
            if(n<40000) then
                P_in := 0.0;
            elsif(n<80000) then
                P_in := 1500.0;
            elsif(n<120000) then
                P_in := 2500.0;
            else
                P_in := 500.0;
            end if;

            theta_var := theta_var + THETA_STEP;
            
            if theta_var >= TWO_PI then
                theta_var := theta_var - TWO_PI;
            end if;
                     
            theta <= to_signed(integer(theta_var * (2.0**28)), 32);
            v_grid <= to_signed(integer(325.0*sin(theta_var)*2.0**6),16);
            v_ref  <= shift_left(to_signed(400,32),16);
            v_dc   <= to_signed(integer(V_dc_meas*2.0**6),16);
            i_meas <= to_signed(integer(I_l_k*2.0**10),16);
            
            v_inv_safe := resize(shift_right(v_out, 21), 48);
            v_inductor := real(to_integer(v_inv_safe))/2.0**10 - real(to_integer(v_grid))/2.0**6;        
            I_l_k      := (I_l_k + (Ts/L)*v_inductor)/(1.0 + (R*Ts)/L);      
            P_out      := (real(to_integer(v_grid))/2.0**6)*I_l_k;
            I_cap      := (P_in-P_out)/V_dc_meas;
            V_dc_meas  := V_dc_meas + (I_cap/C_dc)*Ts;
            
            n := n + 1;
            
        end loop;
        
        finish;
        wait;
    end process;
    
    
end Behavioral;