--------------------------------------------------------------------------------
-- cpu_pkg.vhd
-- Pacote comum da CPU de 8 bits: tipos, codificacao dos comandos da ALU,
-- decodificacao das instrucoes e funcoes auxiliares para montar o texto do LCD.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package cpu_pkg is

    subtype word_t    is std_logic_vector(7 downto 0);
    subtype alu_cmd_t is std_logic_vector(3 downto 0);
    subtype flags_t   is std_logic_vector(5 downto 0);
    subtype line_t    is std_logic_vector(127 downto 0);  -- 16 caracteres ASCII

    ----------------------------------------------------------------------------
    -- Comandos da ALU (codificacao interna UC <-> ALU)
    ----------------------------------------------------------------------------
    constant ALU_ADD  : alu_cmd_t := "0000";
    constant ALU_SUB  : alu_cmd_t := "0001";
    constant ALU_AND  : alu_cmd_t := "0010";
    constant ALU_OR   : alu_cmd_t := "0011";
    constant ALU_XOR  : alu_cmd_t := "0100";
    constant ALU_NOT  : alu_cmd_t := "0101";
    constant ALU_ROL  : alu_cmd_t := "0110";
    constant ALU_ROR  : alu_cmd_t := "0111";
    constant ALU_LSL  : alu_cmd_t := "1000";
    constant ALU_LSR  : alu_cmd_t := "1001";
    constant ALU_PASS : alu_cmd_t := "1111";  -- repassa ALU_A (nao usado p/ flags)

    ----------------------------------------------------------------------------
    -- Posicao de cada flag no vetor FLAGS (igual a ordem dos LEDs LD6..LD1)
    ----------------------------------------------------------------------------
    constant F_ZERO : natural := 5;
    constant F_NEG  : natural := 4;
    constant F_OVF  : natural := 3;
    constant F_EQ   : natural := 2;
    constant F_GT   : natural := 1;
    constant F_SM   : natural := 0;

    ----------------------------------------------------------------------------
    -- Instrucoes decodificadas
    ----------------------------------------------------------------------------
    type instr_t is (
        I_ADD, I_SUB, I_INC, I_DEC,
        I_AND, I_OR, I_NOT, I_XOR, I_ROL, I_ROR, I_LSL, I_LSR,
        I_PUSH, I_POP, I_ST, I_LDI, I_LDR, I_STR, I_MOV,
        I_JMP, I_JMPR, I_BZ, I_BNZ, I_BCS, I_BCC, I_BEQ, I_BNEQ,
        I_BGT, I_BLT, I_BNEG,
        I_NOP, I_HALT
    );

    -- Decodifica o byte de instrucao (IR). Codigos nao usados -> I_NOP.
    function decode(ir : word_t) return instr_t;

    -- Instrucao que usa a ALU (e portanto atualiza as flags)?
    function is_alu(i : instr_t) return boolean;

    ----------------------------------------------------------------------------
    -- Funcoes para o LCD
    ----------------------------------------------------------------------------
    function s2v(s : string) return std_logic_vector;           -- string -> ASCII
    function pad16(v : std_logic_vector) return line_t;         -- completa c/ espacos
    function reg_name(sel : std_logic_vector(1 downto 0)) return std_logic_vector;
    function hex_char(n : std_logic_vector(3 downto 0)) return std_logic_vector;
    function hex2(b : word_t) return std_logic_vector;          -- "3F"
    function to_bcd(b : word_t) return std_logic_vector;        -- 8 bits -> 3 digitos BCD
    function dec3(b : word_t) return std_logic_vector;          -- "028"

end package cpu_pkg;


