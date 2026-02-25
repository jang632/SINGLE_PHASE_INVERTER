library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.MATH_REAL.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spwm is
    generic (
        WIDTH             : integer := 16;
        CARRIER_FREQUENCY : integer := 20000;
        CLK_FREQ          : integer := 50000000
    );
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        v_ref  : in  signed(WIDTH-1 downto 0);
        a_low  : out std_logic;
        a_high : out std_logic;
        b_low  : out std_logic;
        b_high : out std_logic
    );
end spwm;

architecture Behavioral of spwm is

    component up_down_counter
        generic (
            WIDTH             : integer := 8;
            MAX_RANGE         : integer := 126;
            CARRIER_FREQUENCY : integer := 20000;
            CLK_FREQ          : integer := 50000000
        );
        port (
            clk    : in  std_logic;
            rst    : in  std_logic;
            output : out signed(WIDTH-1 downto 0)
        );
    end component;
    
    constant MAX_RANGE : integer := 32766;
    
    signal v_ref_minus : signed(WIDTH-1 downto 0);
    signal counter     : signed(WIDTH-1 downto 0);
            
begin

    v_ref_minus <= -v_ref;

    u_up_down_counter : up_down_counter
        generic map(
            WIDTH             => WIDTH,
            MAX_RANGE         => MAX_RANGE,
            CARRIER_FREQUENCY => CARRIER_FREQUENCY,
            CLK_FREQ          => CLK_FREQ
        )
        port map(
            clk     => clk,
            rst     => rst,
            output  => counter
        );

    PROCESS(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                a_low  <= '0';
                a_high <= '0';
            else
                if counter > v_ref then
                    a_high <= '1';
                    a_low  <= '0';
                else
                    a_high <= '0';
                    a_low  <= '1';
                end if;
            end if;
        end if;
    END PROCESS;

    PROCESS(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                b_low  <= '0';
                b_high <= '0';
            else
                if counter > v_ref_minus then
                    b_high <= '1';
                    b_low  <= '0';
                else
                    b_high <= '0';
                    b_low  <= '1';
                end if;
            end if;
        end if;
    END PROCESS;

end Behavioral;
