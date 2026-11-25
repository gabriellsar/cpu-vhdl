--------------------------------------------------------------------------------
-- cpu_top.vhd
-- Topo do projeto (Spartan-3E Starter Kit):
--
--   SW0  -> RESET (chave; '1' = CPU parada no estado inicial)
--   LD7  -> CLOCK da CPU
--   LD6  -> ZERO      LD5 -> NEGATIVE   LD4 -> OVERFLOW
--   LD3  -> EQUAL     LD2 -> GREATER    LD1 -> SMALLER    LD0 -> livre ('0')
--   LCD  -> linha 1: instrucao atual / linha 2: MEM[255]
--
--   +--------------+    CE    +-----------------------------+
--   | clock_enable |--------->|            cpu              |
--   +--------------+          |  UC (FSM) + regs + ALU      |
--                             +--+------+-------+-----------+
--                         ADDR/DIN/WE  DOUT   FLAGS / DISP_IR / DISP_OP
--                                |      |       |
--                             +--v------+--+    |     +----------+   +----------------+
--                             | RAM_8x256  |----+---->| lcd_text |-->| lcd_controller |--> LCD
--                             +------------+ POS_255  +----------+   +----------------+
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity cpu_top is
    generic (
        STATE_TICKS : positive := 25_000_000   -- 0,5 s por estado -> 2 s por instrucao
    );
    port (
        CLK_50MHZ : in  std_logic;
        SW        : in  std_logic_vector(0 downto 0);   -- SW0 = reset
        LED       : out std_logic_vector(7 downto 0);
        LCD_E     : out std_logic;
        LCD_RS    : out std_logic;
        LCD_RW    : out std_logic;
        SF_D      : out std_logic_vector(11 downto 8);
        SF_CE0    : out std_logic                       -- desabilita a StrataFlash
    );
end entity cpu_top;

architecture structural of cpu_top is

    signal rst_meta, rst : std_logic := '1';
    signal ce, clk_led   : std_logic;

    signal ram_addr, ram_din, ram_dout, mem255 : word_t;
    signal ram_we : std_logic;

    signal flags           : flags_t;
    signal disp_ir, disp_op : word_t;
    signal line1, line2    : line_t;

begin

    -- sincroniza a chave de reset com o clock
    process(CLK_50MHZ)
    begin
        if rising_edge(CLK_50MHZ) then
            rst_meta <= SW(0);
            rst      <= rst_meta;
        end if;
    end process;

    u_ce : entity work.clock_enable
        generic map (TICKS => STATE_TICKS)
        port map (
            CLK     => CLK_50MHZ,
            RESET   => rst,
            CE      => ce,
            CLK_LED => clk_led
        );

    u_cpu : entity work.cpu
        port map (
            CLK       => CLK_50MHZ,
            CE        => ce,
            RESET     => rst,
            RAM_ADDR  => ram_addr,
            RAM_DIN   => ram_din,
            RAM_WE    => ram_we,
            RAM_DOUT  => ram_dout,
            FLAGS_OUT => flags,
            DISP_IR   => disp_ir,
            DISP_OP   => disp_op,
            DBG_PC    => open,
            DBG_SP    => open,
            DBG_RA    => open,
            DBG_RB    => open,
            DBG_RC    => open,
            DBG_RD    => open,
            DBG_WRITE => open
        );

    u_ram : entity work.RAM_8x256
        port map (
            CLK     => CLK_50MHZ,
            DIN     => ram_din,
            ADDR    => ram_addr,
            WE      => ram_we,
            DOUT    => ram_dout,
            POS_255 => mem255
        );

    u_txt : entity work.lcd_text
        port map (
            IR     => disp_ir,
            OP     => disp_op,
            MEM255 => mem255,
            LINE1  => line1,
            LINE2  => line2
        );

    u_lcd : entity work.lcd_controller
        port map (
            CLK    => CLK_50MHZ,
            RESET  => '0',          -- o LCD nao depende do reset da CPU
            LINE1  => line1,
            LINE2  => line2,
            LCD_E  => LCD_E,
            LCD_RS => LCD_RS,
            LCD_RW => LCD_RW,
            LCD_D  => SF_D
        );

    SF_CE0 <= '1';

    LED(7)          <= clk_led;
    LED(6 downto 1) <= flags;      -- Z N OVF EQ GT SM
    LED(0)          <= '0';

end architecture structural;
