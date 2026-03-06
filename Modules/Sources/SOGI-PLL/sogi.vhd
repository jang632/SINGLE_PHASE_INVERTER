library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pkg is
    type t_array is array (natural range <>) of signed;
end package;

package body pkg is
end package body;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.pkg.all;

entity sogi is
    generic(
        WIDTH : integer := 16
    );
    port(
        clk : in  std_logic;
        rst : in  std_logic;
        ce  : in  std_logic;
        v_n : in  signed(WIDTH-1 downto 0);
        v   : out signed(2*WIDTH-1 downto 0);
        qv  : out signed(2*WIDTH-1 downto 0)
    );
end sogi;

architecture behavioral of sogi is

component shift_buffer
generic(
    LENGTH : integer := 3;
    WIDTH  : integer := 8
);
port(
    clk      : in std_logic;
    rst      : in std_logic;
    ce       : in std_logic;
    data_in  : in signed(WIDTH-1 downto 0);
    data_out : out t_array(0 to LENGTH-1)(WIDTH-1 downto 0)
);
end component;

signal array_v_n   : t_array(0 to 1)(WIDTH-1 downto 0);

signal r_v         : signed(2*WIDTH-1 downto 0) := (others => '0');
signal a_mul_reg_1 : signed(63 downto 0) := (others => '0');
signal a_add_reg   : signed(63 downto 0) := (others => '0');

signal r_qv        : signed(2*WIDTH-1 downto 0) := (others => '0');
signal b_mul_reg_1 : signed(63 downto 0) := (others => '0');
signal b_add_reg   : signed(63 downto 0) := (others => '0');

constant X     : signed(31 downto 0) := x"003A3BD7";
constant Y     : signed(31 downto 0) := x"00002965";
constant D     : signed(31 downto 0) := x"403A653D";
constant INV_D : signed(31 downto 0) := x"03FC5CFE";
constant M0    : signed(31 downto 0) := x"7FFFAD35";
constant M1    : signed(31 downto 0) := x"3FC5ED8E";
constant KY    : signed(31 downto 0) := x"00002ED6";

begin

u_shift_buffer_v : shift_buffer
generic map(
    LENGTH => 2,
    WIDTH  => WIDTH
)
port map(
    clk      => clk,
    rst      => rst,
    ce       => ce,
    data_in  => v_n,
    data_out => array_v_n
);

process(clk)
variable sub_var   : signed(31 downto 0);
variable mul_var_1 : signed(63 downto 0);
variable mul_var_2 : signed(63 downto 0);
variable out_var   : signed(63 downto 0);
begin
    if (rising_edge(clk)) then
        if(rst = '1') then
            a_mul_reg_1 <= (others => '0');
            a_add_reg   <= (others => '0');
            r_v         <= (others => '0');
        else
            if(ce = '1') then
                out_var := shift_right(resize(a_add_reg, 32) * INV_D, 28);

                sub_var := resize(v_n - array_v_n(1), 32);
                a_mul_reg_1 <= X * sub_var;

                mul_var_1 := M0 * resize(out_var, 32);
                mul_var_2 := M1 * r_v;

                a_add_reg <= (
                    shift_right(a_mul_reg_1, 16) +
                    shift_right(mul_var_1, 28) -
                    shift_right(mul_var_2, 28)
                );

                r_v <= resize(out_var, 2*WIDTH);
            end if;
        end if;
    end if;
end process;

process(clk)
variable sub_var   : signed(31 downto 0);
variable mul_var_1 : signed(63 downto 0);
variable mul_var_2 : signed(63 downto 0);
variable out_var   : signed(63 downto 0);
begin
    if (rising_edge(clk)) then
        if(rst = '1') then
            b_mul_reg_1 <= (others => '0');
            b_add_reg   <= (others => '0');
            r_qv        <= (others => '0');
        else
            if(ce = '1') then
                out_var := shift_right(resize(b_add_reg, 32) * INV_D, 28);

                sub_var := resize(
                    v_n +
                    shift_left(resize(array_v_n(0), 32), 1) +
                    array_v_n(1),
                    32
                );

                b_mul_reg_1 <= KY * sub_var;

                mul_var_1 := M0 * resize(out_var, 32);
                mul_var_2 := M1 * r_qv;

                b_add_reg <= (
                    shift_right(b_mul_reg_1, 16) +
                    shift_right(mul_var_1, 28) -
                    shift_right(mul_var_2, 28)
                );

                r_qv <= resize(out_var(31 downto 0), 2*WIDTH);
            end if;
        end if;
    end if;
end process;

v  <= r_v;
qv <= r_qv;

end behavioral;