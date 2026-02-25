----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 22.02.2026 17:53:52
-- Design Name: 
-- Module Name: shift_buffer - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

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

entity shift_buffer is
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
end shift_buffer;

architecture Behavioral of shift_buffer is
    signal r_data_out : t_array(0 to DEPTH-1)(DATA_WIDTH-1 downto 0) := (others => (others => '0'));
begin

process(clk)
    variable i : integer;
begin
    if(rising_edge(clk)) then 
        if(rst = '1') then
            r_data_out <= (others => (others => '0'));
        else
            r_data_out(0) <= data_in;
            for i in DEPTH-1 downto 1 loop
                r_data_out(i) <= r_data_out(i-1);
            end loop;
        end if;
    end if;
end process;

data_out <= r_data_out;

end Behavioral;
