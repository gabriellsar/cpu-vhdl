#!/usr/bin/env python3
"""
sim.py - Simulador de referencia (nivel ISA) da CPU de 8 bits.

Gera a tabela passo a passo pedida na apresentacao (PC, LCD linha 1, flags,
MEM[255]) e o trace usado para conferir a simulacao VHDL (testbench).

Uso:
    python sim.py programa.asm                # tabela passo a passo
    python sim.py programa.asm --csv t.csv    # tabela em CSV
    python sim.py programa.asm --trace t.txt  # trace no formato do testbench
"""
import argparse
import csv
import sys

from asm import assemble, AsmError

RN = ["Ra", "Rb", "Rc", "Rd"]


def decode(ir):
    op, rx, fn = ir >> 4, (ir >> 2) & 3, ir & 3
    if op == 0x0: return "add"
    if op == 0x1: return "sub"
    if op == 0x2: return {0: "inc", 1: "dec"}.get(fn, "nop")
    if op == 0x3: return "and"
    if op == 0x4: return "or"
    if op == 0x5: return "not" if fn == 0 else "nop"
    if op == 0x6: return "xor"
    if op == 0x7: return ["rol", "ror", "lsl", "lsr"][fn]
    if op == 0x8: return ["push", "pop", "st", "ldi"][fn]
    if op == 0x9: return "ldr"
    if op == 0xA: return "str"
    if op == 0xB: return "mov"
    if op == 0xC:
        if fn == 0: return "jmp" if rx == 0 else "nop"
        return ["", "jmpr", "bz", "bnz"][fn]
    if op == 0xD: return ["bcs", "bcc", "beq", "bneq"][fn]
    if op == 0xE: return ["bgt", "blt", "bneg", "nop"][fn]
    return "halt" if ir == 0xFF else "nop"


ALU_OPS = {"add", "sub", "inc", "dec", "and", "or", "not", "xor", "rol", "ror", "lsl", "lsr"}


def lcd_line1(ir, op):
    """Mesmo texto gerado por lcd_text.vhd."""
    i = decode(ir)
    rx, ry = RN[(ir >> 2) & 3], RN[ir & 3]
    hx = f"0x{op:02X}"
    if i in ("add", "sub", "and", "or", "xor", "mov"):
        s = f"{i.upper()} {rx}, {ry}"
    elif i in ("ldr", "str"):
        s = f"{i.upper()} {rx}, [{ry}]"
    elif i in ("st", "ldi"):
        s = f"{i.upper()} {rx}, {hx}"
    elif i == "jmp":
        s = f"JMP {hx}"
    elif i in ("nop", "halt"):
        s = i.upper()
    else:
        s = f"{i.upper()} {rx}"
    return s.ljust(16)


def alu(i, a, b):
    if i in ("add", "inc"):
        r9 = a + b
    elif i in ("sub", "dec"):
        r9 = (a - b) & 0x1FF
    elif i == "and":
        r9 = a & b
    elif i == "or":
        r9 = a | b
    elif i == "xor":
        r9 = a ^ b
    elif i == "not":
        r9 = (~a) & 0xFF
    elif i == "rol":
        r9 = ((a >> 7) << 8) | ((a << 1) & 0xFF) | (a >> 7)
    elif i == "ror":
        r9 = ((a & 1) << 8) | ((a & 1) << 7) | (a >> 1)
    elif i == "lsl":
        r9 = ((a >> 7) << 8) | ((a << 1) & 0xFF)
    elif i == "lsr":
        r9 = ((a & 1) << 8) | (a >> 1)
    r = r9 & 0xFF
    flags = {
        "Z": int(r == 0), "N": r >> 7, "OVF": (r9 >> 8) & 1,
        "EQ": int(a == b), "GT": int(a > b), "SM": int(a < b),
    }
    return r, flags


