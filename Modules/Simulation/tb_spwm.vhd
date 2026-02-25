library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity tb_spwm is
end tb_spwm;

architecture Behavioral of tb_spwm is

    constant WIDTH_TB : integer := 16;

    signal clk_tb   : std_logic := '0';
    signal rst_tb   : std_logic := '1';
    signal v_ref_tb : signed(WIDTH_TB-1 downto 0);

    signal a_low_tb, a_high_tb : std_logic;
    signal b_low_tb, b_high_tb : std_logic;

    constant SAMPLES_PER_PERIOD : integer := 640;
    constant V_M : real := 32000.0;

    signal sample_cnt : integer := 0;
    signal delay      : integer := 0;

begin

    UUT: entity work.spwm
        generic map (
            WIDTH => WIDTH_TB
        )
        port map (
            clk    => clk_tb,
            rst    => rst_tb,
            v_ref  => v_ref_tb,
            a_low  => a_low_tb,
            a_high => a_high_tb,
            b_low  => b_low_tb,
            b_high => b_high_tb
        );

    clk_tb <= not clk_tb after 5 ns;

    process
    begin
        rst_tb <= '1';
        wait for 50 ns;
        rst_tb <= '0';
        wait;
    end process;

    process(clk_tb)
        variable angle : real;
    begin
        if rising_edge(clk_tb) then
            delay <= delay + 1;
            if delay = 3125 then 
                angle := 2.0 * math_pi * real(sample_cnt) / real(SAMPLES_PER_PERIOD);
                v_ref_tb <= to_signed(integer(V_M * sin(angle)), WIDTH_TB);

                if sample_cnt = SAMPLES_PER_PERIOD - 1 then
                    sample_cnt <= 0;
                else
                    sample_cnt <= sample_cnt + 1;
                end if;

                delay <= 0;
            end if;
        end if;
    end process;

end Behavioral;
