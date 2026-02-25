
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package pkg is
  type t_array is array (natural range <>) of signed;
end package;

package body pkg is
end package body;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.pkg.all;

-- e +- 100
-- u_req +- 400
-- u_pr +- 700
-- y_res_k +- 9
-- y_prop +- 100

-- wspolczyniki +- 2

entity inner_current_loop is
    port(
        clk    : in  std_logic;
        rst    : in  std_logic;
        en     : in  std_logic;
        i_ref  : in  signed(31 downto 0);
        i_meas : in  signed(31 downto 0);
        v_grid : in  signed(31 downto 0);
        v_dc   : in  signed(31 downto 0);
        v_ref  : out signed(63 downto 0)
     );
end inner_current_loop;

architecture Behavioral of inner_current_loop is
    constant DEPTH_e      : integer := 4;
    constant DATA_WIDTH_e : integer := 32;
    constant DEPTH_y      : integer := 4;
    constant DATA_WIDTH_y : integer := 48;
    
    constant Kp         : signed(15 downto 0) := x"7000"; -- fp 13
    constant b0         : signed(15 downto 0) := x"0405"; -- fp 13
    constant b1         : signed(15 downto 0) := x"0000"; -- fp 13
    constant b2         : signed(15 downto 0) := x"FBFB"; -- fp 13
    constant a1         : signed(15 downto 0) := x"1FFC"; -- fp 13
    constant a0         : signed(15 downto 0) := x"C004"; -- fp 13

    
    signal e_k     : signed(31 downto 0) := (others => '0'); -- fp 10
    signal buf_e_k : t_array(0 to DEPTH_e-1)(DATA_WIDTH_e-1 downto 0) := (others => (others => '0')); -- fp 10
    signal buf_y   : t_array(0 to DEPTH_y-1)(DATA_WIDTH_y-1 downto 0) := (others => (others => '0')); -- fp 10
    
    signal y_p     : signed(47 downto 0);
    signal y_r     : signed(47 downto 0);
    signal u_pr    : signed(32 downto 0);
    signal u_req   : signed(63 downto 0);
    
    signal d0_v_grid   : signed(31 downto 0);
    signal d1_v_grid   : signed(31 downto 0);
    signal d2_v_grid   : signed(31 downto 0);
    
    component shift_buffer 
        generic(
            DATA_WIDTH : integer;
            DEPTH      : integer
        );
        port(
            clk      : in  std_logic;
            rst      : in  std_logic;
            data_in  : in  signed(DATA_WIDTH-1 downto 0);
            data_out : out t_array(0 to DEPTH-1)(DATA_WIDTH-1 downto 0)
        );
    end component;
                
begin

process(clk)
begin
    if(rising_edge(clk)) then
        if(rst = '1')then   
            e_k <= (others => '0'); 
            d0_v_grid <= (others => '0'); 
            d1_v_grid <= (others => '0');   
            d2_v_grid <= (others => '0'); 
        else
            e_k <= resize(i_ref,32) - resize(i_meas,32);
            d0_v_grid <= v_grid;
            d1_v_grid <= d0_v_grid;  
            d2_v_grid <= d1_v_grid;
        end if;
    end if;
end process;

process(clk)
variable v1 : signed(47 downto 0);
variable v2 : signed(63 downto 0);
variable v3 : signed(63 downto 0);
variable v4 : signed(63 downto 0);
begin
    if(rising_edge(clk)) then
        if(rst = '1')then   
            y_p  <= (others => '0');   
            y_r  <= (others => '0'); 
            u_pr  <= (others => '0');
            u_req <= (others => '0'); 
        else
        
            y_p   <= Kp*(resize(i_ref,32) - resize(i_meas,32));   -- fp 23 w 48
            v2    := a0*y_r; -- fp 36
            v3    := a1*buf_y(0);
            y_r   <= b0*(resize(i_ref,32) - resize(i_meas,32)) + b2*buf_e_k(0) - resize(shift_right(v2,13),48) - resize(shift_right(v3,13),48); -- fp 23
            u_req <= resize(y_p + y_r,64) + shift_left(resize(d0_v_grid,64),17);
        end if;
     end if;
end process;

v_ref <= u_req;

u_shift_buffer_e : shift_buffer
    generic map(
        DATA_WIDTH => DATA_WIDTH_e,
        DEPTH      => DEPTH_e
    )
    port map(
        clk      => clk,
        rst      => rst,
        data_in  => e_k,
        data_out => buf_e_k
    );

u_shift_buffer_y : shift_buffer
    generic map(
        DATA_WIDTH => DATA_WIDTH_y,
        DEPTH      => DEPTH_y
    )
    port map(
        clk      => clk,
        rst      => rst,
        data_in  => y_r,
        data_out => buf_y
    );

end Behavioral;
