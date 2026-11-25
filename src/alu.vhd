--------------------------------------------------------------------------------
-- alu.vhd
-- ALU assincrona (puramente combinacional) de 8 bits.
--
-- A conta e feita em 9 bits com extensao de zero (unsigned): o bit 8 do
-- resultado e a flag OVERFLOW (carry na soma, borrow na subtracao, bit que sai
-- nos deslocamentos/rotacoes e 0 nas operacoes logicas).
--
-- FLAGS(5..0) = ZERO, NEGATIVE, OVERFLOW, EQUAL, GREATER, SMALLER
-- A ALU nao guarda nada: a UC salva resultado e flags no fim do EXECUTE.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity alu is
    port (
        ALU_A : in  word_t;
        ALU_B : in  word_t;
        CMD   : in  alu_cmd_t;
        ALU_R : out word_t;
        FLAGS : out flags_t
    );
end entity alu;

architecture rtl of alu is
    signal a9, b9, r9 : unsigned(8 downto 0);
begin

    a9 <= '0' & unsigned(ALU_A);   -- estende com zero: 0..255
    b9 <= '0' & unsigned(ALU_B);

    p_alu : process(CMD, a9, b9, ALU_A, ALU_B)
    begin
        case CMD is
            when ALU_ADD => r9 <= a9 + b9;                                   -- add, inc
            when ALU_SUB => r9 <= a9 - b9;                                   -- sub, dec
            when ALU_AND => r9 <= '0' & (unsigned(ALU_A) and unsigned(ALU_B));
            when ALU_OR  => r9 <= '0' & (unsigned(ALU_A) or  unsigned(ALU_B));
            when ALU_XOR => r9 <= '0' & (unsigned(ALU_A) xor unsigned(ALU_B));
            when ALU_NOT => r9 <= '0' & (not unsigned(ALU_A));
            -- deslocamentos: bit 8 = bit que "saiu"
            when ALU_ROL => r9 <= unsigned(ALU_A(7) & ALU_A(6 downto 0) & ALU_A(7));
            when ALU_ROR => r9 <= unsigned(ALU_A(0) & ALU_A(0) & ALU_A(7 downto 1));
            when ALU_LSL => r9 <= unsigned(ALU_A(7) & ALU_A(6 downto 0) & '0');
            when ALU_LSR => r9 <= unsigned(ALU_A(0) & '0' & ALU_A(7 downto 1));
            when others  => r9 <= a9;                                        -- PASS
        end case;
    end process;

    ALU_R <= std_logic_vector(r9(7 downto 0));

    FLAGS(F_ZERO) <= '1' when r9(7 downto 0) = 0 else '0';
    FLAGS(F_NEG)  <= r9(7);
    FLAGS(F_OVF)  <= r9(8);
    FLAGS(F_EQ)   <= '1' when unsigned(ALU_A) = unsigned(ALU_B) else '0';
    FLAGS(F_GT)   <= '1' when unsigned(ALU_A) > unsigned(ALU_B) else '0';
    FLAGS(F_SM)   <= '1' when unsigned(ALU_A) < unsigned(ALU_B) else '0';

end architecture rtl;
