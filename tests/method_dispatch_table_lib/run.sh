#!/bin/sh
# Two Nim static libraries, each with methods, link into one C program
# (patch 0008): a library build must not define nimMethodDispatchTable, or the
# two would collide. Run from any directory with `nim` and a C compiler on PATH.
set -e
here=$(cd "$(dirname "$0")" && pwd)
d=$(mktemp -d)
trap 'rm -rf "$d"' EXIT
# Nim's clang profile archives with llvm-ar, which an image may lack (alpine
# ships binutils' ar only); the formats are the same, so stand ar in for it.
if ! command -v llvm-ar >/dev/null 2>&1 && command -v ar >/dev/null 2>&1; then
  mkdir "$d/bin" && ln -s "$(command -v ar)" "$d/bin/llvm-ar"
  PATH="$d/bin:$PATH"
fi
nim c --hints:off --app:staticlib --noMain --nimMainPrefix:A --nimcache:"$d/ca" -o:"$d/liba.a" "$here/liba.nim"
nim c --hints:off --app:staticlib --noMain --nimMainPrefix:B --nimcache:"$d/cb" -o:"$d/libb.a" "$here/libb.nim"
if nm "$d/liba.a" "$d/libb.a" | grep -q ' [TtDdRr] .*\(nimMethodDispatchTable\|nimSubtypeHookTable\)'; then
  echo "FAIL: a static library defines nimMethodDispatchTable or nimSubtypeHookTable"; exit 1
fi
${CC:-cc} "$here/main.c" "$d/liba.a" "$d/libb.a" -o "$d/m" -lm
"$d/m"
echo ok
