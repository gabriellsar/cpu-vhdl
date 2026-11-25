--------------------------------------------------------------------------------
-- clock_enable.vhd
-- Divisor de clock na forma de "clock enable": gera um pulso CE de 1 ciclo a
-- cada TICKS ciclos do clock de 50 MHz. Cada pulso avanca 1 estado da UC.
--
-- Com 4 estados por instrucao e TICKS = 25_000_000 (0,5 s), cada instrucao
-- completa (fetch -> write) leva 2 s.
--
-- CLK_LED: onda quadrada com o mesmo periodo do CE (alta na 1a metade de cada
-- estado), usada no LED "CLOCK" (LD7).
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clock_enable is
    generic (
        TICKS : positive := 25_000_000
    );
    port (
        CLK     : in  std_logic;
        RESET   : in  std_logic;
        CE      : out std_logic;
        CLK_LED : out std_logic
    );
end entity clock_enable;

architecture rtl of clock_enable is
    signal cnt : integer range 0 to TICKS-1 := 0;
begin

    process(CLK)
    begin
        if rising_edge(CLK) then
            if RESET = '1' or cnt = TICKS-1 then
                cnt <= 0;
            else
                cnt <= cnt + 1;
            end if;
        end if;
    end process;

    CE      <= '1' when cnt = TICKS-1 and RESET = '0' else '0';
    CLK_LED <= '1' when cnt < TICKS/2 else '0';

end architecture rtl;
