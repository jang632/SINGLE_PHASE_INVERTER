library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity srf_pll is
    port (
        clk   : in  std_logic;
        rst   : in  std_logic;
        ce    : in  std_logic;
        v_n   : in  signed(15 downto 0);
        omega : out signed(31 downto 0); -- fixed point 20
        phase : out signed(31 downto 0)  -- fixed point 28
    );
end srf_pll;

architecture Behavioral of srf_pll is


    type machine is (LOCKING, STABLE);
    signal state : machine;


    signal clk_10M : std_logic := '0';
    signal reset   : std_logic := '0';
    signal enable  : std_logic;


    signal v       : signed(31 downto 0);
    signal qv      : signed(31 downto 0);
    signal v_d     : signed(31 downto 0); -- fixed point 24
    signal v_q     : signed(31 downto 0); -- fixed point 24
    signal v_d_ema : signed(31 downto 0) := (others => '0');


    signal theta           : signed(31 downto 0);
    signal theta_int       : signed(31 downto 0);
    signal theta_saturated : signed(31 downto 0);
    signal omega_int       : signed(31 downto 0);
    
    constant Ts : signed(31 downto 0) := x"0000a7c6"; -- fixed point 31


    signal b0 : signed(31 downto 0) := x"210E5DC9"; -- fixed point 20
    signal b1 : signed(31 downto 0) := x"DF152A0B"; -- fixed point 20
    
    constant b0_LOCKING : signed(31 downto 0) := x"1BD46771"; -- fixed point 20
    constant b1_LOCKING : signed(31 downto 0) := x"E44B2DBD"; -- fixed point 20
    constant b0_STABLE  : signed(31 downto 0) := x"0A9BC1DD"; -- fixed point 20
    constant b1_STABLE  : signed(31 downto 0) := x"F56715CE"; -- fixed point 20


    constant v_d_error_low        : signed(31 downto 0) := x"0010a3d7"; -- fixed point 24
    constant v_d_error_high       : signed(31 downto 0) := x"001851ec"; -- fixed point 24
    constant stable_samples_count : unsigned(15 downto 0) := to_unsigned(3000, 16);
    
    signal stable_samples : unsigned(15 downto 0) := (others => '0');

    component enable_generator
        generic (
            COUNT : integer := 200
        );
        port (
            clk        : in  std_logic;
            rst        : in  std_logic;
            ce         : in  std_logic;
            enable_out : out std_logic
        );
    end component;
    
    component clk_wiz_0
        port (
            clk_out1 : out std_logic;
            clk_in1  : in  std_logic
        );
    end component;
    
    component sogi
        generic (
            WIDTH : integer := 16
        );
        port (
            clk : in  std_logic;
            rst : in  std_logic;
            ce  : in  std_logic;
            v_n : in  signed(WIDTH-1 downto 0);
            v   : out signed(2*WIDTH-1 downto 0);
            qv  : out signed(2*WIDTH-1 downto 0)
        );
    end component;

    component parke_transform is
        port (
            clk     : in  std_logic;
            rst     : in  std_logic;
            ce      : in  std_logic;
            v_alpha : in  signed(31 downto 0); --fixed point 28
            v_beta  : in  signed(31 downto 0); --fixed point 28
            theta   : in  signed(31 downto 0); --fixed point 28
            v_d     : out signed(31 downto 0); --fixed point 24
            v_q     : out signed(31 downto 0)  --fixed point 24
        );
    end component;

    component pi_controller is
        port (
            clk      : in  std_logic;
            rst      : in  std_logic;
            ce       : in  std_logic;
            b0       : in  signed(31 downto 0); --fixed point 20
            b1       : in  signed(31 downto 0); --fixed point 20
            data_in  : in  signed(31 downto 0); --fixed point 24
            data_out : out signed(31 downto 0)  --fixed point 20
        );
    end component;
    
    component integrator is
        port (
            clk      : in  std_logic;
            rst      : in  std_logic;
            ce       : in  std_logic;
            data_in  : in  signed(31 downto 0); --fixed point 20
            data_out : out signed(31 downto 0)  --fixed point 28
        );
    end component;

--    component ema_filter is
--        port (
--            clk      : in  std_logic;
--            reset    : in  std_logic;
--            ce       : in  std_logic;
--            data_in  : in  signed(31 downto 0);
--            data_out : out signed(31 downto 0)
--        );
--    end component;

begin

    u_enable_generator : enable_generator
        generic map (
            COUNT => 400
        )
        port map (
            clk        => clk_10M,
            rst        => rst,
            ce         => ce,
            enable_out => enable 
        );

    u_pll : clk_wiz_0
        port map (
            clk_out1 => clk_10M,
            clk_in1  => clk
        );

    u_sogi : sogi
        generic map (
            WIDTH => 16
        )
        port map (
            clk => clk_10M,
            rst => rst,
            ce  => enable,
            v_n => v_n,
            v   => v,
            qv  => qv
        );

    parke_inst : parke_transform
        port map (
            clk     => clk_10M,
            rst     => rst,
            ce      => enable,
            v_alpha => v,
            v_beta  => qv,
            theta   => theta_int,
            v_d     => v_d,
            v_q     => v_q
        );

    pi_ctrl_inst : pi_controller
        port map (
            clk      => clk_10M,
            rst      => rst,
            ce       => enable,
            b0       => b0,
            b1       => b1,
            data_in  => v_d,
            data_out => omega_int
        );

--    u_ema : ema_filter
--        port map (
--            clk      => clk,
--            reset    => rst,
--            ce       => enable,
--            data_in  => v_q,
--            data_out => v_d_ema
--        );
    
    u_integrator : integrator
        port map (
            clk      => clk_10M,
            rst      => rst,
            ce       => enable,
            data_in  => omega_int,
            data_out => theta_int
        );
    
    process(clk)
    begin
        if rising_edge(clk_10M) then 
            if rst = '1' then 
                state          <= LOCKING;
                stable_samples <= (others => '0');
            else
                if(enable = '1') then
                    case state is
                        when LOCKING => 
                            b0 <= b0_LOCKING;
                            b1 <= b1_LOCKING;
                            
                            if abs(v_d) < v_d_error_low then 
                                stable_samples <= stable_samples + 1;
                            else
                                stable_samples <= (others => '0');
                            end if;
                            
                            if stable_samples > stable_samples_count then 
                                state <= STABLE;
                            else
                                state <= LOCKING;
                            end if;
                            
                        when STABLE =>
                            b0 <= b0_STABLE;
                            b1 <= b1_STABLE;
                            
                            if abs(v_d) > v_d_error_high then 
                                state <= LOCKING;
                            else
                                state <= STABLE;
                            end if;
                    end case;
                 end if;
            end if;
        end if;
    end process;
    
    phase <= theta_int;
    omega <= omega_int;

end Behavioral;