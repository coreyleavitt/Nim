#!/usr/bin/env bash
# Fail if any ELF under a toolchain prefix requires a glibc symbol version
# newer than the declared floor.
#
#   GLIBC_FLOOR=2.35 check-glibc-floor.sh <prefix>
#
# The maximum is taken over every ELF file under <prefix> (executables and
# shared objects alike), from the undefined dynamic symbols' GLIBC_x.y
# version tags (`objdump -T`). Statically linked ELFs carry none and are
# skipped. A prefix with no ELF files at all also fails: a guard that saw
# nothing must not pass. Exit 0 = within floor, 1 = over floor / nothing
# checked, 2 = usage error.
set -euo pipefail

prefix="${1:-}"
floor="${GLIBC_FLOOR:-}"
[ -d "$prefix" ] && [ -n "$floor" ] || {
  echo "usage: GLIBC_FLOOR=<x.y> $0 <prefix>" >&2
  exit 2
}
command -v objdump >/dev/null || { echo "objdump not found" >&2; exit 2; }

is_elf() { [ "$(head -c4 "$1" 2>/dev/null | od -An -c | tr -d ' ')" = '177ELF' ]; }

max=0; nelf=0; fail=0
while IFS= read -r -d '' f; do
  is_elf "$f" || continue
  nelf=$((nelf + 1))
  # "<addr> g DF *UND* <addr> (GLIBC_2.38) sinh" -> "2.38 sinh"
  syms=$(objdump -T "$f" 2>/dev/null \
    | sed -n 's/.*\*UND\*.*(GLIBC_\([0-9][0-9.]*\)) *\(.*\)$/\1 \2/p' || true)
  [ -n "$syms" ] || continue
  fmax=$(printf '%s\n' "$syms" | cut -d' ' -f1 | sort -V | tail -n1)
  if [ "$(printf '%s\n%s\n' "$fmax" "$max" | sort -V | tail -n1)" != "$max" ]; then max="$fmax"; fi
  if [ "$(printf '%s\n%s\n' "$fmax" "$floor" | sort -V | tail -n1)" != "$floor" ]; then
    fail=1
    echo "OVER FLOOR: $f needs GLIBC_$fmax (floor $floor)" >&2
    printf '%s\n' "$syms" | sort -V | awk -v fl="$floor" '{print $1, $2}' \
      | while read -r v s; do
          [ "$(printf '%s\n%s\n' "$v" "$floor" | sort -V | tail -n1)" != "$floor" ] \
            && echo "    GLIBC_$v  $s" >&2
        done
  fi
done < <(find "$prefix" -type f -print0)

if [ "$nelf" -eq 0 ]; then
  echo "FAIL: no ELF files found under $prefix" >&2; exit 1
fi
if [ "$fail" -ne 0 ]; then
  echo "FAIL: highest required GLIBC_$max exceeds floor GLIBC_$floor" >&2; exit 1
fi
echo "PASS: $nelf ELF file(s), highest required GLIBC_$max <= floor GLIBC_$floor"