class CPU:
    def __init__(self, mem):
        self.mem = list(mem)
        self.reg = [0, 0, 0, 0]
        self.pc = 0
        self.sp = 254
        self.f = {"Z": 0, "N": 0, "OVF": 0, "EQ": 0, "GT": 0, "SM": 0}

    def step(self):
        m, pc = self.mem, self.pc
        ir, op = m[pc], m[(pc + 1) & 0xFF]
        i = decode(ir)
        rx, ry = (ir >> 2) & 3, ir & 3
        R, f = self.reg, self.f
        nxt = (pc + 1) & 0xFF
        if i in ALU_OPS:
            b = {"inc": 1, "dec": 1}.get(i, R[ry] if i in ("add", "sub", "and", "or", "xor") else 0)
            R[rx], new = alu(i, R[rx], b)
            f.update(new)
        elif i == "push":
            m[self.sp] = R[rx]; self.sp = (self.sp - 1) & 0xFF
        elif i == "pop":
            R[rx] = m[(self.sp + 1) & 0xFF]; self.sp = (self.sp + 1) & 0xFF
        elif i == "st":
            m[op] = R[rx]; nxt = (pc + 2) & 0xFF
        elif i == "ldi":
            R[rx] = op; nxt = (pc + 2) & 0xFF
        elif i == "ldr":
            R[rx] = m[R[ry]]
        elif i == "str":
            m[R[ry]] = R[rx]
        elif i == "mov":
            R[rx] = R[ry]
        elif i == "jmp":
            nxt = op
        elif i == "halt":
            nxt = pc
        else:
            cond = {
                "jmpr": True, "bz": f["Z"], "bnz": not f["Z"], "bcs": f["OVF"],
                "bcc": not f["OVF"], "beq": f["EQ"], "bneq": not f["EQ"],
                "bgt": f["GT"], "blt": f["SM"], "bneg": f["N"],
            }.get(i, False)
            if cond:
                nxt = R[rx]
        self.pc = nxt
        return pc, ir, op, i


def run(mem, max_steps=2000):
    cpu = CPU(mem)
    rows = []
    for n in range(1, max_steps + 1):
        pc, ir, op, i = cpu.step()
        f = cpu.f
        rows.append({
            "step": n, "pc": pc, "lcd": lcd_line1(ir, op),
            "Z": f["Z"], "N": f["N"], "OVF": f["OVF"], "EQ": f["EQ"], "GT": f["GT"], "SM": f["SM"],
            "mem255": cpu.mem[255], "regs": list(cpu.reg), "sp": cpu.sp, "next": cpu.pc,
        })
        if i == "halt":
            break
    return rows


def trace_line(r):
    """Formato identico ao escrito por tb_cpu.vhd."""
    return (f"{r['step']} {r['pc']:02X} |{r['lcd']}| "
            f"{r['Z']}{r['N']}{r['OVF']}{r['EQ']}{r['GT']}{r['SM']} {r['mem255']:03d} "
            + " ".join(f"{v:02X}" for v in r["regs"]) + f" {r['sp']:02X} {r['next']:02X}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source")
    ap.add_argument("--max", type=int, default=2000)
    ap.add_argument("--csv")
    ap.add_argument("--trace")
    ap.add_argument("--regs", action="store_true", help="mostra registradores na tabela")
    args = ap.parse_args()
    try:
        mem, _, _ = assemble(open(args.source, encoding="utf-8").read())
    except AsmError as e:
        sys.exit(f"erro: {e}")
    rows = run(mem, args.max)

    if args.trace:
        with open(args.trace, "w") as fh:
            fh.write("\n".join(trace_line(r) for r in rows) + "\n")
    if args.csv:
        with open(args.csv, "w", newline="") as fh:
            w = csv.writer(fh)
            w.writerow(["Passo", "PC", "LCD linha 1", "Z", "N", "OVF", "EQ", "GT", "SM", "MEM[255]"])
            for r in rows:
                w.writerow([r["step"], r["pc"], r["lcd"].strip(), r["Z"], r["N"], r["OVF"],
                            r["EQ"], r["GT"], r["SM"], r["mem255"]])
    if not args.trace and not args.csv:
        hdr = f"{'Passo':>5} {'PC':>3}  {'LCD linha 1':<16}  Z N OVF EQ GT SM  MEM[255]"
        if args.regs:
            hdr += "   Ra  Rb  Rc  Rd  SP"
        print(hdr)
        for r in rows:
            s = (f"{r['step']:>5} {r['pc']:>3}  {r['lcd']}  {r['Z']} {r['N']}  {r['OVF']}   "
                 f"{r['EQ']}  {r['GT']}  {r['SM']}     {r['mem255']:03d}")
            if args.regs:
                s += "  " + " ".join(f"{v:3d}" for v in r["regs"]) + f" {r['sp']:3d}"
            print(s)
        if rows and rows[-1]["lcd"].strip() != "HALT":
            print(f"(parou apos {args.max} passos sem HALT)")


if __name__ == "__main__":
    main()
