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
            clk      : in  std_logic;
            rst      : in  std_logic;
            ce       : in  std_logic;
            data_in  : in  signed(DATA_WIDTH-1 downto 0);
            data_out : out signed(DATA_WIDTH-1 downto 0)
        );
    end component;

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
            sin_value : out signed(WIDTH-1 downto 0);
            cos_value : out signed(WIDTH-1 downto 0)
        );     
    end component;

    component inner_current_loop
        port(
            clk    : in  std_logic;
            rst    : in  std_logic;
            ce     : in  std_logic;
            i_ref  : in  signed(15 downto 0); -- fixed point 10
            i_meas : in  signed(15 downto 0); -- fixed point 10
            v_grid : in  signed(15 downto 0); -- fixed point 6
            v_out  : out signed(47 downto 0)  -- fixed point 29
        );
    end component;

    component pi_controller is
        generic(
            INIT        : signed(66 downto 0);
            SATURATION  : signed(66 downto 0);
            FP_DATA_IN  : integer;
            FP_COEFF    : integer;
            FP_DATA_OUT : integer
        );
        port (
            clk      : in  std_logic;
            rst      : in  std_logic;
            ce       : in  std_logic;
            b0       : in  signed(31 downto 0); -- fixed point 20
            b1       : in  signed(31 downto 0); -- fixed point 20
            data_in  : in  signed(31 downto 0); -- fixed point 24
            data_out : out signed(31 downto 0)  -- fixed point 20
        );
    end component;
    
    constant SATURATION : signed(66 downto 0) := shift_left(to_signed(25, 67), 44);
    constant INIT       : signed(66 downto 0) := shift_left(to_signed(5, 67), 44);

    constant b0 : signed(31 downto 0) := x"02668B1A";
    constant b1 : signed(31 downto 0) := x"FD99BE4D";

    signal error_v_dc   : signed(31 downto 0); -- fixed point 16
    signal i_ref        : signed(31 downto 0); -- fixed point 10
    signal i_ref_sliced : signed(15 downto 0); -- fixed point 10

    signal sin_val      : signed(15 downto 0); -- fixed point 14

    signal maf_v_dc     : signed(15 downto 0); -- fixed point 6

begin

    u_maf_filter_inst : MAF_filter
        generic map (
            DATA_WIDTH    => 16,
            WINDOW_LENGTH => 497,
            FIXED_POINT   => 6
        )
        port map (
            clk      => clk,     
            rst      => rst,     
            ce       => ce,   
            data_in  => v_dc,
            data_out => maf_v_dc
        );

    u_cordic_sin : cordic_sin_cos
        generic map(
            iterations => 16,
            WIDTH      => 16,
            OUT_FP     => 14
        )
        port map(
            clk       => clk,
            reset     => rst,
            ce        => ce,
            theta     => theta,
            sin_value => sin_val,
            cos_value => open
        );

    u_pi_voltage_loop : pi_controller
        generic map(
            INIT        => INIT,
            SATURATION  => SATURATION,
            FP_DATA_IN  => 16,
            FP_COEFF    => 28,
            FP_DATA_OUT => 10
        )
        port map(
            clk      => clk,
            rst      => rst,
            ce       => ce,
            b0       => b0,
            b1       => b1,
            data_in  => error_v_dc,
            data_out => i_ref 
        );

    u_inner_current_loop : inner_current_loop
        port map(
            clk    => clk,
            rst    => rst,
            ce     => ce,
            i_ref  => i_ref_sliced, 
            i_meas => i_meas, 
            v_grid => v_grid,
            v_out  => v_out 
        );
    
    process(clk)
        variable v : signed(47 downto 0);
    begin
        if rising_edge(clk) then 
            if(rst = '1') then 
                error_v_dc   <= (others => '0');
                i_ref_sliced <= (others => '0');
                v            := (others => '0');
            else
                if(ce = '1') then
                    error_v_dc   <= shift_left(resize(maf_v_dc, 32), 10) - v_ref; -- fixed point 16        
                    v            := shift_left(i_ref * sin_val, 18);              -- fixed point 42
                    i_ref_sliced <= v(47 downto 32);                              -- fixed point 10
                end if;
            end if;
        end if;
    end process;

end Behavioral;