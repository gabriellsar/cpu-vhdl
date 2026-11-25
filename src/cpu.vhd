--------------------------------------------------------------------------------
-- cpu.vhd
-- CPU de 8 bits: Unidade de Controle (FSM), registradores e ALU instanciada.
--
-- Registradores: regA..regD (REG(0..3)), IR, PC, SP, MBR, MAR.
-- A RAM e enderecada sempre por MAR e recebe o dado de escrita de MBR.
--
-- Ciclo de cada instrucao (4 estados, sempre os mesmos -> tempo constante):
--
--   FETCH   : DOUT = MEM[PC]   (MAR = PC desde o WRITE anterior)
--             IR  <- DOUT ; MAR <- PC+1 (pre-busca do 2o byte)
--   DECODE  : DOUT = MEM[PC+1]
--             decodifica IR; ALU_A/ALU_B/CMD; MBR <- byte seguinte (ldi/jmp);
--             prepara MAR/MBR/WE para acesso a memoria (st, str, push, ldr, pop)
--   EXECUTE : ALU ja respondeu (assincrona) / RAM ja respondeu (sincrona)
--             MBR <- resultado da ALU ou dado lido; FLAGS <- flags da ALU
--             (escritas na RAM acontecem durante este estado; WE <- 0 no fim)
--   WRITE   : Rx <- MBR ; atualiza SP ; PC <- proximo PC ; MAR <- proximo PC
--
-- RAM sincrona: ela registra o endereco na borda de DESCIDA do clock; a UC
-- muda MAR na borda de subida, entao o dado e lido sempre no estado seguinte
-- ao que colocou o endereco em MAR.
--
-- CE (clock enable) reduz a velocidade da CPU sem criar outro clock: a FSM so
-- avanca quando CE = '1'. A RAM e o LCD continuam no clock de 50 MHz.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity cpu is
    port (
        CLK        : in  std_logic;     -- 50 MHz
        CE         : in  std_logic;     -- clock enable da CPU (1 pulso por estado)
        RESET      : in  std_logic;     -- sincrono, ativo em '1'
        -- interface com a RAM
        RAM_ADDR   : out word_t;
        RAM_DIN    : out word_t;
        RAM_WE     : out std_logic;
        RAM_DOUT   : in  word_t;
        -- interface com usuario
        FLAGS_OUT  : out flags_t;       -- Z N OVF EQ GT SM (FFs da UC)
        DISP_IR    : out word_t;        -- instrucao exibida no LCD
        DISP_OP    : out word_t;        -- 2o byte (ldi/st/jmp) exibido no LCD
        -- depuracao / testbench
        DBG_PC     : out word_t;
        DBG_SP     : out word_t;
        DBG_RA     : out word_t;
        DBG_RB     : out word_t;
        DBG_RC     : out word_t;
        DBG_RD     : out word_t;
        DBG_WRITE  : out std_logic      -- '1' quando a FSM esta no estado WRITE
    );
end entity cpu;

architecture rtl of cpu is

    type state_t    is (S_FETCH, S_DECODE, S_EXECUTE, S_WRITE);
    type reg_file_t is array (0 to 3) of word_t;

    -- estado da UC
    signal state : state_t := S_FETCH;

    -- registradores
    signal REG   : reg_file_t := (others => (others => '0'));
    signal IR    : word_t := x"F0";                 -- NOP
    signal PC    : unsigned(7 downto 0) := (others => '0');
    signal SP    : unsigned(7 downto 0) := to_unsigned(254, 8);
    signal MAR   : word_t := (others => '0');
    signal MBR   : word_t := (others => '0');
    signal WE_R  : std_logic := '0';

    -- flags (flip-flops da UC)
    signal FLAGS : flags_t := (others => '0');

    -- registradores de exibicao (atualizados juntos no DECODE)
    signal disp_ir_r : word_t := x"F0";
    signal disp_op_r : word_t := (others => '0');

    -- interface com a ALU
    signal alu_a, alu_b : word_t    := (others => '0');
    signal alu_cmd      : alu_cmd_t := ALU_PASS;
    signal alu_r        : word_t;
    signal alu_flags    : flags_t;

    -- campos decodificados do IR
    signal instr  : instr_t;
    signal rx, ry : integer range 0 to 3;

