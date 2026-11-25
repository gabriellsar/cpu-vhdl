--------------------------------------------------------------------------------
-- lcd_text.vhd
-- Gera (combinacionalmente) as duas linhas de 16 caracteres do LCD:
--   Linha 1: instrucao atual em assembly, ex.: "LDI Ra, 0x64", "ADD Ra, Rb"
--   Linha 2: conteudo de MEM[255] em decimal, ex.: "MEM[255] = 028"
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity lcd_text is
    port (
        IR     : in  word_t;    -- instrucao
        OP     : in  word_t;    -- 2o byte (ldi / st / jmp)
        MEM255 : in  word_t;    -- MEM[255]
        LINE1  : out line_t;
        LINE2  : out line_t
    );
end entity lcd_text;

architecture rtl of lcd_text is
    signal rx, ry : std_logic_vector(15 downto 0);   -- "Ra".."Rd"
    signal hx     : std_logic_vector(31 downto 0);   -- "0x3F"
begin

    rx <= reg_name(IR(3 downto 2));
    ry <= reg_name(IR(1 downto 0));
    hx <= s2v("0x") & hex2(OP);

    p_line1 : process(IR, rx, ry, hx)
    begin
        case decode(IR) is
            when I_ADD  => LINE1 <= pad16(s2v("ADD ")  & rx & s2v(", ") & ry);
            when I_SUB  => LINE1 <= pad16(s2v("SUB ")  & rx & s2v(", ") & ry);
            when I_INC  => LINE1 <= pad16(s2v("INC ")  & rx);
            when I_DEC  => LINE1 <= pad16(s2v("DEC ")  & rx);
            when I_AND  => LINE1 <= pad16(s2v("AND ")  & rx & s2v(", ") & ry);
            when I_OR   => LINE1 <= pad16(s2v("OR ")   & rx & s2v(", ") & ry);
            when I_NOT  => LINE1 <= pad16(s2v("NOT ")  & rx);
            when I_XOR  => LINE1 <= pad16(s2v("XOR ")  & rx & s2v(", ") & ry);
            when I_ROL  => LINE1 <= pad16(s2v("ROL ")  & rx);
            when I_ROR  => LINE1 <= pad16(s2v("ROR ")  & rx);
            when I_LSL  => LINE1 <= pad16(s2v("LSL ")  & rx);
            when I_LSR  => LINE1 <= pad16(s2v("LSR ")  & rx);
            when I_PUSH => LINE1 <= pad16(s2v("PUSH ") & rx);
            when I_POP  => LINE1 <= pad16(s2v("POP ")  & rx);
            when I_ST   => LINE1 <= pad16(s2v("ST ")   & rx & s2v(", ") & hx);
            when I_LDI  => LINE1 <= pad16(s2v("LDI ")  & rx & s2v(", ") & hx);
            when I_LDR  => LINE1 <= pad16(s2v("LDR ")  & rx & s2v(", [") & ry & s2v("]"));
            when I_STR  => LINE1 <= pad16(s2v("STR ")  & rx & s2v(", [") & ry & s2v("]"));
            when I_MOV  => LINE1 <= pad16(s2v("MOV ")  & rx & s2v(", ") & ry);
            when I_JMP  => LINE1 <= pad16(s2v("JMP ")  & hx);
            when I_JMPR => LINE1 <= pad16(s2v("JMPR ") & rx);
            when I_BZ   => LINE1 <= pad16(s2v("BZ ")   & rx);
            when I_BNZ  => LINE1 <= pad16(s2v("BNZ ")  & rx);
            when I_BCS  => LINE1 <= pad16(s2v("BCS ")  & rx);
            when I_BCC  => LINE1 <= pad16(s2v("BCC ")  & rx);
            when I_BEQ  => LINE1 <= pad16(s2v("BEQ ")  & rx);
            when I_BNEQ => LINE1 <= pad16(s2v("BNEQ ") & rx);
            when I_BGT  => LINE1 <= pad16(s2v("BGT ")  & rx);
            when I_BLT  => LINE1 <= pad16(s2v("BLT ")  & rx);
            when I_BNEG => LINE1 <= pad16(s2v("BNEG ") & rx);
            when I_HALT => LINE1 <= pad16(s2v("HALT"));
            when others => LINE1 <= pad16(s2v("NOP"));
        end case;
    end process;

    LINE2 <= pad16(s2v("MEM[255] = ") & dec3(MEM255));

end architecture rtl;
