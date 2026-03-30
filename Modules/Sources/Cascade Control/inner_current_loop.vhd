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
        v_out  : out signed(47 downto 0)  -- fixed point 29
    );
end entity inner_current_loop;

architecture Behavioral of inner_current_loop is
    
    constant SATURATION_u_req : signed(47 downto 0) := shift_left(to_signed(380, 48), 29);
    constant current_width    : integer := 16;
    constant voltage_width    : integer := 16;
    
    signal e_k        : signed(current_width downto 0) := (others => '0'); -- fixed point 10
    
    signal u_req      : signed(47 downto 0);
    
    signal u_pr_50Hz  : signed(43 downto 0);
    signal u_pr_150Hz : signed(43 downto 0);
    
    signal d0_v_grid  : signed(voltage_width - 1 downto 0);
    
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
    
    component pr_controller is
    generic (
        KP : signed(21 downto 0);
        B0 : signed(21 downto 0);
        A0 : signed(21 downto 0);
        A1 : signed(21 downto 0)
    );
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        ce       : in  std_logic;
        error    : in  signed(16 downto 0);
        data_out : out signed(43 downto 0)
    );
    end component;
                
begin

        u_pr_controller_50Hz : pr_controller
        generic map (
            KP => "0111000000000000000000",
            B0 => "0000000110011011101011",
            A0 => "1100000000000100011100",
            A1 => "0001111111111011111001"  
        )
        port map (
            clk      => clk,
            rst      => rst,
            ce       => ce,
            error    => e_k,
            data_out => u_pr_50Hz
        );
        
        u_pr_controller_150Hz : pr_controller
        generic map (
            KP => "0111000000000000000000",
            B0 => "0000000110011011101001",
            A0 => "1100000000000111000010", 
            A1 => "0001111111111011111001" 
        )
        port map (
            clk      => clk,
            rst      => rst,
            ce       => ce,
            error    => e_k,
            data_out => u_pr_150Hz
        );

    input_reg : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then   
                e_k <= (others => '0'); 
                d0_v_grid <= (others => '0'); 
            else
                if(ce = '1') then
                    e_k <= resize(i_ref, current_width + 1) - resize(i_meas, current_width + 1); -- fixed point 10
                    d0_v_grid <= v_grid; -- fixed point 6
                end if;
            end if;
        end if;
    end process;
    
    main_loop : process(clk)
    begin
        if rising_edge(clk) then
            if(rst = '1') then   
                u_req <= (others => '0'); 
            else
                if(ce = '1') then                
                    u_req <= truncate(data_in =>resize(u_pr_50Hz, 48) + resize(u_pr_150Hz, 48) + shift_left(resize(d0_v_grid, 48), 23), limit   => SATURATION_u_req); -- fixed point 29
                end if;
            end if;
        end if;
    end process;
    
    v_out <= u_req;
    
end architecture Behavioral;