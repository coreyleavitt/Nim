#!/usr/bin/env bash
# Build one released Nim from its official source tarball and install it into a
# self-contained prefix (bin/ + lib/ + config/), so `<prefix>/bin/nim` resolves
# its own stdlib relative to the binary and never collides with other versions.
#
#   build-nim.sh <version> <sha256> <prefix>
#   build-nim.sh 2.2.4 f82b419750fcce561f3f897a0486b180186845d76fb5d99f248ce166108189c7 /opt/nim/2.2.4
set -euo pipefail

# macOS ships shasum, not sha256sum; same checkfile format.
command -v sha256sum >/dev/null 2>&1 || sha256sum() { shasum -a 256 "$@"; }

ver="$1"; sha="$2"; prefix="$3"
tarball="nim-${ver}.tar.xz"
work="/tmp/nimbuild-${ver}"
cache="${TARBALL_CACHE:-/tmp}"          # persisted build cache mount when set

# Download into the cache only on a miss; always re-verify the cached copy.
mkdir -p "$cache"
if [ ! -f "$cache/$tarball" ]; then
  curl -fsSL "https://nim-lang.org/download/${tarball}" -o "$cache/$tarball.tmp"
  mv "$cache/$tarball.tmp" "$cache/$tarball"
fi
echo "${sha}  $cache/$tarball" | sha256sum -c -

mkdir -p "$work"; cd "$work"
tar xf "$cache/$tarball"
cd "nim-${ver}"

# Backport patches, applied as an ordered series before `koch boot` recompiles the
# compiler (so the booted nim carries the fixes). The csources bootstrap (build.sh)
# uses pre-generated C and is unaffected. Two inputs, applied in this order:
#   NIM_PATCH_DIR  every *.patch in the dir, in sorted (numeric-prefix) order
#   NIM_PATCHES    explicit space-separated list, applied after the dir
# Ordering is deterministic so harder, interdependent fixes can be sequenced.
patches=""
[ -n "${NIM_PATCH_DIR:-}" ] && patches="$(ls "$NIM_PATCH_DIR"/*.patch 2>/dev/null | LC_ALL=C sort)"
patches="$patches ${NIM_PATCHES:-}"
for p in $patches; do
  [ -n "$p" ] || continue
  echo ">> applying patch: $p"
  patch -p1 --batch --forward < "$p"
done

# build.sh compiles the bundled C sources into bin/nim, then we bootstrap an
# optimized compiler. --skip*Cfg keeps any ambient nim.cfg from leaking in.
sh build.sh
./bin/nim c --skipUserCfg --skipParentCfg koch
./koch boot -d:release --skipUserCfg --skipParentCfg

# Optional: build the bundled tools (nimble, nimgrep, …) into bin/ for a dev
# image. The matrix image leaves this unset (stdlib-only repros need no nimble).
if [ "${NIM_KOCH_TOOLS:-}" = "1" ]; then
  ./koch tools -d:release --skipUserCfg --skipParentCfg
fi

mkdir -p "$prefix"
cp -a bin lib config "$prefix/"

cd /; rm -rf "$work"
"$prefix/bin/nim" --version | head -1
