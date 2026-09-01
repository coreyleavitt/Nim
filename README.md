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
- `.github/workflows/macos-toolchain.yml` — workflow_dispatch build that
  publishes `ghcr.io/coreyleavitt/nim:<ver>-macos-<arch>` as an OCI artifact
  (a tar.xz of the prefix, pushed with oras).

Consume:

```
oras pull ghcr.io/coreyleavitt/nim:2.2.10-macos-arm64
tar xf nim-2.2.10-patched-macos-arm64.tar.xz
./nim-2.2.10-patched/bin/nim --version
```
