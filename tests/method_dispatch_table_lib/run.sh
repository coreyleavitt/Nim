#!/bin/sh
# Two Nim static libraries, each with methods, link into one C program
# (patch 0008): a library build must not define nimMethodDispatchTable, or the
# two would collide. Run from any directory with `nim` and a C compiler on PATH.
set -e
here=$(cd "$(dirname "$0")" && pwd)
d=$(mktemp -d)
trap 'rm -rf "$d"' EXIT
nim c --hints:off --app:staticlib --noMain --nimMainPrefix:A --nimcache:"$d/ca" -o:"$d/liba.a" "$here/liba.nim"
nim c --hints:off --app:staticlib --noMain --nimMainPrefix:B --nimcache:"$d/cb" -o:"$d/libb.a" "$here/libb.nim"
if nm "$d/liba.a" "$d/libb.a" | grep -q ' [TtDdRr] .*nimMethodDispatchTable'; then
  echo "FAIL: a static library defines nimMethodDispatchTable"; exit 1
fi
${CC:-cc} "$here/main.c" "$d/liba.a" "$d/libb.a" -o "$d/m" -lm
"$d/m"
echo ok
