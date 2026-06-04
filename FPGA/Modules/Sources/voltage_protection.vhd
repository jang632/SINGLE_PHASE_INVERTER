library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity voltage_protection is
  port (
    clk : in  std_logic;
    rst : in  std_logic;
    ce  : in  std_logic;
    v   : in  signed(31 downto 0); -- fixed point 21
    qv  : in  signed(31 downto 0); -- fixed point 21
    ov1 : out std_logic;
    ov2 : out std_logic;
    uv1 : out std_logic;
    uv2 : out std_logic
  );
end entity voltage_protection;

architecture Behavioral of voltage_protection is

  signal enable : std_logic;

  signal magnitude     : signed(31 downto 0);          -- fixed point 19
  signal magnitude_ema : signed(31 downto 0);          -- fixed point 19

  type machine_t is (LOCKING, RUNNING);
  signal state : machine_t;

  signal ov1_flag : std_logic;
  signal ov2_flag : std_logic;
  signal uv1_flag : std_logic;
  signal uv2_flag : std_logic;

  signal count : unsigned(15 downto 0);

  signal timer_count : unsigned(15 downto 0);
  signal timer_tick  : std_logic;

  signal ov1_count : unsigned(15 downto 0);
  signal uv1_count : unsigned(15 downto 0);
  signal ov2_count : unsigned(15 downto 0);
  signal uv2_count : unsigned(15 downto 0);

  constant FIXED_POINT : integer := 2**19;

  constant OV1_TRIP  : signed(31 downto 0) := to_signed(43 * FIXED_POINT, 32);
  constant OV1_RESET : signed(31 downto 0) := to_signed(42 * FIXED_POINT, 32);

  constant UV1_TRIP  : signed(31 downto 0) := to_signed(33 * FIXED_POINT, 32);
  constant UV1_RESET : signed(31 downto 0) := to_signed(34 * FIXED_POINT, 32);

  constant OV2_TRIP  : signed(31 downto 0) := to_signed(45 * FIXED_POINT, 32);
  constant OV2_RESET : signed(31 downto 0) := to_signed(44 * FIXED_POINT, 32);

  constant UV2_TRIP  : signed(31 downto 0) := to_signed(31 * FIXED_POINT, 32);
  constant UV2_RESET : signed(31 downto 0) := to_signed(32 * FIXED_POINT, 32);

  constant MAG_EMA : signed(31 downto 0) := to_signed(39 * FIXED_POINT, 32);

begin

  u_cordic_mag : entity work.cordic_mag
    generic map (
      ITERATIONS => 16
    )
    port map (
      clk       => clk,
      reset     => rst,
      ce        => ce,
      x         => v,
      y         => qv,
      magnitude => magnitude_ema
    );
    
  u_ema_filter : entity work.ema_filter
    generic map (
      INIT     => MAG_EMA,
      STRENGTH => 9
    )
    port map (
      clk      => clk,
      reset    => rst,
      ce       => ce,
      data_in  => magnitude_ema,
      data_out => magnitude
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
  
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then 
        state <= LOCKING;
        count <= (others => '0');
        
        uv1_flag <= '0';
        uv2_flag <= '0';
        ov1_flag <= '0';
        ov2_flag <= '0';
        
        ov1_count <= (others => '0');
        ov2_count <= (others => '0');
        uv1_count <= (others => '0');
        uv2_count <= (others => '0');
      elsif ce = '1' then 
        case state is
          when LOCKING =>
            if count > to_unsigned(200, 16) then 
              state <= RUNNING;
            elsif timer_tick = '1' then
              count <= count + 1;
            end if;
          when RUNNING =>
            
            if magnitude > OV1_TRIP then
              if ov1_count < to_unsigned(2000, 16) then
                if timer_tick = '1' then
                  ov1_count <= ov1_count + 1;
                end if;
              else
                ov1_flag <= '1';
              end if; 
            elsif magnitude < OV1_RESET then
              ov1_flag  <= '0';
              ov1_count <= (others => '0');
            end if;
            
            if magnitude > OV2_TRIP then
              if ov2_count < to_unsigned(10, 16) then
                if timer_tick = '1' then
                  ov2_count <= ov2_count + 1;
                end if;
              else
                ov2_flag  <= '1';
                ov1_count <= (others => '0');
                ov1_flag  <= '0';
              end if; 
            elsif magnitude < OV2_RESET then
              ov2_flag  <= '0';
              ov2_count <= (others => '0');
            end if;
            
            if magnitude < UV1_TRIP then
              if uv1_count < to_unsigned(2000, 16) then
                if timer_tick = '1' then
                  uv1_count <= uv1_count + 1;
                end if;
              else
                uv1_flag <= '1';
              end if; 
            elsif magnitude > UV1_RESET then
              uv1_flag  <= '0';
              uv1_count <= (others => '0');
            end if;
            
            if magnitude < UV2_TRIP then
              if uv2_count < to_unsigned(10, 16) then
                if timer_tick = '1' then
                  uv2_count <= uv2_count + 1;
                end if;
              else
                uv2_flag  <= '1';
                uv1_count <= (others => '0');
                uv1_flag  <= '0';
              end if; 
            elsif magnitude > UV2_RESET then
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

end architecture Behavioral;