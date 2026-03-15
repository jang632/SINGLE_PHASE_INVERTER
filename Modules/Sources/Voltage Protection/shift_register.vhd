library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity shift_register is
    generic (
        WIDTH  : integer := 32;
        LENGTH : integer := 15
    );
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        ce          : in  std_logic;
        v_alpha     : in  signed(WIDTH-1 DOWNTO 0);
        v_beta      : in  signed(WIDTH-1 DOWNTO 0);
        v_alpha_del : out signed(WIDTH-1 DOWNTO 0);
        v_beta_del  : out signed(WIDTH-1 DOWNTO 0)
    );
end shift_register;

architecture Behavioral of shift_register is

    type delay_array is array(0 to LENGTH-1) of signed(WIDTH-1 downto 0);
    signal alpha_delay_line : delay_array := (others => (others => '0'));
    signal beta_delay_line  : delay_array := (others => (others => '0'));

begin

    process(clk)
    begin
           if (rising_edge(clk)) then
                if(reset = '1') then 
                    alpha_delay_line <= (others => (others => '0'));
                    beta_delay_line  <= (others => (others => '0'));
                    v_alpha_del      <= (others => '0');
                    v_beta_del       <= (others => '0');
                else
                    if(ce = '1') then
                        for i in LENGTH-1 downto 1 loop
                            alpha_delay_line(i) <= alpha_delay_line(i - 1);
                            beta_delay_line(i)  <= beta_delay_line(i - 1);
                        end loop;
                        alpha_delay_line(0) <= v_alpha;
                        beta_delay_line(0)  <= v_beta;
                        v_alpha_del <= alpha_delay_line(LENGTH-1);
                        v_beta_del  <= beta_delay_line(LENGTH-1);
                     end if;
                end if;     
        end if;
    end process;

end Behavioral;
