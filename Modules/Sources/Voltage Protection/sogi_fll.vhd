library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity sogi_fll is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        ce       : in  std_logic;
        b0_alpha : in  signed(31 downto 0); -- fixed point 28
        b2_alpha : in  signed(31 downto 0); -- fixed point 28
        b0_beta  : in  signed(31 downto 0); -- fixed point 28
        b1_beta  : in  signed(31 downto 0); -- fixed point 28
        b2_beta  : in  signed(31 downto 0); -- fixed point 28
        a1       : in  signed(31 downto 0); -- fixed point 28
        a2       : in  signed(31 downto 0); -- fixed point 28
        v_n      : in  signed(15 downto 0); -- fixed point 6
        omega    : out signed(31 downto 0); -- fixed point 21
        out_v    : out signed(31 downto 0); -- fixed point 19
        out_qv   : out signed(31 downto 0)  -- fixed point 19
    );
end sogi_fll;

architecture Behavioral of sogi_fll is

    component adaptive_sogi is
        generic (
            WIDTH : integer := 16
        );
        port (
            clk      : in  std_logic;
            rst      : in  std_logic;
            ce       : in  std_logic;
            b0_alpha : in  signed(31 downto 0);
            b2_alpha : in  signed(31 downto 0);
            b0_beta  : in  signed(31 downto 0);
            b1_beta  : in  signed(31 downto 0);
            b2_beta  : in  signed(31 downto 0);
            a1       : in  signed(31 downto 0);
            a2       : in  signed(31 downto 0);
            v_n      : in  signed(WIDTH - 1 downto 0);
            out_v    : out signed(2 * WIDTH - 1 downto 0);
            out_qv   : out signed(2 * WIDTH - 1 downto 0)
        );
    end component;

    component uni_shift_register is
        generic (
            WIDTH  : integer := 32;
            LENGTH : integer := 15
        );
        port (
            clk      : in  std_logic;
            reset    : in  std_logic;
            ce       : in  std_logic;
            data_in  : in  signed(WIDTH - 1 downto 0);
            data_out : out signed(WIDTH - 1 downto 0)
        );
    end component;

    component ema_filter is
        generic (
            INIT     : signed(31 downto 0);
            STRENGTH : integer
        );
        port (
            clk      : in  std_logic;
            reset    : in  std_logic;
            ce       : in  std_logic;
            data_in  : in  signed(31 downto 0);
            data_out : out signed(31 downto 0)
        );
    end component;

    signal v      : signed(31 downto 0);
    signal qv     : signed(31 downto 0);
    signal d_v_n  : signed(15 downto 0);
    
    signal omega_est       : signed(63 downto 0);
    signal omega_raw       : signed(31 downto 0);
    signal omega_est_shift : signed(63 downto 0);

    constant K        : signed(7 downto 0)  := x"04"; -- fixed point 6
    constant W0       : signed(63 downto 0) := x"4e8a316755129c00"; -- fixed point 54
    constant W0_EMA   : signed(31 downto 0) := x"274518b4"; -- fixed point 21

begin

    u_sogi : adaptive_sogi
        generic map (
            WIDTH => 16
        )
        port map (
            clk      => clk,
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
            out_v    => v,
            out_qv   => qv
        );

    u_delay : uni_shift_register
        generic map (
            WIDTH  => 16,
            LENGTH => 1
        )
        port map (
            clk      => clk,
            reset    => rst,
            ce       => ce,
            data_in  => v_n,
            data_out => d_v_n
        );

    u_ema : ema_filter
        generic map (
            INIT     => W0_EMA,
            STRENGTH => 9
        )
        port map (
            clk      => clk,
            reset    => rst,
            ce       => ce,
            data_in  => omega_raw,
            data_out => omega
        );

    process(clk)
        variable err       : signed(32 downto 0);
        variable v_err_fll : signed(65 downto 0);
    begin
        if(rising_edge(clk)) then
            if(rst = '1') then
                omega_est <= W0;
            elsif(ce = '1') then
                err       := shift_left(resize(d_v_n, 33), 13) - resize(v, 33);
                v_err_fll := err * resize(qv, 33);
                omega_est <= omega_est - shift_left(v_err_fll(65 downto 10) * K, 3);
            end if;
        end if;
    end process;

    out_v  <= v;
    out_qv <= qv;

    omega_est_shift <= shift_right(omega_est, 1);
    omega_raw       <= omega_est_shift(63 downto 32);

end Behavioral;