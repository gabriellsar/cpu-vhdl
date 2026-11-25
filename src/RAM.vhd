--------------------------------------------------------------------------------
-- RAM.vhd
-- RAM estatica sincrona 256 x 8 (inferida como block RAM), interface fornecida
-- pelo professor (CLK, DIN, ADDR, WE, DOUT, POS_255).
--
-- Escrita e registro do endereco de leitura na borda de DESCIDA do clock;
-- DOUT so fica valido depois dessa borda.
--
-- O programa e o valor inicial do array "ram". Para trocar de programa,
-- substitua o bloco entre PROGRAM BEGIN / PROGRAM END (ou rode
--   python tools/asm.py programa.asm --ram src/RAM.vhd)
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity RAM_8x256 is
    port(
        CLK     : in std_logic;
        DIN     : in std_logic_vector(7 downto 0);
        ADDR    : in std_logic_vector(7 downto 0);
        WE      : in std_logic;
        DOUT    : out std_logic_vector(7 downto 0);
        POS_255 : out std_logic_vector(7 downto 0)
    );
end RAM_8x256;

architecture rtl of RAM_8x256 is

    type RAM_t is array(0 to 255) of std_logic_vector(7 downto 0);
    signal read_address : std_logic_vector(7 downto 0) := (others => '0');

        -- PROGRAM BEGIN (gerado por tools/asm.py)
        -- fibonacci.asm
        signal ram : RAM_t := (
              0 => "10000011", -- ldi Ra, 0
              1 => "00000000", -- 0
              2 => "10000111", -- ldi Rb, 1
              3 => "00000001", -- 1
              4 => "10000010", -- st Ra, 0xFF
              5 => "11111111", -- 0xFF
              6 => "10000110", -- st Rb, 0xFF
              7 => "11111111", -- 0xFF
              8 => "10111001", -- mov Rc, Rb
              9 => "00000100", -- add Rb, Ra
             10 => "10110010", -- mov Ra, Rc
             11 => "10001111", -- ldi Rd, fim
             12 => "00010000", -- fim
             13 => "11011100", -- bcs Rd
             14 => "11000000", -- jmp loop
             15 => "00000110", -- loop
             16 => "11111111", -- halt
            others => (others => '0')
        );
        -- PROGRAM END

begin

    process(CLK) is
    begin
        if falling_edge(CLK) then
            if WE = '1' then
                ram(to_integer(unsigned(ADDR))) <= DIN;
            end if;
            read_address <= ADDR;
        end if;
    end process;

    DOUT    <= ram(to_integer(unsigned(read_address)));
    POS_255 <= ram(255);

end architecture;
