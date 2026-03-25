library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cordic_sin_cos is
    generic( 
        iterations : integer;
        WIDTH      : integer := 16;
        OUT_FP     : integer := 14
    );
    port(
        clk       : in  std_logic;
        reset     : in  std_logic;
        ce        : in  std_logic;
        theta     : in  signed(31 downto 0);
        sin_value : out signed(WIDTH-1 downto 0);
        cos_value : out signed(WIDTH-1 downto 0)
    );     
end cordic_sin_cos;

architecture behavioral of cordic_sin_cos is

    type pipelined_io is record 
        pip_theta    : signed(31 downto 0);
        pip_sin      : signed(WIDTH-1 downto 0);
        pip_cos      : signed(WIDTH-1 downto 0);
        pip_quadrant : std_logic_vector(1 downto 0);
    end record pipelined_io;

    type pipe_stages is array (0 to 15) of pipelined_io;
    signal pipeline : pipe_stages;

    constant PI_OVER_2       : signed(31 downto 0)      := to_signed(421657429, 32);
    constant PI              : signed(31 downto 0)      := to_signed(843314857, 32);
    constant THREE_PI_OVER_2 : signed(31 downto 0)      := to_signed(1264972286, 32);
    constant TWO_PI          : signed(31 downto 0)      := to_signed(1686629714, 32);
    constant CORDIC_CONST    : signed(WIDTH-1 downto 0) := to_signed(integer(0.607252935*2.0**OUT_FP),WIDTH);

    type angle_array is array (0 to 16-1) of signed(31 downto 0);

    constant angles : angle_array := (
        0  => to_signed(integer(0.7853981633974483 * 268435456.0), 32),
        1  => to_signed(integer(0.4636476090008061 * 268435456.0), 32),
        2  => to_signed(integer(0.24497866312686414 * 268435456.0), 32),
        3  => to_signed(integer(0.12435499454676144 * 268435456.0), 32),
        4  => to_signed(integer(0.06241880999595735 * 268435456.0), 32),
        5  => to_signed(integer(0.031239833430268277 * 268435456.0), 32),
        6  => to_signed(integer(0.015623728620476831 * 268435456.0), 32),
        7  => to_signed(integer(0.007812341060101111 * 268435456.0), 32),
        8  => to_signed(integer(0.0039062301319669718 * 268435456.0), 32),
        9  => to_signed(integer(0.0019531225164788188 * 268435456.0), 32),
        10 => to_signed(integer(0.0009765621895593195 * 268435456.0), 32),
        11 => to_signed(integer(0.0004882812111948983 * 268435456.0), 32),
        12 => to_signed(integer(0.00024414062014936177 * 268435456.0), 32),
        13 => to_signed(integer(0.00012207031189367021 * 268435456.0), 32),
        14 => to_signed(integer(6.103515617420877e-05 * 268435456.0), 32),
        15 => to_signed(integer(3.0517578115526096e-05 * 268435456.0), 32)
    );

begin

    process(clk)
    begin 
           if rising_edge(clk) then
            if (reset = '1') then
                pipeline <= (others => ((others => '0'), (others => '0'), (others => '0'), (others => '0')));
            else
                if (ce = '1') then
                    if(signed(theta) < PI_OVER_2) then
                        pipeline(0).pip_theta    <= theta;
                        pipeline(0).pip_quadrant <= "00";
                    elsif(signed(theta) <= PI) then
                        pipeline(0).pip_theta    <= PI - theta;
                        pipeline(0).pip_quadrant <= "01";
                    elsif(signed(theta) <= THREE_PI_OVER_2) then
                        pipeline(0).pip_theta    <= theta - PI;
                        pipeline(0).pip_quadrant <= "10";
                    elsif(signed(theta) <= TWO_PI) then
                        pipeline(0).pip_theta    <= TWO_PI - theta;
                        pipeline(0).pip_quadrant <= "11";
                    else
                        pipeline(0).pip_theta    <= (others => '0');
                        pipeline(0).pip_quadrant <= "00";
                    end if;
    
                    pipeline(0).pip_cos <= CORDIC_CONST;
                    pipeline(0).pip_sin <= (others => '0');
    
                    for i in 0 to iterations-2 loop
                        if(pipeline(i).pip_theta < 0) then
                            pipeline(i+1).pip_cos      <= pipeline(i).pip_cos + shift_right(pipeline(i).pip_sin, i);
                            pipeline(i+1).pip_sin      <= pipeline(i).pip_sin - shift_right(pipeline(i).pip_cos, i);
                            pipeline(i+1).pip_quadrant <= pipeline(i).pip_quadrant;
                            pipeline(i+1).pip_theta    <= pipeline(i).pip_theta + angles(i);
                        else
                            pipeline(i+1).pip_sin      <= pipeline(i).pip_sin + shift_right(pipeline(i).pip_cos, i);
                            pipeline(i+1).pip_cos      <= pipeline(i).pip_cos - shift_right(pipeline(i).pip_sin, i);
                            pipeline(i+1).pip_quadrant <= pipeline(i).pip_quadrant;
                            pipeline(i+1).pip_theta    <= pipeline(i).pip_theta - angles(i);
                        end if;
                    end loop;
                end if;
            end if;
        end if;
    end process;


    process(pipeline(iterations-1).pip_sin, pipeline(iterations-1).pip_cos)
    begin
        case pipeline(iterations-1).pip_quadrant is
            when "00" =>
                sin_value <= pipeline(iterations-1).pip_sin;
                cos_value <= pipeline(iterations-1).pip_cos;
            when "01" =>
                sin_value <= pipeline(iterations-1).pip_sin;
                cos_value <= -pipeline(iterations-1).pip_cos;
            when "10" =>
                sin_value <= -pipeline(iterations-1).pip_sin;
                cos_value <= -pipeline(iterations-1).pip_cos;
            when others =>
                sin_value <= -pipeline(iterations-1).pip_sin;
                cos_value <= pipeline(iterations-1).pip_cos;
        end case;
    end process;
end behavioral;