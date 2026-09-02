# Nim patched-toolchain branch

Orphan branch of this fork carrying the backport patch series and build
recipe behind the `ghcr.io/coreyleavitt/nim` dev images, so CI runners can
build the same patched toolchain for platforms the container images do not
cover (currently macOS).

The source of truth for the patch series is the WSL-side
`nim/toolchain/patches/` directory; this branch is a synced copy, like the
Windows port's `patches/`. Re-sync after changing the series.

- `patches/2.2.10/` — ordered backport series (see each patch header; applied
  by `build-nim.sh` before `koch boot`).
- `build-nim.sh` — pinned from-source build into a self-contained prefix
  (identical to the container recipe, plus a shasum shim for macOS).
- `tests/` — repro programs for the bugs the series fixes; the workflow runs
  them against the built compiler.
- `.github/workflows/native-artifacts.yml` — builds the prefix directly on
  native runners (macos-arm64, linux-arm64) and publishes it as an OCI
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
| `2.2.10-linux-x64` | glibc prefix, tar.xz (same bits as the `2.2.10` image) |
| `2.2.10-linux-x64-musl` | musl prefix, tar.xz (same bits as `-alpine`) |
| `2.2.10-windows-x64` | MSVC prefix, zip (same bits as `-windows`) |
| `2.2.10-linux-arm64` | glibc arm64 prefix, tar.xz (runner-built, no container equivalent) |
| `2.2.10-macos-arm64` | arm64 prefix, tar.xz (no container equivalent) |

Consume:

```
oras pull ghcr.io/coreyleavitt/nim:2.2.10-macos-arm64
tar xf nim-2.2.10-patched-macos-arm64.tar.xz
./nim-2.2.10-patched/bin/nim --version
```
