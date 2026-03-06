library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity tb_srf_pll is
end entity;

architecture tb of tb_srf_pll is

    constant WIDTH : integer := 16;

    constant FS       : real := 50000.0;
    constant F_SIGNAL : real := 50.0;

    constant SLOW_PER : time := 20.0 us;
    constant FAST_PER : time := 10 ns;

    constant AMP : real := 0.8;

    constant H3_AMP  : real := 0.04;
    constant H5_AMP  : real := 0.05;
    constant H7_AMP  : real := 0.03;
    constant H14_AMP : real := 0.04;

    constant H1_PHASE_DEG     : real := 0.0;
    constant H1_PHASE_DEG_err : real := 66.0;
    constant H3_PHASE_DEG     : real := 0.0;
    constant H5_PHASE_DEG     : real := 0.0;
    constant H7_PHASE_DEG     : real := 0.0;

    constant ADC_MAX : real := 2.0**(WIDTH-1) - 1.0;

    signal clk     : std_logic := '0';
    signal slw_clk : std_logic := '0';
    signal rst     : std_logic := '0';
    signal ce      : std_logic := '0';

    signal v_n   : signed(WIDTH-1 downto 0);
    signal omega : signed(31 downto 0);
    signal phase : signed(31 downto 0);

begin

    uut : entity work.srf_pll
        port map (
            clk   => clk,
            rst   => rst,
            ce    => ce,
            v_n   => v_n,
            omega => omega,
            phase => phase
        );

    clk     <= not clk after FAST_PER/2;
    slw_clk <= not slw_clk after SLOW_PER/2;

    process
        variable n      : integer := 500;
        variable t      : real;
        variable v_real : real;
        variable v_int  : integer;

        constant RAD_CONV : real := math_pi / 180.0;

        variable phi1     : real := H1_PHASE_DEG * RAD_CONV;
        variable phi1_err : real := H1_PHASE_DEG_err * RAD_CONV;
        variable phi3     : real := H3_PHASE_DEG * RAD_CONV;
        variable phi5     : real := H5_PHASE_DEG * RAD_CONV;
        variable phi7     : real := H7_PHASE_DEG * RAD_CONV;

    begin

        rst <= '1';
        ce  <= '0';
        v_n <= (others => '0');

        wait for 5*SLOW_PER;

        rst <= '0';
        ce  <= '1';

        while n < 80000 loop

            wait until rising_edge(slw_clk);

            t := real(n) / FS;

            if (n >= 40000 and n < 60000) then

                v_real :=
                    AMP * sin(2.0 * math_pi * F_SIGNAL * t + phi1_err) +
                    AMP * H3_AMP  * sin(2.0 * math_pi * 3.0  * F_SIGNAL * t + phi3 + phi1_err) +
                    AMP * H5_AMP  * sin(2.0 * math_pi * 5.0  * F_SIGNAL * t + phi5 + phi1_err) +
                    AMP * H7_AMP  * sin(2.0 * math_pi * 7.0  * F_SIGNAL * t + phi7 + phi1_err) +
                    AMP * H14_AMP * sin(2.0 * math_pi * 14.0 * F_SIGNAL * t + phi7 + phi1_err);

            elsif (n >= 20000 and n < 40000) then

                v_real :=
                    AMP * sin(2.0 * math_pi * F_SIGNAL * t + phi1_err) +
                    0.0 * H3_AMP  * sin(2.0 * math_pi * 3.0  * F_SIGNAL * t + phi3 + phi1_err) +
                    0.0 * H5_AMP  * sin(2.0 * math_pi * 5.0  * F_SIGNAL * t + phi5 + phi1_err) +
                    0.0 * H7_AMP  * sin(2.0 * math_pi * 7.0  * F_SIGNAL * t + phi7 + phi1_err) +
                    0.0 * H14_AMP * sin(2.0 * math_pi * 14.0 * F_SIGNAL * t + phi7 + phi1_err);

            else

                v_real :=
                    AMP * sin(2.0 * math_pi * F_SIGNAL * t + phi1) +
                    AMP * H3_AMP  * sin(2.0 * math_pi * 3.0  * F_SIGNAL * t + phi3) +
                    AMP * H5_AMP  * sin(2.0 * math_pi * 5.0  * F_SIGNAL * t + phi5) +
                    AMP * H7_AMP  * sin(2.0 * math_pi * 7.0  * F_SIGNAL * t + phi7) +
                    AMP * H14_AMP * sin(2.0 * math_pi * 14.0 * F_SIGNAL * t + phi7);

            end if;

            v_int := integer(v_real * ADC_MAX);

            if v_int > integer(ADC_MAX) then
                v_int := integer(ADC_MAX);
            end if;

            if v_int < -integer(ADC_MAX) then
                v_int := -integer(ADC_MAX);
            end if;

            v_n <= to_signed(v_int, WIDTH);

            n := n + 1;

        end loop;

        wait;

    end process;

end architecture;