#!/usr/bin/env python3
"""
gerar_tabelas.py - gera as tabelas do relatorio a partir do simulador da ISA.

    cd relatorio && python3 gerar_tabelas.py

Cria:
    tabelas/passo_fibonacci.tex   tabela passo a passo (PC, LCD, flags, MEM[255])
    tabelas/resumo_testes.tex     numero de instrucoes e resultado de cada programa
"""
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, "..", "tools"))
from asm import assemble          # noqa: E402
from sim import run               # noqa: E402

PROG = os.path.join(AQUI, "..", "programs")
OUT = os.path.join(AQUI, "tabelas")
os.makedirs(OUT, exist_ok=True)


def tex(s):
    return (s.replace("\\", r"\textbackslash{}").replace("_", r"\_")
             .replace("#", r"\#").replace("&", r"\&").replace("%", r"\%")
             .replace("[", "{[}").replace("]", "{]}"))


def carregar(nome):
    with open(os.path.join(PROG, nome), encoding="utf-8") as f:
        mem, _, _ = assemble(f.read())
    return mem


def tabela_passo(nome, arquivo):
    rows = run(carregar(nome))
    linhas = [
        r"\begin{longtable}{rrlcccccc r rrrr}",
        r"\caption{Execução passo a passo de \texttt{" + tex(nome) + r"} (valores após o estado WRITE de cada instrução).}\label{tab:passo-fib}\\",
        r"\toprule",
        r"Passo & PC & LCD linha 1 & Z & N & OVF & EQ & GT & SM & MEM[255] & Ra & Rb & Rc & Rd \\",
        r"\midrule\endfirsthead",
        r"\toprule",
        r"Passo & PC & LCD linha 1 & Z & N & OVF & EQ & GT & SM & MEM[255] & Ra & Rb & Rc & Rd \\",
        r"\midrule\endhead",
        r"\bottomrule\endfoot",
    ]
    for r in rows:
        regs = " & ".join(str(v) for v in r["regs"])
        linhas.append(
            f"{r['step']} & {r['pc']} & \\texttt{{{tex(r['lcd'].strip())}}} & "
            f"{r['Z']} & {r['N']} & {r['OVF']} & {r['EQ']} & {r['GT']} & {r['SM']} & "
            f"{r['mem255']:03d} & {regs} \\\\")
    linhas.append(r"\end{longtable}")
    with open(os.path.join(OUT, arquivo), "w", encoding="utf-8") as f:
        f.write("\n".join(linhas) + "\n")
    return rows


def resumo():
    progs = [("fibonacci.asm", "Sequência de Fibonacci até estourar 8 bits", "233"),
             ("test_alu.asm", "ALU, flags e saltos condicionais", "100"),
             ("test_mem.asm", "memória, pilha, \\texttt{jmpr} e opcodes não usados", "100")]
    linhas = [r"\begin{tabularx}{\linewidth}{l X r r r}", r"\toprule",
              r"Programa & O que testa & Bytes & Instruções & MEM[255] final \\",
              r"\midrule"]
    for nome, desc, esperado in progs:
        mem = carregar(nome)
        tam = max(i for i, b in enumerate(mem) if b != 0) + 1
        rows = run(mem)
        final = rows[-1]["mem255"]
        assert str(final) == esperado, (nome, final)
        linhas.append(f"\\texttt{{{tex(nome)}}} & {desc} & {tam} & {len(rows)} & {final} \\\\")
    linhas += [r"\bottomrule", r"\end{tabularx}"]
    with open(os.path.join(OUT, "resumo_testes.tex"), "w", encoding="utf-8") as f:
        f.write("\n".join(linhas) + "\n")


if __name__ == "__main__":
    rows = tabela_passo("fibonacci.asm", "passo_fibonacci.tex")
    resumo()
    print(f"tabelas geradas em {OUT} ({len(rows)} passos no Fibonacci)")
