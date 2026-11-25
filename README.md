# CPU 8 bits em VHDL — Trabalho Final de Computação Digital

## Arquivos
| Arquivo | Conteúdo |
|---|---|
| `src/cpu_pkg.vhd` | tipos, comandos da ALU, decodificação das instruções, funções do LCD |
| `src/alu.vhd` | ALU assíncrona (conta em 9 bits, 6 flags) |
| `src/cpu.vhd` | UC (FSM fetch → decode → execute → write), registradores, ALU instanciada |
| `src/RAM.vhd` | RAM 256×8 síncrona (interface original); programa entre `PROGRAM BEGIN/END` |
| `src/clock_enable.vhd` | divisor por clock enable (0,5 s por estado = 2 s por instrução) + LED CLOCK |
| `src/lcd_text.vhd` | texto das linhas do LCD (instrução / `MEM[255] = ddd`) |
| `src/lcd_controller.vhd` | driver do LCD 16x2 em 4 bits (50 MHz) |
| `src/cpu_top.vhd` | topo: liga tudo, chave SW0 = reset, LEDs |
| `constraints/cpu_top.ucf` | pinos da Spartan-3E Starter Kit |
| `sim/tb_cpu.vhd` | testbench: imprime a tabela passo a passo (PC, LCD, flags, MEM[255]) |
| `sim/tb_top.vhd` | testbench do topo com modelo do LCD |
| `sim/run_tests.sh` | roda todos os programas no GHDL e compara com o modelo Python |
| `tools/asm.py` | montador: gera o bloco da RAM (ou já substitui no `RAM.vhd`) |
| `tools/sim.py` | simulador da ISA: gera a tabela da apresentação |
| `programs/*.asm` | `fibonacci`, `test_alu` e `test_mem` (autoteste: 100 = ok, 238 = falha) |

## ISE
1. Novo projeto (XC3S500E, FG320, -4), adicione todos os `src/*.vhd` e o `.ucf`; top = `cpu_top`.
2. Para simular no ISim, adicione `sim/tb_cpu.vhd` (ou `tb_top.vhd`) como Simulation.

## Trocar o programa (ex.: programa surpresa)
    python tools/asm.py programa.asm --ram src/RAM.vhd
ou cole o bloco do professor no lugar de `signal ram : RAM_t := (...);`.

## Tabela passo a passo
    python tools/sim.py programs/fibonacci.asm          # texto
    python tools/sim.py programs/fibonacci.asm --csv fib.csv

## LEDs
LD7 CLOCK · LD6 ZERO · LD5 NEGATIVE · LD4 OVERFLOW · LD3 EQUAL · LD2 GREATER · LD1 SMALLER · LD0 livre
