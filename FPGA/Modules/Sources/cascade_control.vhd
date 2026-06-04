library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cascade_control is
  port (
    clk         : in  std_logic;
    rst         : in  std_logic;
    ce          : in  std_logic;
    v           : in  signed(31 downto 0); -- fixed point 21
    qv          : in  signed(31 downto 0); -- fixed point 21 
    v_dc        : in  signed(15 downto 0); -- fixed point 8
    v_ref       : in  signed(31 downto 0); -- fixed point 16
    v_grid      : in  signed(15 downto 0); -- fixed point 8
    i_meas      : in  signed(15 downto 0); -- fixed point 10
    i_cap       : in  signed(15 downto 0); -- fixed point 10
    v_out       : out signed(47 downto 0); -- fixed point 29
    grid_error  : out std_logic;
    dc_error_uv : out std_logic;
    dc_error_ov : out std_logic
  );
end entity cascade_control;

architecture Behavioral of cascade_control is

  type state_t is (LOCKING, WORKING);
  signal state : state_t;

  signal phase      : signed(31 downto 0);
  signal phase_comp : signed(31 downto 0);
  
  signal vdc_trip_uv  : signed(15 downto 0) := shift_left(to_signed(41, 16), 8);
  signal vdc_reset_uv : signed(15 downto 0) := shift_left(to_signed(44, 16), 8);
  
  signal vdc_trip_ov  : signed(15 downto 0) := shift_left(to_signed(70, 16), 8);
  signal vdc_reset_ov : signed(15 downto 0) := shift_left(to_signed(65, 16), 8);

  signal pll_error : signed(31 downto 0);

  signal i_ce_current : std_logic;
  signal ce_pll       : std_logic;

  signal timer_count : unsigned(15 downto 0);
  signal timer_tick  : std_logic;

  signal phase_err_flag : std_logic;
  signal amp_err_flag   : std_logic;

  signal i_rst_current : std_logic;

  signal grid_rst_current : std_logic;
  signal dc_rst_current   : std_logic;

  signal grid_ce_current : std_logic;
  signal dc_ce_current   : std_logic;

  signal count      : unsigned(15 downto 0);

  constant PHASE_TRIP  : signed(31 downto 0) := x"000a3d71";
  constant PHASE_RESET : signed(31 downto 0) := x"000f5c29";

  signal ov1 : std_logic;
  signal ov2 : std_logic;
  signal uv1 : std_logic;
  signal uv2 : std_logic;

begin

  u_voltage_protection : entity work.voltage_protection
    port map (
      clk => clk,
      rst => rst,
      ce  => ce,
      v   => v,
      qv  => qv,
      ov1 => ov1,
      ov2 => ov2,
      uv1 => uv1,
      uv2 => uv2
    ); 

  u_current_controller : entity work.current_controller
    port map (
      clk    => clk,
      rst    => i_rst_current,
      ce     => i_ce_current,
      theta  => phase_comp,
      v_dc   => v_dc,
      v_ref  => v_ref,
      v_grid => v_grid,
      i_meas => i_meas,
      i_cap  => i_cap,
      v_out  => v_out
    );
    
  u_pll : entity work.pll
    port map (
      clk   => clk,
      rst   => rst,
      ce    => ce,
      v     => v,
      qv    => qv,
      error => pll_error,
      omega => open,
      phase => phase
    );
    
  u_shift_register : entity work.shift_register
    generic map (
      DATA_WIDTH => 32,
      DEPTH      => 5
    )
    port map (
      clk      => clk,
      rst      => rst,
      ce       => ce,
      data_in  => phase,
      data_out => phase_comp
    );

  process(clk)
  begin
    if rising_edge(clk) then 
      if rst = '1' then 
        timer_tick  <= '0';
        timer_count <= (others => '0');
      elsif ce = '1' then 
        if timer_count < to_unsigned(49, 16) then
          timer_tick  <= '0';
          timer_count <= timer_count + 1;
        else
          timer_tick  <= '1';
          timer_count <= (others => '0');
        end if;
      end if;
    end if;
  end process;
  
  i_rst_current <= rst or dc_rst_current or grid_rst_current;
  i_ce_current  <= ce when (dc_ce_current = '1' and grid_ce_current = '1') else '0';
  grid_error    <= phase_err_flag or amp_err_flag;
  
  process(clk)
  begin
    if rising_edge(clk) then 
      if rst = '1' then
        state <= LOCKING;
        
        ce_pll          <= '0'; 
        dc_ce_current   <= '0';
        grid_ce_current <= '0';
        
        dc_rst_current   <= '1';
        grid_rst_current <= '1';
        
        count <= (others => '0');
        
        dc_error_uv    <= '1';
        dc_error_ov    <= '0';
        phase_err_flag <= '1';
        amp_err_flag   <= '1';
      elsif ce = '1' then
        case state is
          when LOCKING =>
            ce_pll         <= '1';   
            phase_err_flag <= '1';
            
            if abs(pll_error) < PHASE_RESET then
              if count > to_unsigned(200, 16) then 
                state <= WORKING;
                count <= (others => '0');
              elsif timer_tick = '1' then
                count <= count + 1;
              end if;
            else   
              count <= (others => '0');
            end if;
                                            
          when WORKING =>
            phase_err_flag <= '0';
        
            if abs(pll_error) > PHASE_TRIP then
              if count > to_unsigned(200, 16) then 
                state <= LOCKING;
                count <= (others => '0');
              elsif timer_tick = '1' then
                count <= count + 1;
              end if;
            else
              count <= (others => '0');
            end if; 
             
            if v_dc < vdc_trip_uv then 
              dc_error_uv    <= '1';                      
              dc_ce_current  <= '0';
              dc_rst_current <= '1';
            elsif v_dc > vdc_reset_uv then
              dc_error_uv    <= '0';
              dc_ce_current  <= '1';
              dc_rst_current <= '0';
            end if;
            
            if v_dc > vdc_trip_ov then 
              dc_error_ov <= '1';                      
            elsif v_dc < vdc_reset_ov then
              dc_error_ov <= '0';
            end if;
                
            if ov1 = '1' or ov2 = '1' or uv1 = '1' or uv2 = '1' then
              grid_ce_current  <= '0';
              grid_rst_current <= '1';
              amp_err_flag     <= '1';
            else
              grid_ce_current  <= '1';
              grid_rst_current <= '0';
              amp_err_flag     <= '0';
            end if;       
                                          
        end case;
      end if;
    end if;
  end process;
                               
end architecture Behavioral;