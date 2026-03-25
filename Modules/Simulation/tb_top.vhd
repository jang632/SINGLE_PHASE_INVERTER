library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity tb_top is
end entity;

architecture tb of tb_top is

constant WIDTH : integer := 16;

constant FS       : real := 50000.0;
constant F_SIGNAL : real := 50.0;

constant FAST_PER : time := 10 ns;

constant AMP : real := 0.8;
constant ADC_MAX : real := 2.0**(WIDTH-1) - 1.0;

signal clk  : std_logic := '0';
signal rst  : std_logic := '0';
signal ce   : std_logic := '0';
signal pll_rst   : std_logic := '0';


signal miso : std_logic := '0';
signal sclk : std_logic;
signal ss_n : std_logic_vector(0 downto 0);
signal tx   : std_logic;

-- SPI
signal spi_shift : std_logic_vector(15 downto 0) := (others=>'0');
signal bit_cnt   : integer range 0 to 15 := 15;

begin

dut : entity work.top
port map(
    clk     => clk,
    rst     => rst,
    pll_rst => pll_rst,
    ce      => ce,
    miso    => miso,
    sclk    => sclk,
    ss_n    => ss_n,
    tx      => tx
);

clk <= not clk after FAST_PER/2;

process
begin

    pll_rst <= '1';
    wait for 100 ns;
    pll_rst <= '0';
    wait for 100 ns;
    rst <= '1';
    ce  <= '1';

    wait for 2 us;
     rst <= '0';
    
    wait;

end process;

process

    variable n      : integer := 0;
    variable t      : real;
    variable v_real : real;
    variable v_int  : integer;

begin

    wait until ss_n(0) = '0';

    while true loop

        t := real(n) / FS;

        v_real := AMP * sin(2.0 * math_pi * F_SIGNAL * t) + 0.06*AMP * sin(2.0 *3 * math_pi * F_SIGNAL * t)+ 0.06 *AMP* sin(2.0 *5* math_pi * F_SIGNAL * t);

        v_int := integer(v_real * ADC_MAX);

        spi_shift <= std_logic_vector(to_signed(v_int,16));

        for i in 15 downto 0 loop

            wait until falling_edge(sclk);
            miso <= spi_shift(i);

        end loop;

        n := n + 1;

        wait until ss_n(0) = '1';
        wait until ss_n(0) = '0';

    end loop;

end process;

end architecture;