begin

    ----------------------------------------------------------------------------
    -- ALU (assincrona)
    ----------------------------------------------------------------------------
    u_alu : entity work.alu
        port map (
            ALU_A => alu_a,
            ALU_B => alu_b,
            CMD   => alu_cmd,
            ALU_R => alu_r,
            FLAGS => alu_flags
        );

    ----------------------------------------------------------------------------
    -- Decodificacao combinacional do IR
    ----------------------------------------------------------------------------
    instr <= decode(IR);
    rx    <= to_integer(unsigned(IR(3 downto 2)));
    ry    <= to_integer(unsigned(IR(1 downto 0)));

    ----------------------------------------------------------------------------
    -- Maquina de estados da Unidade de Controle
    ----------------------------------------------------------------------------
    p_uc : process(CLK)
        variable pc_next : unsigned(7 downto 0);
        variable take    : boolean;
    begin
        if rising_edge(CLK) then
            if RESET = '1' then
                state     <= S_FETCH;
                REG       <= (others => (others => '0'));
                IR        <= x"F0";
                PC        <= (others => '0');
                SP        <= to_unsigned(254, 8);   -- SP inicializado em 254
                MAR       <= (others => '0');       -- MAR = PC = 0
                MBR       <= (others => '0');
                WE_R      <= '0';
                FLAGS     <= (others => '0');
                alu_a     <= (others => '0');
                alu_b     <= (others => '0');
                alu_cmd   <= ALU_PASS;
                disp_ir_r <= x"F0";
                disp_op_r <= (others => '0');

            elsif CE = '1' then
                case state is

                    ------------------------------------------------------------
                    when S_FETCH =>
                        -- MAR = PC, portanto RAM_DOUT = MEM[PC]
                        IR    <= RAM_DOUT;
                        MAR   <= std_logic_vector(PC + 1);   -- busca do 2o byte
                        state <= S_DECODE;

                    ------------------------------------------------------------
                    when S_DECODE =>
                        -- RAM_DOUT = MEM[PC+1]
                        disp_ir_r <= IR;
                        disp_op_r <= RAM_DOUT;

                        -- por padrao a ALU recebe zeros (so e usada nas instr. de ALU)
                        alu_a   <= (others => '0');
                        alu_b   <= (others => '0');
                        alu_cmd <= ALU_PASS;

                        case instr is
                            -- aritmeticas / logicas ---------------------------
                            when I_ADD => alu_a <= REG(rx); alu_b <= REG(ry); alu_cmd <= ALU_ADD;
                            when I_SUB => alu_a <= REG(rx); alu_b <= REG(ry); alu_cmd <= ALU_SUB;
                            when I_INC => alu_a <= REG(rx); alu_b <= x"01";   alu_cmd <= ALU_ADD;
                            when I_DEC => alu_a <= REG(rx); alu_b <= x"01";   alu_cmd <= ALU_SUB;
                            when I_AND => alu_a <= REG(rx); alu_b <= REG(ry); alu_cmd <= ALU_AND;
                            when I_OR  => alu_a <= REG(rx); alu_b <= REG(ry); alu_cmd <= ALU_OR;
                            when I_XOR => alu_a <= REG(rx); alu_b <= REG(ry); alu_cmd <= ALU_XOR;
                            when I_NOT => alu_a <= REG(rx); alu_b <= x"00";   alu_cmd <= ALU_NOT;
                            when I_ROL => alu_a <= REG(rx); alu_b <= x"00";   alu_cmd <= ALU_ROL;
                            when I_ROR => alu_a <= REG(rx); alu_b <= x"00";   alu_cmd <= ALU_ROR;
                            when I_LSL => alu_a <= REG(rx); alu_b <= x"00";   alu_cmd <= ALU_LSL;
                            when I_LSR => alu_a <= REG(rx); alu_b <= x"00";   alu_cmd <= ALU_LSR;

                            -- memoria -----------------------------------------
                            when I_LDI | I_JMP =>
                                MBR <= RAM_DOUT;                 -- imediato / destino
                            when I_ST =>
                                MAR  <= RAM_DOUT;                -- endereco = MEM[PC+1]
                                MBR  <= REG(rx);
                                WE_R <= '1';
                            when I_STR =>
                                MAR  <= REG(ry);
                                MBR  <= REG(rx);
                                WE_R <= '1';
                            when I_PUSH =>
                                MAR  <= std_logic_vector(SP);
                                MBR  <= REG(rx);
                                WE_R <= '1';
                            when I_POP =>
                                MAR  <= std_logic_vector(SP + 1);
                            when I_LDR =>
                                MAR  <= REG(ry);

                            when others => null;
                        end case;
                        state <= S_EXECUTE;

                    ------------------------------------------------------------
                    when S_EXECUTE =>
                        WE_R <= '0';                             -- escrita concluida
                        if is_alu(instr) then
                            MBR   <= alu_r;                      -- resultado da ALU
                            FLAGS <= alu_flags;                  -- salva flags nos FFs
                        end if;
                        case instr is
                            when I_LDR | I_POP => MBR <= RAM_DOUT;  -- dado lido
                            when I_MOV         => MBR <= REG(ry);
                            when others        => null;
                        end case;
                        state <= S_WRITE;

                    ------------------------------------------------------------
                    when S_WRITE =>
                        -- escrita no registrador destino
                        if is_alu(instr) then
                            REG(rx) <= MBR;
                        end if;
                        case instr is
                            when I_LDI | I_LDR | I_POP | I_MOV => REG(rx) <= MBR;
                            when others => null;
                        end case;

                        -- stack pointer
                        if instr = I_PUSH then SP <= SP - 1; end if;
                        if instr = I_POP  then SP <= SP + 1; end if;

                        -- condicao dos saltos (flags salvas pela ultima op. de ALU)
                        case instr is
                            when I_BZ   => take := FLAGS(F_ZERO) = '1';
                            when I_BNZ  => take := FLAGS(F_ZERO) = '0';
                            when I_BCS  => take := FLAGS(F_OVF)  = '1';
                            when I_BCC  => take := FLAGS(F_OVF)  = '0';
                            when I_BEQ  => take := FLAGS(F_EQ)   = '1';
                            when I_BNEQ => take := FLAGS(F_EQ)   = '0';
                            when I_BGT  => take := FLAGS(F_GT)   = '1';
                            when I_BLT  => take := FLAGS(F_SM)   = '1';
                            when I_BNEG => take := FLAGS(F_NEG)  = '1';
                            when I_JMPR => take := true;
                            when others => take := false;
                        end case;

                        -- proximo PC
                        case instr is
                            when I_LDI | I_ST => pc_next := PC + 2;
                            when I_JMP        => pc_next := unsigned(MBR);
                            when I_HALT       => pc_next := PC;
                            when others       =>
                                if take then
                                    pc_next := unsigned(REG(rx));
                                else
                                    pc_next := PC + 1;
                                end if;
                        end case;
                        PC    <= pc_next;
                        MAR   <= std_logic_vector(pc_next);   -- prepara o FETCH
                        state <= S_FETCH;

                end case;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- Saidas
    ----------------------------------------------------------------------------
    RAM_ADDR  <= MAR;
    RAM_DIN   <= MBR;
    RAM_WE    <= WE_R;

    FLAGS_OUT <= FLAGS;
    DISP_IR   <= disp_ir_r;
    DISP_OP   <= disp_op_r;

    DBG_PC    <= std_logic_vector(PC);
    DBG_SP    <= std_logic_vector(SP);
    DBG_RA    <= REG(0);
    DBG_RB    <= REG(1);
    DBG_RC    <= REG(2);
    DBG_RD    <= REG(3);
    DBG_WRITE <= '1' when state = S_WRITE else '0';

end architecture rtl;
