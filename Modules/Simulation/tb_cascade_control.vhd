library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use std.env.finish;

entity tb_cascade_control is
end tb_cascade_control;

architecture Behavioral of tb_cascade_control is

    component cascade_control
        port(
            clk    : in  std_logic;
            rst    : in  std_logic;
            ce     : in  std_logic;
            v_dc   : in  signed(15 downto 0);
            v_ref  : in  signed(31 downto 0);
            v_grid : in  signed(15 downto 0);
            i_meas : in  signed(15 downto 0);
            i_cap  : in  signed(15 downto 0);
            v_out  : out signed(47 downto 0)
        );
    end component;

    signal clk    : std_logic := '0';
    signal rst    : std_logic := '1';
    signal ce     : std_logic := '0';
    
    signal v_dc   : signed(15 downto 0) := (others => '0');
    signal v_ref  : signed(31 downto 0) := (others => '0');
    signal v_grid : signed(15 downto 0) := (others => '0');
    signal i_meas : signed(15 downto 0) := (others => '0');
    signal i_cap  : signed(15 downto 0) := (others => '0');

    signal v_out  : signed(47 downto 0);

    constant CLK_PERIOD : time := 20 us;
    constant CE_PERIOD  : time := 20 us;
    
    constant Ts : real := 1.0 / 50000.0;
    
    constant L1 : real := 3.3 / 10000.0; 
    constant R1 : real := 0.1;           
    constant L2 : real := 1.5 / 10000.0; 
    constant R2 : real := 0.1;           
    constant Cf : real := 10.0 / 1000000.0; 
    constant Rd : real := 2.0;          
    
begin

    uut: cascade_control
        port map (
            clk    => clk,
            rst    => rst,
            ce     => ce,
            v_dc   => v_dc,
            v_ref  => v_ref,
            v_grid => v_grid,
            i_meas => i_meas,
            i_cap  => i_cap,
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

        function to_real_scaled(val : signed(47 downto 0); scale : real) return real is
            variable tmp : real := 0.0;
        begin
            for i in 0 to 46 loop
                if val(i) = '1' then
                    tmp := tmp + (2.0**i);
                end if;
            end loop;
            if val(47) = '1' then
                tmp := tmp - (2.0**47); 
            end if;
            return tmp / scale;
        end function;

        variable n : integer := 0;
        
        variable I_L1_k     : real := 0.0; 
        variable I_L2_k     : real := 0.0;
        variable V_cf_k     : real := 0.0;
        variable V_C_branch : real := 0.0;
        
        variable u_inv_real : real := 0.0;
        variable v_grid_real: real := 0.0;
        
        variable P_out      : real := 0.0;
        variable I_cap      : real := 0.0;
        variable V_dc_meas  : real := 380.0; 
        variable P_in       : real := 0.0;
        variable C_dc       : real := 3.0 / 1000.0;
        
        variable theta_var      : real := 0.0;
        variable TWO_PI         : real := 2.0 * math_pi;
        variable THETA_STEP     : real := 2.0 * math_pi * 50.0 * Ts;
        
        variable pwm_enabled    : boolean := false;
        
    begin   
        rst <= '1';
        ce  <= '0';
        wait for 40 us;
        
        wait until rising_edge(clk);
        rst <= '0';
        ce  <= '1';
        
        v_ref <= to_signed(integer(400.0 * 2.0**16), 32); 
        
        while n < 240000 loop
        
            wait until rising_edge(clk) and ce = '1';
            
            if n < 60000 then
                P_in :=10.0;
            elsif n < 100000 then
                P_in := 1500.0;
            elsif n < 140000 then
                P_in := 3000.0;
            else
                P_in := 500.0;
            end if;

            theta_var := theta_var + THETA_STEP;
            if theta_var >= TWO_PI then
                theta_var := theta_var - TWO_PI;
            end if;
                      
            v_grid_real := 325.0 * (sin(theta_var) + 0.1*sin(3*theta_var));
            v_grid      <= to_signed(integer(v_grid_real * 2.0**6), 16);
            
            i_meas <= to_signed(integer(I_L2_k * 2.0**10), 16);
            
            v_dc <= to_signed(integer(V_dc_meas * 2.0**6), 16);
            
            u_inv_real := to_real_scaled(v_out, 2.0**29);
            
            if u_inv_real /= 0.0 then
                pwm_enabled := true;
            end if;

            if not pwm_enabled then
                I_L1_k := 0.0;
                I_L2_k := 0.0;
                V_cf_k := v_grid_real; 
                
            else
                if u_inv_real > V_dc_meas then
                    u_inv_real := V_dc_meas;
                elsif u_inv_real < -V_dc_meas then
                    u_inv_real := -V_dc_meas;
                end if;

                V_C_branch := V_cf_k + Rd * (I_L1_k - I_L2_k);
                    
                I_L1_k := I_L1_k + (Ts) * (u_inv_real - I_L1_k * R1 - V_C_branch) / L1;
                I_L2_k := I_L2_k + (Ts) * (V_C_branch - I_L2_k * R2 - v_grid_real) / L2;
                V_cf_k := V_cf_k + (Ts) * (I_L1_k - I_L2_k) / Cf;
            
                P_out      := v_grid_real * I_L2_k;
                I_cap      := (P_in - P_out) / V_dc_meas;
                V_dc_meas  := V_dc_meas + (I_cap / C_dc) * Ts;
            end if;
            
            n := n + 1;
            
        end loop;
        
        finish;
        wait;
    end process;
    
end Behavioral;