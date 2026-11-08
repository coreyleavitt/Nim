#!/usr/bin/env bash
# Proves scripts/check-glibc-floor.sh in both directions with podman:
#   FAIL on a probe built in a new-glibc image (tumbleweed, pulls sinh@GLIBC_2.44)
#   PASS on the same probe built in ubuntu:22.04 (glibc 2.35)
# Run from the repo root:  tests/glibc_floor/test.sh
set -uo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
FLOOR=2.35

build() { # image, install-cmd, outdir
  mkdir -p "$3/bin"
  podman run --rm -v "$root/tests/glibc_floor:/src:ro,Z" -v "$3:/out:Z" "$1" bash -c \
    "($2) >/dev/null 2>&1; gcc -O0 /src/libm_probe.c -o /out/bin/probe -lm -ldl -lpthread" \
    || { echo "build failed in $1" >&2; exit 2; }
}
build docker.io/opensuse/tumbleweed 'zypper -n install -y gcc binutils' "$work/new"
build docker.io/library/ubuntu:22.04 'apt-get update && apt-get install -y gcc libc6-dev' "$work/old"

rc=0
echo "== new glibc (expect FAIL)"
GLIBC_FLOOR=$FLOOR "$root/scripts/check-glibc-floor.sh" "$work/new"; r=$?
[ $r -eq 1 ] || { echo "UNEXPECTED rc=$r"; rc=1; }
echo "== ubuntu:22.04 (expect PASS)"
GLIBC_FLOOR=$FLOOR "$root/scripts/check-glibc-floor.sh" "$work/old"; r=$?
[ $r -eq 0 ] || { echo "UNEXPECTED rc=$r"; rc=1; }
echo "== empty prefix (expect FAIL)"
mkdir "$work/empty"
GLIBC_FLOOR=$FLOOR "$root/scripts/check-glibc-floor.sh" "$work/empty"; r=$?
[ $r -eq 1 ] || { echo "UNEXPECTED rc=$r"; rc=1; }
[ $rc -eq 0 ] && echo "ALL OK" || echo "TEST FAILED"
exit $rc