package body cpu_pkg is

    function decode(ir : word_t) return instr_t is
        variable op  : std_logic_vector(3 downto 0);
        variable rx  : std_logic_vector(1 downto 0);
        variable fn  : std_logic_vector(1 downto 0);
        variable res : instr_t;
    begin
        op  := ir(7 downto 4);
        rx  := ir(3 downto 2);
        fn  := ir(1 downto 0);
        res := I_NOP;
        case op is
            when "0000" => res := I_ADD;
            when "0001" => res := I_SUB;
            when "0010" =>
                case fn is
                    when "00"   => res := I_INC;
                    when "01"   => res := I_DEC;
                    when others => res := I_NOP;   -- nao usado
                end case;
            when "0011" => res := I_AND;
            when "0100" => res := I_OR;
            when "0101" =>
                if fn = "00" then res := I_NOT; else res := I_NOP; end if;
            when "0110" => res := I_XOR;
            when "0111" =>
                case fn is
                    when "00"   => res := I_ROL;
                    when "01"   => res := I_ROR;
                    when "10"   => res := I_LSL;
                    when others => res := I_LSR;
                end case;
            when "1000" =>
                case fn is
                    when "00"   => res := I_PUSH;
                    when "01"   => res := I_POP;
                    when "10"   => res := I_ST;
                    when others => res := I_LDI;
                end case;
            when "1001" => res := I_LDR;
            when "1010" => res := I_STR;
            when "1011" => res := I_MOV;
            when "1100" =>
                case fn is
                    when "00" =>
                        if rx = "00" then res := I_JMP; else res := I_NOP; end if;
                    when "01"   => res := I_JMPR;
                    when "10"   => res := I_BZ;
                    when others => res := I_BNZ;
                end case;
            when "1101" =>
                case fn is
                    when "00"   => res := I_BCS;
                    when "01"   => res := I_BCC;
                    when "10"   => res := I_BEQ;
                    when others => res := I_BNEQ;
                end case;
            when "1110" =>
                case fn is
                    when "00"   => res := I_BGT;
                    when "01"   => res := I_BLT;
                    when "10"   => res := I_BNEG;
                    when others => res := I_NOP;   -- nao usado
                end case;
            when others =>  -- "1111"
                if ir(3 downto 0) = "1111" then res := I_HALT; else res := I_NOP; end if;
        end case;
        return res;
    end function;

    function is_alu(i : instr_t) return boolean is
    begin
        case i is
            when I_ADD | I_SUB | I_INC | I_DEC | I_AND | I_OR | I_NOT |
                 I_XOR | I_ROL | I_ROR | I_LSL | I_LSR => return true;
            when others => return false;
        end case;
    end function;

    -- Converte string (constante) em vetor ASCII; primeiro caractere nos MSBs.
    function s2v(s : string) return std_logic_vector is
        variable ret : std_logic_vector(s'length*8-1 downto 0);
    begin
        for i in 0 to s'length-1 loop
            ret(ret'high - 8*i downto ret'high - 8*i - 7) :=
                std_logic_vector(to_unsigned(character'pos(s(s'low + i)), 8));
        end loop;
        return ret;
    end function;

    -- Ajusta um texto de ate 16 caracteres para 16 caracteres (espacos a direita).
    function pad16(v : std_logic_vector) return line_t is
        variable vn  : std_logic_vector(v'length-1 downto 0);
        variable ret : line_t;
    begin
        vn := v;
        for i in 0 to 15 loop
            if 8*(i+1) <= v'length then
                ret(127 - 8*i downto 120 - 8*i) := vn(vn'high - 8*i downto vn'high - 8*i - 7);
            else
                ret(127 - 8*i downto 120 - 8*i) := x"20";  -- ' '
            end if;
        end loop;
        return ret;
    end function;

    function reg_name(sel : std_logic_vector(1 downto 0)) return std_logic_vector is
        variable ret : std_logic_vector(15 downto 0);
    begin
        case sel is
            when "00"   => ret := x"5261";  -- "Ra"
            when "01"   => ret := x"5262";  -- "Rb"
            when "10"   => ret := x"5263";  -- "Rc"
            when others => ret := x"5264";  -- "Rd"
        end case;
        return ret;
    end function;

    function hex_char(n : std_logic_vector(3 downto 0)) return std_logic_vector is
        variable ret : std_logic_vector(7 downto 0);
    begin
        if unsigned(n) < 10 then
            ret := std_logic_vector(to_unsigned(48, 8) + unsigned(n));        -- '0'..'9'
        else
            ret := std_logic_vector(to_unsigned(55, 8) + unsigned(n));        -- 'A'..'F'
        end if;
        return ret;
    end function;

    function hex2(b : word_t) return std_logic_vector is
    begin
        return hex_char(b(7 downto 4)) & hex_char(b(3 downto 0));
    end function;

    -- Binario -> BCD (algoritmo "double dabble"): 8 bits -> 3 digitos.
    function to_bcd(b : word_t) return std_logic_vector is
        variable bin : unsigned(7 downto 0);
        variable bcd : unsigned(11 downto 0);
    begin
        bin := unsigned(b);
        bcd := (others => '0');
        for i in 0 to 7 loop
            if bcd(3 downto 0)  > 4 then bcd(3 downto 0)  := bcd(3 downto 0)  + 3; end if;
            if bcd(7 downto 4)  > 4 then bcd(7 downto 4)  := bcd(7 downto 4)  + 3; end if;
            if bcd(11 downto 8) > 4 then bcd(11 downto 8) := bcd(11 downto 8) + 3; end if;
            bcd := bcd(10 downto 0) & bin(7);
            bin := bin(6 downto 0) & '0';
        end loop;
        return std_logic_vector(bcd);
    end function;

    function dec3(b : word_t) return std_logic_vector is
        variable d : std_logic_vector(11 downto 0);
    begin
        d := to_bcd(b);
        return "0011" & d(11 downto 8) & "0011" & d(7 downto 4) & "0011" & d(3 downto 0);
    end function;

end package body cpu_pkg;
