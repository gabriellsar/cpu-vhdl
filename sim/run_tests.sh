#!/usr/bin/env bash
# run_tests.sh - simula cada programa de programs/ no GHDL e compara o trace da
# CPU em VHDL com o do simulador de referencia (tools/sim.py).
#   uso: ./sim/run_tests.sh [programa.asm ...]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/sim/build"
mkdir -p "$BUILD"
PROGS=("$@")
[ ${#PROGS[@]} -eq 0 ] && PROGS=("$ROOT"/programs/*.asm)

SRC="$ROOT/src/cpu_pkg.vhd $ROOT/src/alu.vhd $ROOT/src/cpu.vhd $ROOT/src/clock_enable.vhd \
     $ROOT/src/lcd_text.vhd $ROOT/src/lcd_controller.vhd"
FAIL=0
for p in "${PROGS[@]}"; do
    name="$(basename "$p" .asm)"
    work="$BUILD/$name"; rm -rf "$work"; mkdir -p "$work"
    cp "$ROOT/src/RAM.vhd" "$work/RAM.vhd"
    python3 "$ROOT/tools/asm.py" "$p" --ram "$work/RAM.vhd" >/dev/null
    python3 "$ROOT/tools/sim.py" "$p" --trace "$work/trace_py.txt"
    ( cd "$work"
      ghdl -a --std=93c -fexplicit $SRC RAM.vhd "$ROOT/sim/tb_cpu.vhd"
      ghdl -e --std=93c -fexplicit tb_cpu
      ghdl -r --std=93c tb_cpu -gTRACE_FILE=trace_vhdl.txt --ieee-asserts=disable-at-0 2>&1 | grep -v "^$" | tail -2 )
    if diff -q "$work/trace_py.txt" "$work/trace_vhdl.txt" >/dev/null; then
        echo "[OK]   $name: $(wc -l < "$work/trace_vhdl.txt") instrucoes identicas ao modelo"
    else
        echo "[FAIL] $name"; diff "$work/trace_py.txt" "$work/trace_vhdl.txt" | head -10; FAIL=1
    fi
done
exit $FAIL
