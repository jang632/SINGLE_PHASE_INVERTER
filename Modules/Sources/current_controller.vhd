library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity current_controller is
    port(
        clk    : in  std_logic;
        rst    : in  std_logic;
        ce     : in  std_logic;
        theta  : in  signed(31 downto 0); -- fixed point 28
        v_dc   : in  signed(15 downto 0); -- fixed point 6
        v_ref  : in  signed(31 downto 0); -- fixed point 16
        v_grid : in  signed(15 downto 0); -- fixed point 6
        i_meas : in  signed(15 downto 0); -- fixed point 10
        v_out  : out signed(47 downto 0)  -- fixed point 31
    );
end current_controller;

architecture Behavioral of current_controller is

    component MAF_filter
        generic(
            DATA_WIDTH    : integer := 16;
            WINDOW_LENGTH : integer := 500;
            FIXED_POINT   : integer := 6
        );
        port(
            clk      : in std_logic;
            rst      : in std_logic;
            ce       : in std_logic;
            data_in  : in  signed(DATA_WIDTH-1 downto 0);
            data_out : out signed(DATA_WIDTH-1 downto 0)
        );
    end component;

    component cordic_sin_cos
        generic( 
            iterations : integer 
        );
        port(
            clk       : in  std_logic;
            reset     : in  std_logic;
            theta     : in  signed(31 downto 0);
            sin_value : out signed(15 downto 0);
            cos_value : out signed(15 downto 0)
        );     
    end component;

    component inner_current_loop
        port(
            clk    : in  std_logic;
            rst    : in  std_logic;
            en     : in  std_logic;
            i_ref  : in  signed(15 downto 0); -- fixed point 10
            i_meas : in  signed(15 downto 0); -- fixed point 10
            v_grid : in  signed(15 downto 0); -- fixed point 6
            v_dc   : in  signed(31 downto 0); -- CURRENTLY NOT USED
            v_ref  : out signed(47 downto 0)  -- fixed point 31
        );
    end component;

    component pi_controller
        port(
            clk      : in  std_logic;
            rst      : in  std_logic;
            ce       : in  std_logic;
            data_in  : in  signed(31 downto 0); -- fixed point 16
            data_out : out signed(31 downto 0)  -- fixed point 10
        );
    end component;

    signal v_dc_open    : signed(31 downto 0);
    signal error_v_dc   : signed(31 downto 0); -- fixed point 16
    signal i_ref        : signed(31 downto 0); -- fixed point 10
    signal i_ref_sliced : signed(15 downto 0); -- fixed point 10

    signal sin_val    : signed(15 downto 0); -- fixed point 14

    signal maf_v_dc : signed(15 downto 0); -- fixed point 6

    signal h_v        : signed(47 downto 0); -- fixed point 6

begin

    u_maf_filter_inst : MAF_filter
    generic map (
        DATA_WIDTH    => 16,
        WINDOW_LENGTH => 500,
        FIXED_POINT   => 6
    )
    port map (
        clk      => clk,      -- Twój zegar systemowy
        rst      => rst,      -- Twój sygnał resetu
        ce       => ce,   -- Sygnał zezwolenia (obecnie ignorowany wewnątrz)
        data_in  => v_dc,
        data_out => maf_v_dc
    );

    u_cordic_sin : cordic_sin_cos
    generic map(
        iterations => 16 
    )
    port map(
        clk       => clk,
        reset     => rst,
        theta     => theta,
        sin_value => sin_val,
        cos_value => open
    );

    u_pi_voltage_loop : pi_controller
    port map(
        clk      => clk,
        rst      => rst,
        ce       => ce,
        data_in  => error_v_dc,
        data_out => i_ref 
    );

    u_inner_current_loop : inner_current_loop
    port map(
        clk    => clk,
        rst    => rst,
        en     => ce,
        i_ref  => i_ref_sliced, 
        i_meas => i_meas, 
        v_grid => v_grid,
        v_dc   => v_dc_open, 
        v_ref  => v_out 
    );
    
    process(clk)
        variable v : signed(47 downto 0);
    begin
        if(rising_edge(clk)) then 
            if(rst = '1') then 
                error_v_dc   <= (others => '0');
                i_ref_sliced <= (others => '0');
                h_v          <= (others => '0');
                v            := (others => '0');
            else
                if(ce = '1') then
                    error_v_dc   <= shift_left(resize(v_dc,32),10) - v_ref; -- fixed point 16       
                    v            := shift_left(i_ref*sin_val,18);           -- fixed point 42
                    i_ref_sliced <= v(47 downto 32);                        -- fixed point 10
                    h_v          <= v;
                else
                    error_v_dc   <= error_v_dc;    
                    v            := v;
                    i_ref_sliced <= i_ref_sliced;
                end if;
            end if;
        end if;
    end process;

end Behavioral;