library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity relay_controller is
  port (
    clk         : in  std_logic;
    rst         : in  std_logic;
    ce          : in  std_logic;
    v_dc        : in  signed(15 downto 0);
    dc_error_uv : in  std_logic;
    dc_error_ov : in  std_logic;
    grid_error  : in  std_logic;
    ce_pwm      : out std_logic;
    relay_dc    : out std_logic;
    relay_dcpc  : out std_logic;
    relay_grid  : out std_logic
  ); 
end entity relay_controller;

architecture Behavioral of relay_controller is

  constant FIXED_POINT         : integer := 2**8;
  
  constant PRECHARGE_THRESHOLD : signed(15 downto 0) := to_signed(38 * FIXED_POINT, 16);
  constant VDC_FAULT_THRESHOLD : signed(15 downto 0) := to_signed(70 * FIXED_POINT, 16);
  
  type machine is (POWER_ON, PRECHARGE, RUNNING, FAULT_DC_OV, FAULT_DC_UV, FAULT_GRID, DISCHARGE, RELAY_DELAY);
  signal state      : machine;
  signal next_state : machine;

  signal delay_count : unsigned(15 downto 0);
  signal timer_tick  : std_logic;
  signal timer_count : unsigned(15 downto 0);

begin

  process(clk)
  begin
    if rising_edge(clk) then 
      if rst = '1' then 
        timer_tick  <= '0';
        timer_count <= (others => '0');
      elsif ce = '1' then 
        if timer_count < to_unsigned(10000, 16) then
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
    if rising_edge(clk) then
      if rst = '1' then
        state       <= POWER_ON;
        next_state  <= POWER_ON;
        ce_pwm      <= '0';
        relay_dc    <= '0';
        relay_dcpc  <= '0';
        relay_grid  <= '0';
        delay_count <= (others => '0');
        
      elsif ce = '1' then          
        if grid_error = '1' then
          ce_pwm <= '0';
          state  <= FAULT_GRID;
          state  <= RELAY_DELAY;
          
          if state = FAULT_GRID then
            state      <= FAULT_GRID;
            next_state <= FAULT_GRID;
          else
            next_state <= FAULT_GRID;
            state      <= RELAY_DELAY;
          end if;
          
        elsif dc_error_ov = '1' then
          next_state <= FAULT_DC_OV;
          state      <= RELAY_DELAY;
          
          if state = FAULT_DC_OV then
            ce_pwm     <= '1';
            state      <= FAULT_DC_OV;
            next_state <= FAULT_DC_OV;
          else
            next_state <= FAULT_DC_OV;
            state      <= RELAY_DELAY;
          end if;
          
        elsif dc_error_uv = '1' and v_dc <= PRECHARGE_THRESHOLD then
          ce_pwm     <= '0';
          next_state <= PRECHARGE;
          state      <= RELAY_DELAY;
          
          if state = PRECHARGE then
            state      <= PRECHARGE;
            next_state <= PRECHARGE;
          else
            next_state <= PRECHARGE;
            state      <= RELAY_DELAY;
          end if;
          
        elsif dc_error_uv = '1' and v_dc > PRECHARGE_THRESHOLD then
          ce_pwm     <= '0';
          next_state <= FAULT_DC_UV;
          state      <= RELAY_DELAY;
          
          if state = FAULT_DC_UV then
            state      <= FAULT_DC_UV;
            next_state <= FAULT_DC_UV;
          else
            next_state <= FAULT_DC_UV;
            state      <= RELAY_DELAY;
          end if;
          
        else
          if state = RUNNING then
            ce_pwm     <= '1';
            state      <= RUNNING;
            next_state <= RUNNING;
          else
            next_state <= RUNNING;
            state      <= RELAY_DELAY;
          end if;
        end if;
        
        case state is                        
          when RELAY_DELAY =>
            case next_state is
              when POWER_ON =>
                relay_dc   <= '0';
                relay_dcpc <= '0';
                relay_grid <= '0';
              when PRECHARGE => 
                relay_dc   <= '0';
                relay_dcpc <= '1';
                relay_grid <= '0';
              when RUNNING =>
                relay_dc   <= '1';
                relay_dcpc <= '0';
                relay_grid <= '1';
              when FAULT_DC_OV =>
                relay_dc   <= '0';
                relay_dcpc <= '0';
                relay_grid <= '1'; 
              when FAULT_DC_UV =>
                relay_dc   <= '1';
                relay_dcpc <= '0';
                relay_grid <= '0'; 
              when FAULT_GRID =>
                relay_dc   <= '0';
                relay_dcpc <= '0';
                relay_grid <= '0';
              when DISCHARGE =>
                relay_dc   <= '0';
                relay_dcpc <= '0';
                relay_grid <= '0';
              when others =>
                relay_dc   <= '0';
                relay_dcpc <= '0';
                relay_grid <= '0';
            end case;
            
            if delay_count < to_unsigned(10, 16) then
              if timer_tick = '1' then
                delay_count <= delay_count + 1;
              else
                delay_count <= delay_count;
              end if;
            else
              state       <= next_state;
              delay_count <= (others => '0');
            end if;
            
          when POWER_ON =>
            relay_dc   <= '0';
            relay_dcpc <= '0';
            relay_grid <= '0';
          when PRECHARGE => 
            relay_dc   <= '0';
            relay_dcpc <= '1';
            relay_grid <= '0';
          when RUNNING =>
            relay_dc   <= '1';
            relay_dcpc <= '0';
            relay_grid <= '1';
          when FAULT_DC_OV =>
            relay_dc   <= '0';
            relay_dcpc <= '0';
            relay_grid <= '1'; 
          when FAULT_DC_UV =>
            relay_dc   <= '1';
            relay_dcpc <= '0';
            relay_grid <= '0'; 
          when FAULT_GRID =>
            relay_dc   <= '0';
            relay_dcpc <= '0';
            relay_grid <= '0';
          when DISCHARGE =>
            relay_dc   <= '0';
            relay_dcpc <= '0';
            relay_grid <= '0';
          when others =>
            relay_dc   <= '0';
            relay_dcpc <= '0';
            relay_grid <= '0';
        end case;          
      end if;  
    end if;
  end process;

end architecture Behavioral;