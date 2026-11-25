#!/usr/bin/env python3
"""
asm.py - Montador da CPU de 8 bits (Computacao Digital / Trabalho Final).

Uso:
    python asm.py programa.asm                 # imprime o bloco da RAM
    python asm.py programa.asm -o bloco.vhd    # grava o bloco em arquivo
    python asm.py programa.asm --ram ../src/RAM.vhd   # substitui o bloco no RAM.vhd

Sintaxe:
    ; comentario  (tambem '#' e '--')
    rotulo:                     define um rotulo (endereco atual)
    .org 0x40                   muda o endereco de montagem
    .db 1, 0x2F, rotulo         bytes de dados
    .equ NOME, 10               constante
    add Ra, Rb | inc Rc | ldi Ra, 0x10 | st Ra, 0xFF | ldr Ra, [Rb] | jmp loop ...

Numeros: 10, 0x0A, 0b1010, 'A'. Operandos podem ser rotulo+N / rotulo-N.
"""
import re
import sys
import argparse

REGS = {"ra": 0, "rb": 1, "rc": 2, "rd": 3, "a": 0, "b": 1, "c": 2, "d": 3}

# mnemonico -> (opcode 4 bits, formato, funcao[1:0])
#   rr : Rx, Ry          r  : Rx (func fixa)      ri : Rx, imm (2 bytes)
#   rm : Rx, [Ry]        i  : imm (2 bytes)       n  : sem operando (byte fixo)
INSTR = {
    "add":  (0b0000, "rr", None), "sub":  (0b0001, "rr", None),
    "inc":  (0b0010, "r", 0b00),  "dec":  (0b0010, "r", 0b01),
    "and":  (0b0011, "rr", None), "or":   (0b0100, "rr", None),
    "not":  (0b0101, "r", 0b00),  "xor":  (0b0110, "rr", None),
    "rol":  (0b0111, "r", 0b00),  "ror":  (0b0111, "r", 0b01),
    "lsl":  (0b0111, "r", 0b10),  "lsr":  (0b0111, "r", 0b11),
    "push": (0b1000, "r", 0b00),  "pop":  (0b1000, "r", 0b01),
    "st":   (0b1000, "ri", 0b10), "ldi":  (0b1000, "ri", 0b11),
    "ldr":  (0b1001, "rm", None), "str":  (0b1010, "rm", None),
    "mov":  (0b1011, "rr", None),
    "jmp":  (0b1100, "i", 0b00),  "jmpr": (0b1100, "r", 0b01),
    "bz":   (0b1100, "r", 0b10),  "bnz":  (0b1100, "r", 0b11),
    "bcs":  (0b1101, "r", 0b00),  "bcc":  (0b1101, "r", 0b01),
    "beq":  (0b1101, "r", 0b10),  "bneq": (0b1101, "r", 0b11),
    "bgt":  (0b1110, "r", 0b00),  "blt":  (0b1110, "r", 0b01),
    "bneg": (0b1110, "r", 0b10),
    "nop":  (0xF0, "n", None),    "halt": (0xFF, "n", None),
}


class AsmError(Exception):
    pass


def strip_comment(line):
    for mark in (";", "#", "--"):
        i = line.find(mark)
        if i >= 0 and not (mark == "#" and "'#'" in line):
            line = line[:i]
    return line.strip()


def parse_number(tok, symbols, lineno, allow_undefined=False):
    tok = tok.strip()
    m = re.fullmatch(r"([A-Za-z_]\w*)\s*([+-])\s*(.+)", tok)
    if m and m.group(1).lower() not in REGS:
        base = parse_number(m.group(1), symbols, lineno, allow_undefined)
        off = parse_number(m.group(3), symbols, lineno, allow_undefined)
        return (base + off) if m.group(2) == "+" else (base - off)
    if re.fullmatch(r"'.'", tok):
        return ord(tok[1])
    try:
        return int(tok, 0)
    except ValueError:
        pass
    if re.fullmatch(r"[A-Za-z_]\w*", tok):
        if tok in symbols:
            return symbols[tok]
        if allow_undefined:
            return 0
        raise AsmError(f"linha {lineno}: simbolo indefinido '{tok}'")
    raise AsmError(f"linha {lineno}: numero invalido '{tok}'")


def parse_reg(tok, lineno):
    t = tok.strip().lower()
    if t not in REGS:
        raise AsmError(f"linha {lineno}: registrador invalido '{tok}'")
    return REGS[t]


def split_ops(s):
    return [o.strip() for o in s.split(",")] if s.strip() else []


