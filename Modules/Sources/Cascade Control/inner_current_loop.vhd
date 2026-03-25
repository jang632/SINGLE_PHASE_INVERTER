library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

library work;
use work.pkg.all;

entity inner_current_loop is
    port(
        clk    : in  std_logic;
        rst    : in  std_logic;
        ce     : in  std_logic;
        i_ref  : in  signed(15 downto 0); -- fixed point 10
        i_meas : in  signed(15 downto 0); -- fixed point 10
        v_grid : in  signed(15 downto 0); -- fixed point 6
        v_dc   : in  signed(31 downto 0); -- fixed point 16
        v_ref  : out signed(47 downto 0)  -- fixed point 23
    );
end entity inner_current_loop;

architecture Behavioral of inner_current_loop is

    constant DEPTH_e      : integer := 2;
    constant DATA_WIDTH_e : integer := 17;
    constant DEPTH_y      : integer := 1;
    constant DATA_WIDTH_y : integer := 43;
    
    constant SATURATION_y_r   : signed(42 downto 0) := shift_left(to_signed(80, 43), 31);
    constant SATURATION_u_pr  : signed(43 downto 0) := shift_left(to_signed(100, 44), 31);
    constant SATURATION_u_req : signed(47 downto 0) := shift_left(to_signed(380, 48), 31);
    
    constant Kp : signed(23 downto 0) := x"700000"; -- fixed point 21, value =  3.5
    constant b0 : signed(23 downto 0) := x"04052B"; -- fixed point 21, value =  0.12561035
    constant b1 : signed(23 downto 0) := x"000000"; -- fixed point 21, value =  0.0
    constant b2 : signed(23 downto 0) := x"FBFAD5"; -- fixed point 21, value = -0.12561035
    constant a0 : signed(23 downto 0) := x"C00471"; -- fixed point 21, value = -1.99951172
    constant a1 : signed(23 downto 0) := x"1FFBE2"; -- fixed point 21, value =  0.99951172

    signal e_k       : signed(16 downto 0) := (others => '0'); -- fixed point 10
    signal buf_e_k   : t_array(0 to DEPTH_e-1)(DATA_WIDTH_e-1 downto 0) := (others => (others => '0')); -- fixed point 10
    signal buf_y     : t_array(0 to DEPTH_y-1)(DATA_WIDTH_y-1 downto 0) := (others => (others => '0')); -- fixed point 10
    
    signal y_p       : signed(DATA_WIDTH_y-1 downto 0);
    signal y_r       : signed(DATA_WIDTH_y-1 downto 0);
    signal u_pr      : signed(43 downto 0);
    signal u_req     : signed(47 downto 0);
    
    signal d0_v_grid : signed(15 downto 0);
    
    function truncate(data_in : signed; limit : signed) return signed is 
        variable data_out : signed(data_in'range); 
    begin
        if data_in > limit then
            data_out := limit;
        elsif data_in < -limit then
            data_out := -limit;
        else
            data_out := data_in;
        end if;  
        return data_out;
    end function truncate;
    
    component shift_buffer is
        generic(
            LENGTH : integer;
            WIDTH  : integer
        );
        port(
            clk      : in  std_logic;
            rst      : in  std_logic;
            ce       : in  std_logic;
            data_in  : in  signed(WIDTH-1 downto 0);
            data_out : out t_array(0 to LENGTH-1)(WIDTH-1 downto 0)
        );
    end component shift_buffer;
                
begin

        u_shift_buffer_e : shift_buffer
        generic map(
            LENGTH => DEPTH_e,
            WIDTH  => DATA_WIDTH_e
        )
        port map(
            clk      => clk,
            rst      => rst,
            ce       => ce,
            data_in  => e_k,
            data_out => buf_e_k
        );
    
    u_shift_buffer_y : shift_buffer
        generic map(
            LENGTH => DEPTH_y,
            WIDTH  => DATA_WIDTH_y
        )
        port map(
            clk      => clk,
            rst      => rst,
            ce       => ce,
            data_in  => y_r,
            data_out => buf_y
        );

    input_reg : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then   
                e_k <= (others => '0'); 
                d0_v_grid <= (others => '0'); 
            else
                if(ce = '1') then
                    e_k <= resize(i_ref, 17) - resize(i_meas, 17); -- fixed point 10
                    d0_v_grid <= v_grid; -- fixed point 6
                end if;
            end if;
        end if;
    end process;
    
    main_loop : process(clk)
        variable v1 : signed(66 downto 0);
        variable v2 : signed(66 downto 0);
    begin
        if rising_edge(clk) then
            if(rst = '1') then   
                y_p   <= (others => '0');   
                y_r   <= (others => '0'); 
                u_pr  <= (others => '0');
                u_req <= (others => '0'); 
            else
                if(ce = '1') then
                    y_p  <= resize(Kp * (resize(i_ref, 17) - resize(i_meas, 17)), 43); -- fixed point 31
                    v1   := a0 * y_r;      -- fixed point 52
                    v2   := a1 * buf_y(0); -- fixed point 52
                    
                    y_r <= truncate(
                        data_in => resize(b0 * e_k, 43) 
                                 + resize(b2 * buf_e_k(1), 43) 
                                 - resize(shift_right(v1, 21), 43) 
                                 - resize(shift_right(v2, 21), 43),
                        limit   => SATURATION_y_r
                    ); -- fixed point 31
                    
                    u_pr <= truncate(
                        data_in => resize(y_p, 44) + resize(y_r, 44), 
                        limit   => SATURATION_u_pr
                    ); -- fixed point 23
                    
                    u_req <= truncate(
                        data_in => resize(u_pr, 48) + shift_left(resize(d0_v_grid, 48), 25), 
                        limit   => SATURATION_u_req
                    ); -- fixed point 23
                end if;
            end if;
        end if;
    end process;
    
    v_ref <= u_req;
    
end architecture Behavioral;