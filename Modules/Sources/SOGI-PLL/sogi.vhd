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
        v_n : in  signed(WIDTH-1 downto 0);   -- fixed point 15
        v   : out signed(2*WIDTH-1 downto 0); -- fixed point 28
        qv  : out signed(2*WIDTH-1 downto 0)  -- fixed point 28
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

constant COEFF_WIDTH : integer := 32;

signal array_v_n     : t_array(0 to 1)(WIDTH-1 downto 0);
signal array_v_beta  : t_array(0 to 0)(2*WIDTH-1 downto 0);
signal array_v_alpha : t_array(0 to 0)(2*WIDTH-1 downto 0);

signal ff_alpha : signed(COEFF_WIDTH+WIDTH+3 downto 0) := (others => '0');
signal ff_beta  : signed(COEFF_WIDTH+WIDTH+3 downto 0) := (others => '0');

signal v_alpha : signed(2*WIDTH+COEFF_WIDTH+1 downto 0) := (others => '0');
signal v_beta  : signed(2*WIDTH+COEFF_WIDTH+1 downto 0) := (others => '0');


constant b0_alpha   : signed(COEFF_WIDTH-1 downto 0) := x"000E81B9";  -- +0.0035416832
constant b1_alpha   : signed(COEFF_WIDTH-1 downto 0) := x"00000000";  -- +0.0000000000
constant b2_alpha   : signed(COEFF_WIDTH-1 downto 0) := x"FFF17E47";  -- -0.0035416832
constant b0_beta    : signed(COEFF_WIDTH-1 downto 0) := x"00000BAB";  -- +0.0000111265
constant b1_beta    : signed(COEFF_WIDTH-1 downto 0) := x"00001756";  -- +0.0000222531
constant b2_beta    : signed(COEFF_WIDTH-1 downto 0) := x"00000BAB";  -- +0.0000111265
constant a1         : signed(COEFF_WIDTH-1 downto 0) := x"1FE2D34E";  -- +1.9928772955
constant a2         : signed(COEFF_WIDTH-1 downto 0) := x"F01D0373";  -- -0.9929166337

constant SATURATION_v  : signed(2*WIDTH-1 downto 0) := x"07eb34ae";
constant SATURATION_qv : signed(2*WIDTH-1 downto 0) := x"07eb496b";

signal c_v   : signed(2*WIDTH-1 downto 0); -- fixed point 28
signal c_qv  : signed(2*WIDTH-1 downto 0);  -- fixed point 28