def assemble(source):
    """Retorna (mem[256], comentarios{addr: texto})."""
    lines = source.splitlines()
    symbols = {}

    def run(final):
        mem = [None] * 256
        notes = {}
        addr = 0
        for lineno, raw in enumerate(lines, 1):
            line = strip_comment(raw)
            while True:  # rotulos (podem ser varios na mesma linha)
                m = re.match(r"^([A-Za-z_]\w*):\s*(.*)$", line)
                if not m:
                    break
                if not final:
                    if m.group(1) in symbols:
                        raise AsmError(f"linha {lineno}: rotulo repetido '{m.group(1)}'")
                    symbols[m.group(1)] = addr
                line = m.group(2)
            if not line:
                continue
            parts = line.split(None, 1)
            mnem = parts[0].lower()
            rest = parts[1] if len(parts) > 1 else ""
            ops = split_ops(rest)

            def num(t):
                v = parse_number(t, symbols, lineno, allow_undefined=not final)
                if final and not (-128 <= v <= 255):
                    raise AsmError(f"linha {lineno}: valor fora de 8 bits: {v}")
                return v & 0xFF

            def emit(byte, note):
                nonlocal addr
                if addr > 255:
                    raise AsmError(f"linha {lineno}: programa excede 256 bytes")
                if final and mem[addr] is not None:
                    raise AsmError(f"linha {lineno}: sobreposicao no endereco {addr}")
                mem[addr] = byte
                notes[addr] = note
                addr += 1

            if mnem == ".org":
                addr = num(ops[0])
                continue
            if mnem == ".equ":
                if not final:
                    symbols[ops[0]] = parse_number(ops[1], symbols, lineno)
                continue
            if mnem == ".db":
                for o in ops:
                    emit(num(o), f"dado {o}")
                continue
            if mnem not in INSTR:
                raise AsmError(f"linha {lineno}: instrucao desconhecida '{mnem}'")

            opc, fmt, fn = INSTR[mnem]
            text = " ".join(line.split())
            if fmt == "n":
                if ops:
                    raise AsmError(f"linha {lineno}: '{mnem}' nao tem operandos")
                emit(opc, text)
            elif fmt == "rr":
                if len(ops) != 2:
                    raise AsmError(f"linha {lineno}: '{mnem}' espera Rx, Ry")
                emit((opc << 4) | (parse_reg(ops[0], lineno) << 2) | parse_reg(ops[1], lineno), text)
            elif fmt == "r":
                if len(ops) != 1:
                    raise AsmError(f"linha {lineno}: '{mnem}' espera Rx")
                emit((opc << 4) | (parse_reg(ops[0], lineno) << 2) | fn, text)
            elif fmt == "rm":
                m = re.fullmatch(r"\[\s*(\w+)\s*\]", ops[1]) if len(ops) == 2 else None
                if not m:
                    raise AsmError(f"linha {lineno}: '{mnem}' espera Rx, [Ry]")
                emit((opc << 4) | (parse_reg(ops[0], lineno) << 2) | parse_reg(m.group(1), lineno), text)
            elif fmt == "ri":
                if len(ops) != 2:
                    raise AsmError(f"linha {lineno}: '{mnem}' espera Rx, valor")
                emit((opc << 4) | (parse_reg(ops[0], lineno) << 2) | fn, text)
                emit(num(ops[1]), ops[1])
            elif fmt == "i":
                if len(ops) != 1:
                    raise AsmError(f"linha {lineno}: '{mnem}' espera um endereco")
                emit(opc << 4, text)
                emit(num(ops[0]), ops[0])
        return mem, notes

    run(final=False)
    mem, notes = run(final=True)
    return [b if b is not None else 0 for b in mem], {a: n for a, n in notes.items()}, mem


def vhdl_block(mem_used, notes, name="programa", indent=8):
    pad = " " * indent
    out = [f"{pad}-- {name}", f"{pad}signal ram : RAM_t := ("]
    for addr, b in enumerate(mem_used):
        if b is None:
            continue
        out.append(f'{pad}    {addr:3d} => "{b:08b}", -- {notes.get(addr, "")}')
    out.append(f"{pad}    others => (others => '0')")
    out.append(f"{pad});")
    return "\n".join(out)


def patch_ram(path, block):
    with open(path, encoding="utf-8") as f:
        src = f.read()
    pat = re.compile(r"[ \t]*-- PROGRAM BEGIN.*?-- PROGRAM END[^\n]*", re.S)
    new = "        -- PROGRAM BEGIN (gerado por tools/asm.py)\n" + block + "\n        -- PROGRAM END"
    if pat.search(src):
        src = pat.sub(lambda _: new, src, count=1)
    else:
        pat2 = re.compile(r"[ \t]*signal\s+ram\s*:\s*RAM_t\s*:=\s*\(.*?\n\s*\);", re.S | re.I)
        if not pat2.search(src):
            raise AsmError("nao encontrei a declaracao 'signal ram : RAM_t := (...);' no arquivo")
        src = pat2.sub(lambda _: new, src, count=1)
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)


def main():
    ap = argparse.ArgumentParser(description="Montador da CPU de 8 bits")
    ap.add_argument("source")
    ap.add_argument("-o", "--output", help="grava o bloco VHDL neste arquivo")
    ap.add_argument("--ram", help="substitui o bloco de programa neste RAM.vhd")
    ap.add_argument("--hex", action="store_true", help="imprime tambem o dump hexadecimal")
    args = ap.parse_args()
    with open(args.source, encoding="utf-8") as f:
        src = f.read()
    try:
        mem, notes, used = assemble(src)
    except AsmError as e:
        sys.exit(f"erro: {e}")
    name = args.source.replace("\\", "/").split("/")[-1]
    block = vhdl_block(used, notes, name)
    if args.ram:
        patch_ram(args.ram, block)
        print(f"{args.ram} atualizado com {name}")
    elif args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(block + "\n")
    else:
        print(block)
    if args.hex:
        for a in range(0, 256, 16):
            print(f"{a:02X}: " + " ".join(f"{b:02X}" for b in mem[a:a + 16]))


if __name__ == "__main__":
    main()
