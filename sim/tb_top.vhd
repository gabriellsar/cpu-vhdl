--------------------------------------------------------------------------------
-- tb_top.vhd
-- Testbench do topo (cpu_top): alem da CPU, exercita o controlador do LCD.
-- Um modelo simples do HD44780 (4 bits) decodifica LCD_E/LCD_RS/SF_D e mantem
-- a DDRAM de 2x16; o ultimo quadro completo do display e os LEDs sao impressos a cada 5 ms.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_top is
    generic (
        STATE_TICKS : positive := 10_000;    -- 0,2 ms por estado (simulacao)
        SIM_TIME    : time     := 90 ms
    );
end entity tb_top;

architecture sim of tb_top is
    signal clk    : std_logic := '0';
    signal sw     : std_logic_vector(0 downto 0) := "1";
    signal led    : std_logic_vector(7 downto 0);
    signal lcd_e, lcd_rs, lcd_rw, sf_ce0 : std_logic;
    signal sf_d   : std_logic_vector(11 downto 8);
    signal done   : boolean := false;

    type ddram_t is array (0 to 127) of character;
    signal ddram : ddram_t := (others => ' ');
    signal frame : ddram_t := (others => ' ');   -- ultimo quadro completo
begin

    clk <= not clk after 10 ns when not done else '0';

    dut : entity work.cpu_top
        generic map (STATE_TICKS => STATE_TICKS)
        port map (CLK_50MHZ => clk, SW => sw, LED => led,
                  LCD_E => lcd_e, LCD_RS => lcd_rs, LCD_RW => lcd_rw,
                  SF_D => sf_d, SF_CE0 => sf_ce0);

    -- modelo do LCD: captura nibbles na descida de E
    p_lcd : process
        variable pulses : natural := 0;
        variable hi     : std_logic_vector(3 downto 0);
        variable b      : std_logic_vector(7 downto 0);
        variable addr   : natural range 0 to 127 := 0;
    begin
        wait until falling_edge(lcd_e);
        pulses := pulses + 1;
        if pulses > 4 then                       -- 4 primeiros = init (3,3,3,2)
            if (pulses mod 2) = 1 then
                hi := sf_d;
            else
                b := hi & sf_d;
                if lcd_rs = '1' then
                    ddram(addr) <= character'val(to_integer(unsigned(b)));
                    addr := (addr + 1) mod 128;
                elsif b = x"01" then
                    ddram <= (others => ' '); addr := 0;
                elsif b(7) = '1' then
                    if b = x"80" then frame <= ddram; end if;   -- inicio de novo quadro
                    addr := to_integer(unsigned(b(6 downto 0)));
                end if;
            end if;
        end if;
    end process;

    p_main : process
        variable l1, l2 : string(1 to 16);
    begin
        sw <= "1";
        wait for 1 ms;
        sw <= "0";                               -- solta o reset
        while now < SIM_TIME loop
            wait for 5 ms;
            for i in 0 to 15 loop
                l1(i+1) := frame(i);
                l2(i+1) := frame(16#40# + i);
            end loop;
            report "t=" & time'image(now) & "  LCD [" & l1 & "] [" & l2 & "]  LEDs(7..0) = " &
                   std_logic'image(led(7)) & std_logic'image(led(6)) & std_logic'image(led(5)) &
                   std_logic'image(led(4)) & std_logic'image(led(3)) & std_logic'image(led(2)) &
                   std_logic'image(led(1)) & std_logic'image(led(0));
        end loop;
        assert sf_ce0 = '1' and lcd_rw = '0' report "SF_CE0/LCD_RW incorretos" severity error;
        done <= true;
        wait;
    end process;

end architecture sim;