function truncate(value_in : signed; limit : signed) return signed is
    variable value_out : signed(value_in'range);
begin
    if value_in > limit then
        value_out := limit;
    elsif value_in < -limit then
        value_out := -limit;
    else
        value_out := value_in;
    end if;  
    return value_out;
end function;

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

u_shift_buffer_v_beta : shift_buffer
generic map(
    LENGTH => 1,
    WIDTH  => 2*WIDTH
)
port map(
    clk      => clk,
    rst      => rst,
    ce       => ce,
    data_in  => c_qv,
    data_out => array_v_beta
);

u_shift_buffer_v_alpha : shift_buffer
generic map(
    LENGTH => 1,
    WIDTH  => 2*WIDTH
)
port map(
    clk      => clk,
    rst      => rst,
    ce       => ce,
    data_in  => c_v,
    data_out => array_v_alpha
);


process(clk)

variable ff_alpha_shift : signed(2*WIDTH+COEFF_WIDTH downto 0);
variable ff_alpha_scale : signed(2*WIDTH+COEFF_WIDTH downto 0);

variable ff_alpha_m0 : signed(COEFF_WIDTH+WIDTH downto 0);
variable ff_alpha_m1 : signed(COEFF_WIDTH+WIDTH downto 0);
variable ff_alpha_m2 : signed(COEFF_WIDTH+WIDTH downto 0);

variable fb_alpha    : signed(2*WIDTH+COEFF_WIDTH downto 0);
variable fb_alpha_m0 : signed(2*WIDTH+COEFF_WIDTH downto 0);
variable fb_alpha_m1 : signed(2*WIDTH+COEFF_WIDTH downto 0);

begin
    if (rising_edge(clk)) then
        if(rst = '1') then
            ff_alpha <= (others => '0');
            v_alpha   <= (others => '0');
        else
            if(ce = '1') then
                ff_alpha_m0 := b0_alpha*resize(v_n,17); -- fixed point 34
                ff_alpha_m1 := b1_alpha*resize(array_v_n(0),17); -- fixed point 34
                ff_alpha_m2 := b2_alpha*resize(array_v_n(1),17); -- fixed point 34
                ff_alpha <= resize(ff_alpha_m0,52) + resize(ff_alpha_m1,52) + resize(ff_alpha_m2,52); -- fixed point 34
                
                ff_alpha_scale := resize(ff_alpha,65);
                ff_alpha_shift := shift_left(ff_alpha_scale, 13); -- fixed point 56
                
                fb_alpha_m0 := a1*resize(c_v,33); -- fixed point 56
                fb_alpha_m1 := a2*resize(array_v_alpha(0),33); -- fixed point 56
                fb_alpha := resize(fb_alpha_m0,65) + resize(fb_alpha_m1,65);
                                              
                v_alpha <= shift_left(resize(fb_alpha,66) + resize(ff_alpha_shift,66),6); -- fixed point 62               
            end if;
        end if;
    end if;
end process;

c_v <= v_alpha(2*WIDTH+COEFF_WIDTH+1 downto 2*WIDTH+COEFF_WIDTH-(2*WIDTH-2));
v   <= c_v;


process(clk)

variable ff_beta_shift : signed(2*WIDTH+COEFF_WIDTH downto 0);
variable ff_beta_scale : signed(2*WIDTH+COEFF_WIDTH downto 0);

variable ff_beta_m0 : signed(COEFF_WIDTH+WIDTH downto 0);
variable ff_beta_m1 : signed(COEFF_WIDTH+WIDTH downto 0);
variable ff_beta_m2 : signed(COEFF_WIDTH+WIDTH downto 0);

variable fb_beta    : signed(2*WIDTH+COEFF_WIDTH downto 0);
variable fb_beta_m0 : signed(2*WIDTH+COEFF_WIDTH downto 0);
variable fb_beta_m1 : signed(2*WIDTH+COEFF_WIDTH downto 0);

begin
    if (rising_edge(clk)) then
        if(rst = '1') then
            ff_beta <= (others => '0');
            v_beta  <= (others => '0');
        else
            if(ce = '1') then
                ff_beta_m0 := b0_beta*resize(v_n,17); -- fixed point 34
                ff_beta_m1 := b1_beta*resize(array_v_n(0),17); -- fixed point 34
                ff_beta_m2 := b2_beta*resize(array_v_n(1),17); -- fixed point 34
                ff_beta <= resize(ff_beta_m0,52) + resize(ff_beta_m1,52) + resize(ff_beta_m2,52); -- fixed point 34
                
                ff_beta_scale := resize(ff_beta,65);
                ff_beta_shift := shift_left(ff_beta_scale, 13); -- fixed point 56
                
                fb_beta_m0 := a1*resize(c_qv,33); -- fixed point 56
                fb_beta_m1 := a2*resize(array_v_beta(0),33); -- fixed point 56
                fb_beta := resize(fb_beta_m0,65) + resize(fb_beta_m1,65); -- 65 w 
                                              
                v_beta <= shift_left(resize(fb_beta,66) + resize(ff_beta_shift,66),6); -- fixed point 62               
            end if;
        end if;
    end if;
end process;

c_qv <= v_beta(2*WIDTH+COEFF_WIDTH+1 downto 2*WIDTH+COEFF_WIDTH-(2*WIDTH-2));
qv   <= c_qv;

end behavioral;