library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity parke_transform is
    port(
        clk     : in  std_logic;
        rst     : in  std_logic;
        ce      : in  std_logic;
        v_alpha : in  signed(31 downto 0);
        v_beta  : in  signed(31 downto 0);
        theta   : in  signed(31 downto 0);
        v_d     : out signed(31 downto 0);
        v_q     : out signed(31 downto 0)
    );
end parke_transform;

architecture behavioral of parke_transform is

    signal sin_val : signed(31 downto 0);
    signal cos_val : signed(31 downto 0);

    signal v_d_int : signed(63 downto 0);
    signal v_q_int : signed(63 downto 0);

    signal v_alpha_delayed : signed(31 downto 0);
    signal v_beta_delayed  : signed(31 downto 0);

    component cordic_sin_cos
        generic(
            iterations : integer;
            WIDTH      : integer;
            OUT_FP     : integer
        );
        port(
            clk       : in  std_logic;
            reset     : in  std_logic;
            ce        : in  std_logic;
            theta     : in  signed(31 downto 0);
            sin_value : out signed(31 downto 0);
            cos_value : out signed(31 downto 0)
        );
    end component;

    component shift_register
        generic(
            DATA_WIDTH : integer;
            DEPTH      : integer
        );
        port(
            clk      : in  std_logic;
            rst      : in  std_logic;
            data_in  : in  signed(31 downto 0);
            data_out : out signed(31 downto 0)
        );
    end component;

begin

    u_cordic : cordic_sin_cos
        generic map(
            iterations => 16,
            WIDTH      => 32,
            OUT_FP     => 28
        )
        port map(
            clk       => clk,
            reset     => rst,
            ce        => ce,
            theta     => theta,
            sin_value => sin_val,
            cos_value => cos_val
        );

     u_beta_delay : shift_register
        generic map(
            DATA_WIDTH => 32,
            DEPTH      => 14
        )
        port map(
            clk      => clk,
            rst      => rst,
            data_in  => v_beta,
            data_out => v_beta_delayed
        );
     
     u_alpha_delay : shift_register
        generic map(
            DATA_WIDTH => 32,
            DEPTH      => 14
        )
        port map(
            clk      => clk,
            rst      => rst,
            data_in  => v_alpha,
            data_out => v_alpha_delayed
        );

    process(clk)
    begin
        if (rising_edge(clk)) then
            if(rst = '1') then
                v_d_int <= (others => '0');
                v_q_int <= (others => '0');
            else
                if(ce = '1') then
                    v_d_int <= v_alpha_delayed * cos_val + v_beta_delayed * sin_val;
                    v_q_int <= v_beta_delayed  * cos_val - v_alpha_delayed * sin_val;
                end if;
            end if;
        end if;
    end process;

    v_d <= shift_left(v_d_int(63 downto 32), 1);
    v_q <= shift_left(v_q_int(63 downto 32), 1);

end behavioral;