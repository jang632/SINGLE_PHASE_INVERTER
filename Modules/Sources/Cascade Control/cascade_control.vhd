
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity cascade_control is
    port(
        clk    : in std_logic;
        rst    : in std_logic;
        ce     : in std_logic;
        v_dc   : in  signed(15 downto 0); -- fixed point 9
        v_ref  : in  signed(31 downto 0); -- fixed point 16
        v_grid : in  signed(15 downto 0); -- fixed point 9
        i_meas : in  signed(15 downto 0); -- fixed point 10
        i_cap  : in  signed(15 downto 0);
        v_out  : out signed(47 downto 0)
    );
        
end cascade_control;

architecture Behavioral of cascade_control is

component srf_pll is
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        ce     : in  std_logic;
        v_n    : in  signed(15 downto 0);
        v_sogi : out signed(31 downto 0);
        error  : out signed(31 downto 0);
        omega  : out signed(31 downto 0); -- fixed point 20
        phase  : out signed(31 downto 0)  -- fixed point 28
    );
end component;

component current_controller is
    port(
        clk    : in  std_logic;
        rst    : in  std_logic;
        ce     : in  std_logic;
        theta  : in  signed(31 downto 0); -- fixed point 28
        v_dc   : in  signed(15 downto 0); -- fixed point 9
        v_ref  : in  signed(31 downto 0); -- fixed point 16
        v_grid : in  signed(15 downto 0); -- fixed point 9
        i_meas : in  signed(15 downto 0); -- fixed point 10
        i_cap  : in  signed(15 downto 0);
        v_out  : out signed(47 downto 0)  -- fixed point 31
    );
end component;

type machine is (LOCKING, WORKING);
signal state : machine;

signal phase        : signed(31 downto 0);
signal error        : signed(31 downto 0);

signal ce_current : std_logic;
signal ce_pll     : std_logic;

signal timer_count : unsigned(15 downto 0);
signal timer_tick  : std_logic;

signal rst_current  : std_logic;
signal i_rst_current  : std_logic;


signal count : unsigned(15 downto 0);
signal uvlo_count : unsigned(15 downto 0);

constant PHASE_TRIP  : signed(31 downto 0) := x"000a3d71";
constant PHASE_RESET : signed(31 downto 0) := x"000f5c29";

begin

u_current_controller : current_controller
    port map (
        clk    => clk,
        rst    => rst_current,
        ce     => ce_current,
        theta  => phase,
        v_dc   => v_dc,
        v_ref  => v_ref,
        v_grid => v_grid,
        i_meas => i_meas,
        i_cap  => i_cap,
        v_out  => v_out
    );

u_srf_pll : srf_pll
    port map(
        clk    => clk,
        rst    => rst,
        ce     => ce_pll,
        v_n    => v_grid,
        v_sogi => OPEN, 
        error  => error,
        omega  => OPEN,
        phase  => phase
    );
    
    process(clk)
    begin
        if(rising_edge(clk)) then 
            if(rst = '1') then 
                timer_tick  <= '0';
                timer_count <= (others => '0');
            elsif(ce = '1') then 
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
    
    rst_current <= rst or i_rst_current;
    
    process(clk)
    begin
        if(rst = '1') then
            state <= LOCKING;
            ce_pll      <= '0';    
            ce_current  <= '0';
            count       <= (others => '0');
            uvlo_count  <= (others => '0');
            i_rst_current <= '1';
        else
            if(ce = '1') then
                case(state) is
                    when LOCKING =>
                        ce_pll     <= '1';    
                        ce_current <= '0';
                        
                        if(abs(error) < PHASE_RESET) then
                            if(count > to_unsigned(200, 16)) then 
                                state <= WORKING;
                                count <= (others => '0');
                            elsif(timer_tick = '1') then
                                count <= count + 1;
                            end if;
                         else   
                            count <= (others => '0');
                         end if;
                                    
                    when WORKING =>
                        if(abs(error) > PHASE_TRIP) then
                            if(count > to_unsigned(200, 16)) then 
                                state <= LOCKING;
                                count <= (others => '0');
                            elsif(timer_tick = '1') then
                                count <= count + 1;
                            end if;
                         else
                            count <= (others => '0');
                         end if; 
                         
                         if(v_dc < x"2900") then                       
                            ce_current <= '0';
                            i_rst_current <= '1';
                            uvlo_count <= (others => '0');
                         elsif(v_dc > x"2c00") then
                            if(uvlo_count > to_unsigned(40, 16)) then 
                                uvlo_count <= (others => '0');
                                ce_current <= '1';
                                i_rst_current <= '0';
                            elsif(timer_tick = '1') then
                                uvlo_count <= uvlo_count + 1;
                            end if;
                         end if;               
                        ce_pll <= '1';
                end case;
           end if;
      end if;
 end process;
                            
end Behavioral;