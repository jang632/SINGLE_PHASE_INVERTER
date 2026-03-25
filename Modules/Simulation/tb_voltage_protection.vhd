library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity tb_voltage_protection is
end entity;

architecture Behavioral of tb_voltage_protection is

    constant WIDTH : integer := 16;

    constant FS       : real := 50000.0;
    constant F_SIGNAL : real := 52.0; 

    constant CLK_PER      : time := 20 us;
    constant CLK_FAST_PER : time := 100 ns;
    
    constant AMP      : real := 0.7812738426 * 0.8125;

    constant H3_AMP   : real := 0.05;
    constant H5_AMP   : real := 0.06;
    constant H7_AMP   : real := 0.05;
    constant H14_AMP  : real := 0.01;

    constant ADC_MAX  : real := 2.0**(WIDTH - 1) - 1.0;

    signal clk      : std_logic := '0';
    signal clk_fast : std_logic := '0';
    signal rst      : std_logic := '0';
    signal ce       : std_logic := '1';
    
    signal ov1_out : std_logic;
    signal ov2_out : std_logic;
    signal uv1_out : std_logic;
    signal uv2_out : std_logic;

    signal b0_alpha : signed(31 downto 0) := (others => '0');
    signal b2_alpha : signed(31 downto 0) := (others => '0');
    signal b0_beta  : signed(31 downto 0) := (others => '0');
    signal b1_beta  : signed(31 downto 0) := (others => '0');
    signal b2_beta  : signed(31 downto 0) := (others => '0');
    signal a1       : signed(31 downto 0) := (others => '0');
    signal a2       : signed(31 downto 0) := (others => '0');
    signal omega    : signed(31 downto 0) := (others => '0');

    signal v_n      : signed(WIDTH - 1 downto 0) := (others => '0');
    
begin

    uut : entity work.voltage_protection
        port map (
            clk      => clk_fast,
            rst      => rst,
            ce       => ce,
            b0_alpha => b0_alpha,
            b2_alpha => b2_alpha,
            b0_beta  => b0_beta,
            b1_beta  => b1_beta,
            b2_beta  => b2_beta,
            a1       => a1,
            a2       => a2,
            v_n      => v_n,
            omega    => omega,
            ov1      => ov1_out,
            ov2      => ov2_out,
            uv1      => uv1_out,
            uv2      => uv2_out
        );

    clk      <= not clk after CLK_PER / 2;
    clk_fast <= not clk_fast after CLK_FAST_PER / 2;

    process
        variable n       : integer := 0;
        variable t       : real;
        variable v_real  : real;
        variable v_int   : integer;
        variable amp_mod : real := 1.0; 

        variable f0    : real := 50.0; 
        variable K_val : real := 0.5 * sqrt(2.0);
        variable Ts    : real := 1.0 / FS;
        variable w0    : real;
        variable x, y, D, inv_D, ky : real;
        
        variable v_b0_alpha, v_b2_alpha : real;
        variable v_b0_beta, v_b1_beta, v_b2_beta : real;
        variable v_a1, v_a2 : real;
        
        constant SCALE_Q28 : real := 2.0**28;

    begin
        rst <= '1';
        ce  <= '1';
        v_n <= (others => '0');

        wait for 10 * CLK_PER;
        rst <= '0';

        while n < 400000 loop

            wait until rising_edge(clk);

            if(n mod 250 = 0) then
                w0    := real(to_integer(omega)) / 2.0**21; 
                x     := 2.0 * K_val * w0 * Ts;
                y     := (w0 * Ts)**2;
                D     := 4.0 + x + y;
                inv_D := 1.0 / D;
                ky    := K_val * y;
    
                v_b0_alpha :=  x * inv_D;
                v_b2_alpha := -x * inv_D;
                v_b0_beta  :=  ky * inv_D;
                v_b1_beta  :=  2.0 * ky * inv_D;
                v_b2_beta  :=  ky * inv_D;
                v_a1       :=  (8.0 - 2.0 * y) * inv_D;
                v_a2       := -(4.0 - x + y) * inv_D;
    
                b0_alpha <= to_signed(integer(v_b0_alpha * SCALE_Q28), 32);
                b2_alpha <= to_signed(integer(v_b2_alpha * SCALE_Q28), 32);
                b0_beta  <= to_signed(integer(v_b0_beta  * SCALE_Q28), 32);
                b1_beta  <= to_signed(integer(v_b1_beta  * SCALE_Q28), 32);
                b2_beta  <= to_signed(integer(v_b2_beta  * SCALE_Q28), 32);
                a1       <= to_signed(integer(v_a1       * SCALE_Q28), 32);
                a2       <= to_signed(integer(v_a2       * SCALE_Q28), 32);
            end if;

            if(n < 50000) then
                amp_mod := 1.0;
            elsif(n < 175000) then
                amp_mod := 0.8;
            elsif(n < 200000) then
                amp_mod := 0.4;
            elsif(n < 250000) then
                amp_mod := 1.0;
            elsif(n < 375000) then
                amp_mod := 1.12;
            else
                amp_mod := 1.25;
            end if;

            t := real(n) / FS;

            v_real := 
                (amp_mod * AMP) * sin(2.0 * math_pi * F_SIGNAL * t) +
                (amp_mod * AMP) * H3_AMP  * sin(2.0 * math_pi * 3.0  * F_SIGNAL * t) +
                (amp_mod * AMP) * H5_AMP  * sin(2.0 * math_pi * 5.0  * F_SIGNAL * t) +
                (amp_mod * AMP) * H7_AMP  * sin(2.0 * math_pi * 7.0  * F_SIGNAL * t) +
                (amp_mod * AMP) * H14_AMP * sin(2.0 * math_pi * 14.0 * F_SIGNAL * t);

            v_int := integer(v_real * ADC_MAX);

            if(v_int > integer(ADC_MAX)) then
                v_int := integer(ADC_MAX);
            elsif(v_int < -integer(ADC_MAX)) then
                v_int := -integer(ADC_MAX);
            end if;

            v_n <= to_signed(v_int, WIDTH);
            n   := n + 1;

        end loop;
        
        wait;

    end process;

end architecture;