--------------------------------------------------------------------------------
-- lcd_controller.vhd
-- Controlador do LCD 16x2 (HD44780 / ST7066U) da Spartan-3E Starter Kit,
-- interface de 4 bits (SF_D<11:8>), somente escrita (LCD_RW = '0').
-- Roda no clock da FPGA (50 MHz). Temporizacoes conforme o UG230 (Xilinx):
--
--   Inicializacao: 15 ms, 0x3, 4.1 ms, 0x3, 100 us, 0x3, 40 us, 0x2, 40 us
--   Configuracao : 0x28 (4 bits, 2 linhas), 0x06 (entry mode),
--                  0x0C (display on, sem cursor), 0x01 (clear, 1.64 ms)
--   Laco         : 0x80 + 16 caracteres da linha 1,
--                  0xC0 + 16 caracteres da linha 2, repete para sempre
--
-- Cada byte = nibble alto + nibble baixo; pulso de E com 12 ciclos (240 ns),
-- 1 us entre nibbles e 40 us entre bytes.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity lcd_controller is
    port (
        CLK    : in  std_logic;                     -- 50 MHz
        RESET  : in  std_logic;
        LINE1  : in  line_t;
        LINE2  : in  line_t;
        LCD_E  : out std_logic;
        LCD_RS : out std_logic;
        LCD_RW : out std_logic;
        LCD_D  : out std_logic_vector(3 downto 0)   -- SF_D<11:8>
    );
end entity lcd_controller;

architecture rtl of lcd_controller is

    -- tempos em ciclos de 50 MHz
    constant T_POWERON : natural := 750_000;  -- 15 ms
    constant T_4100US  : natural := 205_000;  -- 4.1 ms
    constant T_100US   : natural := 5_000;
    constant T_40US    : natural := 2_000;
    constant T_CLEAR   : natural := 100_000;  -- 2 ms (> 1.64 ms)
    constant T_1US     : natural := 50;
    constant T_SETUP   : natural := 2;        -- 40 ns
    constant T_E       : natural := 12;       -- 240 ns

    type state_t is (
        ST_POWERON,                   -- espera inicial
        ST_INIT_SETUP, ST_INIT_E, ST_INIT_WAIT,
        ST_LOAD,                      -- escolhe o proximo byte
        ST_HI_SETUP, ST_HI_E, ST_GAP, -- nibble alto
        ST_LO_SETUP, ST_LO_E, ST_WAIT -- nibble baixo
    );
    signal state : state_t := ST_POWERON;

    signal cnt      : natural range 0 to T_POWERON := 0;
    signal init_idx : natural range 0 to 3 := 0;
    signal step     : natural range 0 to 37 := 0;
    signal byte_r   : std_logic_vector(7 downto 0) := (others => '0');
    signal rs_r     : std_logic := '0';
    signal delay_r  : natural range 0 to T_CLEAR := T_40US;

    signal e_r : std_logic := '0';
    signal d_r : std_logic_vector(3 downto 0) := (others => '0');

    type chars_t is array (0 to 15) of std_logic_vector(7 downto 0);
    signal c1, c2 : chars_t;     -- texto atual (entrada)
    signal s1, s2 : chars_t;     -- copia travada no inicio de cada refresh

    type nib_arr_t is array (0 to 3) of std_logic_vector(3 downto 0);
    constant INIT_NIB  : nib_arr_t := ("0011", "0011", "0011", "0010");
    type nat_arr_t is array (0 to 3) of natural;
    constant INIT_WAIT : nat_arr_t := (T_4100US, T_100US, T_40US, T_40US);

