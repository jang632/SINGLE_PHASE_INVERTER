library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity voltage_protection is
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
        ov1      : out std_logic;
        ov2      : out std_logic;
        uv1      : out std_logic;
        uv2      : out std_logic
    );
end voltage_protection;

architecture Behavioral of voltage_protection is

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

    component sogi_fll is
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
            v_n      : in  signed(15 downto 0);
            omega    : out signed(31 downto 0);
            out_v    : out signed(31 downto 0);
            out_qv   : out signed(31 downto 0)
        );
    end component;

    component cordic_mag is
        generic (
            iterations : integer := 16
        );
        port (
            clk       : in  std_logic;
            reset     : in  std_logic;
            ce        : in  std_logic;
            x         : in  signed(31 downto 0);
            y         : in  signed(31 downto 0);
            magnitude : out signed(31 downto 0)
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
    
    signal enable  : std_logic;

    signal v, qv                    : signed(31 downto 0); -- fixed point 19
    signal magnitude, magnitude_ema : signed(31 downto 0); -- fixed point 17

    type machine is (LOCKING, RUNNING);
    signal state : machine;

    signal ov1_flag : std_logic;
    signal ov2_flag : std_logic;
    signal uv2_flag : std_logic;
    signal uv1_flag : std_logic;

    signal count : unsigned(15 downto 0);

    signal timer_count : unsigned(15 downto 0);
    signal timer_tick  : std_logic;

    signal ov1_count : unsigned(15 downto 0);
    signal uv1_count : unsigned(15 downto 0);
    signal ov2_count : unsigned(15 downto 0);
    signal uv2_count : unsigned(15 downto 0);

    constant FIXED_POINT : integer := 2**17;

    constant OV1_TRIP  : signed(31 downto 0) := to_signed(358 * FIXED_POINT, 32);
    constant OV1_RESET : signed(31 downto 0) := to_signed(351 * FIXED_POINT, 32);

    constant UV1_TRIP  : signed(31 downto 0) := to_signed(276 * FIXED_POINT, 32);
    constant UV1_RESET : signed(31 downto 0) := to_signed(286 * FIXED_POINT, 32);

    constant OV2_TRIP  : signed(31 downto 0) := to_signed(374 * FIXED_POINT, 32);
    constant OV2_RESET : signed(31 downto 0) := to_signed(368 * FIXED_POINT, 32);

    constant UV2_TRIP  : signed(31 downto 0) := to_signed(146 * FIXED_POINT, 32);
    constant UV2_RESET : signed(31 downto 0) := to_signed(163 * FIXED_POINT, 32);

    constant MAG_EMA : signed(31 downto 0) := x"028a0000"; -- fixed point 17

begin

    u_enable_generator : enable_generator
    generic map (
        COUNT => 200
    )
    port map (
        clk        => clk,
        rst        => rst,
        ce         => ce,
        enable_out => enable 
    );

    u_sogi_fll : sogi_fll
        port map (
            clk      => clk,
            rst      => rst,
            ce       => enable,
            b0_alpha => b0_alpha,
            b2_alpha => b2_alpha,
            b0_beta  => b0_beta,
            b1_beta  => b1_beta,
            b2_beta  => b2_beta,
            a1       => a1,
            a2       => a2,
            v_n      => v_n,
            omega    => omega,
            out_v    => v,
            out_qv   => qv
        );

    u_cordic_mag : cordic_mag
        generic map (
            iterations => 16
        )
        port map (
            clk       => clk,
            reset     => rst,
            ce        => enable,
            x         => v,
            y         => qv,
            magnitude => magnitude_ema
        );
        
    u_ema : ema_filter
        generic map (
            INIT     => MAG_EMA,
            STRENGTH => 9
        )
        port map (
            clk      => clk,
            reset    => rst,
            ce       => enable,
            data_in  => magnitude_ema,
            data_out => magnitude
        );
        
    process(clk)
    begin
        if(rising_edge(clk)) then 
            if(rst = '1') then 
                timer_tick  <= '0';
                timer_count <= (others => '0');
            elsif(enable = '1') then 
                if(timer_count < to_unsigned(49, 16)) then
                    timer_tick  <= '0';
                    timer_count <= timer_count + 1;
                else
                    timer_tick  <= '1';
                    timer_count <= (others => '0');
                end if;
            end if;
        end if;
    end process;
    
    process(clk)
    begin
        if(rising_edge(clk)) then
            if(rst = '1') then 
                state <= LOCKING;
                count <= (others => '0');
                
                uv1_flag <= '0';
                uv2_flag <= '0';
                ov1_flag <= '0';
                ov2_flag <= '0';
                
                ov2_count <= (others => '0');
                ov1_count <= (others => '0');
                uv2_count <= (others => '0');
                uv1_count <= (others => '0');
            elsif(enable = '1') then 
                case(STATE) is
                    when LOCKING =>
                        if(count > to_unsigned(200, 16)) then 
                            state <= RUNNING;
                        elsif(timer_tick = '1') then
                            count <= count + 1;
                        end if;
                    when RUNNING =>
                        
                        if(magnitude > OV1_TRIP) then
                            if(ov1_count < to_unsigned(2000, 16)) then
                                if(timer_tick = '1') then
                                    ov1_count <= ov1_count + 1;
                                end if;
                            else
                                ov1_flag <= '1';
                            end if; 
                        elsif(magnitude < OV1_RESET) then
                            ov1_flag  <= '0';
                            ov1_count <= (others => '0');
                        end if;
                        
                        if(magnitude > OV2_TRIP) then
                            if(ov2_count < to_unsigned(10, 16)) then
                                if(timer_tick = '1') then
                                    ov2_count <= ov2_count + 1;
                                end if;
                            else
                                ov2_flag  <= '1';
                                ov1_count <= (others => '0');
                                ov1_flag  <= '0';
                            end if; 
                        elsif(magnitude < OV2_RESET) then
                            ov2_flag  <= '0';
                            ov2_count <= (others => '0');
                        end if;
                        
                        if(magnitude < UV1_TRIP) then
                            if(uv1_count < to_unsigned(2000, 16)) then
                                if(timer_tick = '1') then
                                    uv1_count <= uv1_count + 1;
                                end if;
                            else
                                uv1_flag <= '1';
                            end if; 
                        elsif(magnitude > UV1_RESET) then
                            uv1_flag  <= '0';
                            uv1_count <= (others => '0');
                        end if;
                        
                        if(magnitude < UV2_TRIP) then
                            if(uv2_count < to_unsigned(10, 16)) then
                                if(timer_tick = '1') then
                                    uv2_count <= uv2_count + 1;
                                end if;
                            else
                                uv2_flag  <= '1';
                                uv1_count <= (others => '0');
                                uv1_flag  <= '0';
                            end if; 
                        elsif(magnitude > UV2_RESET) then
                            uv2_flag  <= '0';
                            uv2_count <= (others => '0');
                        end if;
                        
                end case;
            end if;
        end if;
    end process;
       
    ov1 <= '0' when ov2_flag = '1' else ov1_flag;
    uv1 <= '0' when uv2_flag = '1' else uv1_flag;        
    ov2 <= ov2_flag;      
    uv2 <= uv2_flag;

end Behavioral;