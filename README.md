# Nim patched-toolchain branch

Orphan branch of this fork carrying the backport patch series and build
recipe behind the `ghcr.io/coreyleavitt/nim` dev images, so CI runners can
build the same patched toolchain for platforms the container images do not
cover (currently macOS) and on fixed-glibc runners for the glibc artifacts.

The source of truth for the patch series is the WSL-side
`nim/toolchain/patches/` directory; this branch is a synced copy, like the
Windows port's `patches/`. Re-sync after changing the series.

- `patches/2.2.10/` — ordered backport series (see each patch header; applied
  by `build-nim.sh` before `koch boot`).
- `build-nim.sh` — pinned from-source build into a self-contained prefix
  (identical to the container recipe, plus a shasum shim for macOS).
- `tests/` — repro programs for the bugs the series fixes; the workflow runs
  them against the built compiler. `check_*.nim` entries inspect the emitted
  C instead of running a program, so a `--cc:vcc` codegen fix is verified on
  hosts without MSVC.
- `scripts/check-glibc-floor.sh` — release guard: max GLIBC_x.y over every ELF
  in a prefix must not exceed `GLIBC_FLOOR`.
- `.github/workflows/native-artifacts.yml` — builds the prefix directly on
  native runners (macos-arm64, linux-arm64, linux-x64) and publishes it as an OCI
  artifact via oras; triggered by pushes to this branch.
- `.github/workflows/linux-images.yml` — dispatch-only for now: builds the
  glibc + alpine dev-base images from the committed series, validates,
  pushes, and re-stitches the shared manifest lists.
- `.github/workflows/windows-images.yml` — dispatch-only, experimental:
  MSVC + mingw images on a windows-2025 runner (process isolation), with
  the same validate/push/re-stitch flow. The release tarball is seeded into
  the build context (`cache/`) because the Dockerfiles no longer download
  it in-build.

Every platform also publishes the bare toolchain prefix as an OCI artifact
next to the container tags — the fast path for CI (a few dozen MB instead of
a container pull; only needs a C compiler on the consumer):

| tag | contents |
|---|---|
| `2.2.10-linux-x64` | glibc prefix, tar.xz (runner-built on ubuntu-22.04; NOT the `2.2.10` image, which is rolling Tumbleweed) |
| `2.2.10-linux-x64-musl` | musl prefix, tar.xz (same bits as `-alpine`) |
| `2.2.10-windows-x64` | MSVC prefix, zip (same bits as `-windows`) |
| `2.2.10-linux-arm64` | glibc arm64 prefix, tar.xz (runner-built on ubuntu-22.04-arm, no container equivalent) |
| `2.2.10-macos-arm64` | arm64 prefix, tar.xz (no container equivalent) |

glibc floor: the `linux-x64` and `linux-arm64` artifacts run on any host with
glibc >= 2.35 (Ubuntu 22.04 and newer, Debian 12 and newer). They are built on
ubuntu-22.04 runners, and `scripts/check-glibc-floor.sh` fails the build before
any push if an ELF in the prefix requires a glibc symbol version above
`GLIBC_FLOOR` (declared once, in `native-artifacts.yml`). The guard is proven
in both directions by `tests/glibc_floor/test.sh` (podman). Hosts with an older
glibc should use `linux-x64-musl`. The `2.2.10` container image remains
Tumbleweed-based and is not covered by the floor.

Consume:

```
oras pull ghcr.io/coreyleavitt/nim:2.2.10-macos-arm64
tar xf nim-2.2.10-patched-macos-arm64.tar.xz
./nim-2.2.10-patched/bin/nim --version
```
