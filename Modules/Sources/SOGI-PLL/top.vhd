
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity top is
    port(
        clk     : in  std_logic;
        pll_rst : in std_logic;
        rst     : in  std_logic;
        ce      : in  std_logic;
        miso    : in  std_logic;
        sclk    : buffer std_logic;
        ss_n    : buffer std_logic_vector(0 downto 0);
        tx      : out std_logic
    );
end top;

architecture Behavioral of top is

component clk_wiz_0
    port (
        clk_out1 : out std_logic;
        clk_out2 : out std_logic;
        reset    : in  std_logic;
        locked   : out  std_logic;
        clk_in1  : in  std_logic
    );
end component;

component srf_pll is
    port (
        clk   : in  std_logic;
        rst   : in  std_logic;
        ce    : in  std_logic;
        v_n   : in  signed(15 downto 0);
        omega : out signed(31 downto 0); -- fixed point 20
        phase : out signed(31 downto 0)  -- fixed point 28
    );
end component;

component uart_tx is
    generic(
        BAUD_RATE : integer := 115200;
        WIDTH     : integer := 32
    );
    port(
        clk        : in  std_logic;
        rst        : in  std_logic;
        busy       : out std_logic;
        data_in    : in  std_logic_vector(WIDTH-1 downto 0);
        tx_request : in  std_logic;
        tx         : out std_logic
    );
end component;

component spi is
    generic(
        slaves  : integer := 1;   -- number of spi slaves
        d_width : integer := 48   -- data bus width
    );
    port(
        clock   : in     std_logic;                               -- system clock
        reset_n : in     std_logic;                               -- asynchronous reset
        enable  : in     std_logic;                               -- initiate transaction
        cpol    : in     std_logic;                               -- spi clock polarity
        cpha    : in     std_logic;                               -- spi clock phase
        cont    : in     std_logic;                               -- continuous mode command
        clk_div : in     integer;                                 -- system clock cycles per 1/2 period of sclk
        addr    : in     integer;                                 -- address of slave
        miso    : in     std_logic;                               -- master in, slave out
        sclk    : buffer std_logic;                               -- spi clock
        ss_n    : buffer std_logic_vector(slaves-1 downto 0);     -- slave select
        busy    : out    std_logic;                               -- busy / data ready signal
        rx_data : out    std_logic_vector(d_width-1 downto 0)     -- data received
    );
end component spi;

attribute DONT_TOUCH : string;
attribute DONT_TOUCH of u_srf_pll : label is "TRUE";

signal clk_10M : std_logic := '0';
signal clk_100M : std_logic := '0';

signal locked  : std_logic;
signal n_ce  : std_logic;


signal v_n       : signed(15 downto 0);
signal phase     : signed(31 downto 0);
signal omega     : signed(31 downto 0);


signal std_phase : std_logic_vector(63 downto 0);

signal spi_ena : std_logic;
signal spi_cont : std_logic;

signal spi_index : unsigned(15 downto 0);
signal uart_index : unsigned(15 downto 0);

signal rx_data : std_logic_vector(15 downto 0);

signal tx_request : std_logic := '0';


begin

u_pll : clk_wiz_0
    port map (
        clk_out1 => clk_10M,
        clk_out2 => clk_100M,
        reset    => pll_rst,
        locked   => locked,
        clk_in1  => clk
    );

u_srf_pll : srf_pll
    port map(
        clk   => clk_10M,
        rst   => rst,
        ce    => ce,
        v_n   => v_n,
        omega => omega,
        phase => phase
    );
    

u_uart_tx : uart_tx
    generic map(
        BAUD_RATE => 230400,
        WIDTH     => 64
    )
    port map(
        clk        => clk_100M,
        rst        => rst,
        busy       => open,
        data_in    => std_phase,
        tx_request => tx_request,
        tx         => tx 
    );


u_spi : spi
    generic map(
        slaves  => 1,
        d_width => 16 
    )
    port map(
        clock   => clk_100M,
        reset_n => rst,
        enable  => spi_ena,
        cpol    => '1',
        cpha    => '1',
        cont    => spi_cont,
        clk_div => 25,
        addr    => 0,
        miso    => miso,
        sclk    => sclk,
        ss_n    => ss_n,
        busy    => open,
        rx_data => rx_data 
    );

process(clk_100M)
begin 
    if(rising_edge(clk_100M)) then 
       if(rst = '1') THEN 
        spi_ena <= '0';
        spi_cont <= '0';
        spi_index <= (others => '0');
   else 
      if(ce = '1') then
          if(spi_index < x"07cf") then 
            spi_index <= spi_index + 1;
            spi_ena <= '0';
            spi_cont <= '0';
          else
            spi_ena <= '1';
            spi_cont <= '1';
            spi_index <= x"0000";
          end if; 
       end if;
   end if;
   end if;
end process;


process(clk_100M)
begin 
    if(rising_edge(clk_100M)) then 
       if(rst = '1') then 
        tx_request <= '0';
        uart_index <= (others => '0');
       else 
          if(ce = '1') then
              if(uart_index < x"cf08") then 
                uart_index <= uart_index + 1;
                tx_request <= '0';
              else
                tx_request <= '1';
                uart_index <= x"0000";
              end if; 
            end if;
       end if;
     end if;
end process;

process(clk_10M)
begin
    if(rising_edge(clk_10M)) then
        if(rst = '1') then
            v_n <= (others => '0');
            std_phase <= (others => '0');
        else          
            v_n       <= signed(rx_data);
            std_phase <= std_logic_vector(phase) & rx_data & x"55" & x"AA";
        end if;
    end if;
end process;

n_ce <= not ce;

end Behavioral;
