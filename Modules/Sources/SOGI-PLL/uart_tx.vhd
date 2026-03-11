library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity uart_tx is
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
end uart_tx;

architecture behavioral of uart_tx is

    constant DIVIDER     : integer := 100000000 / BAUD_RATE;
    constant FRAME_WIDTH : integer := WIDTH + 2 * ((WIDTH / 8) - 1) + 2;

    type state_machine is (IDLE, LATCH, TRANSMIT);
    signal state : state_machine := IDLE;

    signal bit_index  : integer range 0 to 150;
    signal clk_count  : integer range 0 to 100000000 / BAUD_RATE;

    signal data_frame : std_logic_vector(FRAME_WIDTH - 1 downto 0);
    signal data_latch : std_logic_vector(FRAME_WIDTH - 1 downto 0);


begin

    process(clk)
    begin
        if(rising_edge(clk)) then
            if (rst = '1') then

                data_latch    <= (others => '1');
               
                data_frame    <= (others => '0');
                data_frame(0) <= '0';
                data_frame(FRAME_WIDTH - 1) <= '1';
    
                for i in 1 to (WIDTH / 8) - 1 loop
                    data_frame(8 * i + 1 + (i-1)*2) <= '1';
                    data_frame(8 * i + 2 + (i-1)*2) <= '0';
                end loop;
    
                clk_count <= 0;
                state     <= IDLE;
                tx        <= '1';
                busy      <= '1';
                bit_index <= 0;
            else       
                case state is
                    when IDLE =>
    
                        if (tx_request = '1') then
    
                            for i in 0 to (WIDTH / 8) - 1 loop
                                data_frame(10 * i + 8 downto 10 * i + 1) <= data_in(i * 8 + 7 downto i * 8);
                            end loop;
                            bit_index <= 0;
                            clk_count <= 0;
                            state <= LATCH;
                        else
                            state <= IDLE;
                            tx    <= '1';
                        end if;
    
                    when LATCH =>
    
                        data_latch <= data_frame;
                        state      <= TRANSMIT;
    
                    when TRANSMIT =>
    
                        if (clk_count = DIVIDER - 1) then
                            clk_count  <= 0;
                            bit_index  <= bit_index + 1;
                            data_latch <= '1' & data_latch(FRAME_WIDTH - 1 downto 1);
                        else
                            clk_count <= clk_count + 1;
                        end if;
    
                        if (bit_index >= FRAME_WIDTH - 1) then
                            state <= IDLE;
                        end if;
                end case;
                tx <= data_latch(0);
            end if;
        end if;
    end process;

end behavioral;