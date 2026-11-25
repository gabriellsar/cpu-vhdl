--------------------------------------------------------------------------------
-- tb_cpu.vhd
-- Testbench da CPU (cpu + RAM + clock_enable + lcd_text).
--
-- A cada instrucao concluida (fim do estado WRITE) imprime / grava uma linha:
--   passo  PC  |LCD linha 1|  Z N OVF EQ GT SM  MEM[255]  Ra Rb Rc Rd SP  PC'
-- que e exatamente a tabela pedida na apresentacao. O mesmo formato e gerado
-- por tools/sim.py, o que permite comparar a CPU em VHDL com o modelo da ISA.
--
-- A simulacao para no primeiro HALT (ou apos MAX_STEPS instrucoes).
-- Tambem verifica o estado de reset (PC = 0, SP = 254, flags = 0).
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.cpu_pkg.all;

entity tb_cpu is
    generic (
        STATE_TICKS : positive := 2;            -- 2 ciclos de 50 MHz por estado
        MAX_STEPS   : positive := 3000;
        TRACE_FILE  : string   := "trace_vhdl.txt"
    );
end entity tb_cpu;

architecture sim of tb_cpu is

    constant T_CLK : time := 20 ns;

    signal clk     : std_logic := '0';
    signal reset   : std_logic := '1';
    signal running : boolean   := true;

    signal ce : std_logic;
    signal ram_addr, ram_din, ram_dout, mem255 : word_t;
    signal ram_we : std_logic;
    signal flags  : flags_t;
    signal disp_ir, disp_op : word_t;
    signal line1, line2 : line_t;
    signal pc, sp, ra, rb, rc, rd : word_t;
    signal in_write : std_logic;

    -- auxiliares de formatacao ------------------------------------------------
    function hex2s(v : std_logic_vector(7 downto 0)) return string is
        constant H : string(1 to 16) := "0123456789ABCDEF";
        variable s : string(1 to 2);
    begin
        s(1) := H(to_integer(unsigned(v(7 downto 4))) + 1);
        s(2) := H(to_integer(unsigned(v(3 downto 0))) + 1);
        return s;
    end function;

    function dec3s(v : std_logic_vector(7 downto 0)) return string is
        variable n : natural := to_integer(unsigned(v));
        variable s : string(1 to 3);
    begin
        s(1) := character'val(48 + n / 100);
        s(2) := character'val(48 + (n / 10) mod 10);
        s(3) := character'val(48 + n mod 10);
        return s;
    end function;

    function line2s(l : line_t) return string is
        variable s : string(1 to 16);
    begin
        for i in 0 to 15 loop
            s(i+1) := character'val(to_integer(unsigned(l(127 - 8*i downto 120 - 8*i))));
        end loop;
        return s;
    end function;

    function bit2s(b : std_logic) return string is
    begin
        if b = '1' then return "1"; else return "0"; end if;
    end function;

begin

    -- clock 50 MHz -----------------------------------------------------------
    clk <= not clk after T_CLK/2 when running else '0';

    -- DUT --------------------------------------------------------------------
    u_ce : entity work.clock_enable
        generic map (TICKS => STATE_TICKS)
        port map (CLK => clk, RESET => reset, CE => ce, CLK_LED => open);

    u_cpu : entity work.cpu
        port map (
            CLK => clk, CE => ce, RESET => reset,
            RAM_ADDR => ram_addr, RAM_DIN => ram_din, RAM_WE => ram_we, RAM_DOUT => ram_dout,
            FLAGS_OUT => flags, DISP_IR => disp_ir, DISP_OP => disp_op,
            DBG_PC => pc, DBG_SP => sp, DBG_RA => ra, DBG_RB => rb, DBG_RC => rc, DBG_RD => rd,
            DBG_WRITE => in_write
        );

    u_ram : entity work.RAM_8x256
        port map (CLK => clk, DIN => ram_din, ADDR => ram_addr, WE => ram_we,
                  DOUT => ram_dout, POS_255 => mem255);

    u_txt : entity work.lcd_text
        port map (IR => disp_ir, OP => disp_op, MEM255 => mem255, LINE1 => line1, LINE2 => line2);

    -- estimulo: reset por alguns ciclos ---------------------------------------
    p_stim : process
    begin
        reset <= '1';
        wait for 10 * T_CLK;
        wait until falling_edge(clk);
        assert unsigned(pc) = 0   report "reset: PC /= 0"   severity error;
        assert unsigned(sp) = 254 report "reset: SP /= 254" severity error;
        assert flags = "000000"   report "reset: flags /= 0" severity error;
        reset <= '0';
        wait;
    end process;

    -- monitor: uma linha por instrucao ----------------------------------------
    p_mon : process
        file     f      : text open write_mode is TRACE_FILE;
        variable l      : line;
        variable step   : natural := 0;
        variable pc_old : word_t;
        variable txt    : string(1 to 16);
    begin
        wait until rising_edge(clk);
        if reset = '0' and ce = '1' and in_write = '1' then
            pc_old := pc;
            txt    := line2s(line1);
            wait for 1 ns;                   -- valores apos a borda do WRITE
            step := step + 1;
            write(l, integer'image(step) & " " & hex2s(pc_old) & " |" & txt & "| " &
                     bit2s(flags(F_ZERO)) & bit2s(flags(F_NEG)) & bit2s(flags(F_OVF)) &
                     bit2s(flags(F_EQ)) & bit2s(flags(F_GT)) & bit2s(flags(F_SM)) & " " &
                     dec3s(mem255) & " " &
                     hex2s(ra) & " " & hex2s(rb) & " " & hex2s(rc) & " " & hex2s(rd) & " " &
                     hex2s(sp) & " " & hex2s(pc));
            writeline(f, l);
            if txt(1 to 4) = "HALT" or step = MAX_STEPS then
                report "fim: " & integer'image(step) & " instrucoes; LCD = [" & txt &
                       "] [" & line2s(line2) & "]";
                running <= false;
                wait;
            end if;
        end if;
    end process;

end architecture sim;