begin

    -- separa as linhas em 16 bytes (caractere 0 = MSBs)
    g_chars : for i in 0 to 15 generate
        c1(i) <= LINE1(127 - 8*i downto 120 - 8*i);
        c2(i) <= LINE2(127 - 8*i downto 120 - 8*i);
    end generate;

    process(CLK)
    begin
        if rising_edge(CLK) then
            if RESET = '1' then
                state    <= ST_POWERON;
                cnt      <= 0;
                init_idx <= 0;
                step     <= 0;
                e_r      <= '0';
                d_r      <= (others => '0');
                rs_r     <= '0';
            else
                case state is

                    -- 15 ms apos ligar ------------------------------------------
                    when ST_POWERON =>
                        if cnt = T_POWERON-1 then
                            cnt   <= 0;
                            state <= ST_INIT_SETUP;
                        else
                            cnt <= cnt + 1;
                        end if;

                    -- sequencia de inicializacao (nibbles 3,3,3,2) ---------------
                    when ST_INIT_SETUP =>
                        rs_r <= '0';
                        d_r  <= INIT_NIB(init_idx);
                        if cnt = T_SETUP-1 then
                            cnt <= 0; state <= ST_INIT_E;
                        else
                            cnt <= cnt + 1;
                        end if;

                    when ST_INIT_E =>
                        e_r <= '1';
                        if cnt = T_E-1 then
                            e_r <= '0'; cnt <= 0; state <= ST_INIT_WAIT;
                        else
                            cnt <= cnt + 1;
                        end if;

                    when ST_INIT_WAIT =>
                        if cnt = INIT_WAIT(init_idx)-1 then
                            cnt <= 0;
                            if init_idx = 3 then
                                step  <= 0;
                                state <= ST_LOAD;
                            else
                                init_idx <= init_idx + 1;
                                state    <= ST_INIT_SETUP;
                            end if;
                        else
                            cnt <= cnt + 1;
                        end if;

                    -- escolhe o proximo byte ------------------------------------
                    when ST_LOAD =>
                        delay_r <= T_40US;
                        case step is
                            when 0 => rs_r <= '0'; byte_r <= x"28";  -- function set
                            when 1 => rs_r <= '0'; byte_r <= x"06";  -- entry mode
                            when 2 => rs_r <= '0'; byte_r <= x"0C";  -- display on
                            when 3 => rs_r <= '0'; byte_r <= x"01";  -- clear
                                      delay_r <= T_CLEAR;
                            when 4 => rs_r <= '0'; byte_r <= x"80";  -- linha 1
                                      s1 <= c1;   -- trava o texto: evita mostrar
                                      s2 <= c2;   -- metade de uma linha antiga
                            when 21 => rs_r <= '0'; byte_r <= x"C0"; -- linha 2
                            when others =>
                                rs_r <= '1';
                                if step <= 20 then
                                    byte_r <= s1(step - 5);
                                else
                                    byte_r <= s2(step - 22);
                                end if;
                        end case;
                        cnt   <= 0;
                        state <= ST_HI_SETUP;

                    -- nibble alto -----------------------------------------------
                    when ST_HI_SETUP =>
                        d_r <= byte_r(7 downto 4);
                        if cnt = T_SETUP-1 then
                            cnt <= 0; state <= ST_HI_E;
                        else
                            cnt <= cnt + 1;
                        end if;

                    when ST_HI_E =>
                        e_r <= '1';
                        if cnt = T_E-1 then
                            e_r <= '0'; cnt <= 0; state <= ST_GAP;
                        else
                            cnt <= cnt + 1;
                        end if;

                    when ST_GAP =>
                        if cnt = T_1US-1 then
                            cnt <= 0; state <= ST_LO_SETUP;
                        else
                            cnt <= cnt + 1;
                        end if;

                    -- nibble baixo ----------------------------------------------
                    when ST_LO_SETUP =>
                        d_r <= byte_r(3 downto 0);
                        if cnt = T_SETUP-1 then
                            cnt <= 0; state <= ST_LO_E;
                        else
                            cnt <= cnt + 1;
                        end if;

                    when ST_LO_E =>
                        e_r <= '1';
                        if cnt = T_E-1 then
                            e_r <= '0'; cnt <= 0; state <= ST_WAIT;
                        else
                            cnt <= cnt + 1;
                        end if;

                    when ST_WAIT =>
                        if cnt = delay_r-1 then
                            cnt <= 0;
                            if step = 37 then
                                step <= 4;           -- volta para o inicio da linha 1
                            else
                                step <= step + 1;
                            end if;
                            state <= ST_LOAD;
                        else
                            cnt <= cnt + 1;
                        end if;

                end case;
            end if;
        end if;
    end process;

    LCD_E  <= e_r;
    LCD_RS <= rs_r;
    LCD_RW <= '0';
    LCD_D  <= d_r;

end architecture rtl;
