# PowerShell port of toolchain/build-nim.sh from the WSL bug-busting workbench.
# Build one released Nim from its official source tarball and install it into a
# self-contained prefix (bin/ + lib/ + config/), so <prefix>\bin\nim.exe resolves
# its own stdlib relative to the binary and never collides with other versions.
#
# Differences from the Linux script:
#   - stage-0 is a stock same-version binary install (-Bootstrap), not the
#     csources build.bat (which requires mingw)
#   - patches go on with MinGit `git apply -p1` (no GNU patch on Windows), so
#     the series must be git-apply clean (exact hunk counts)
#   - cc = <-CC> is appended to the tree's config\nim.cfg before building, which
#     covers koch, boot, tools, and the installed prefix (config\ is copied).
#     -CC vcc (default, the MSVC image) needs the SDK rc.exe and vccexe.exe
#     staging below; -CC gcc (the mingw image) just needs gcc on PATH.
#
#   build-nim.ps1 -Version 2.2.10 -Sha256 <sha> -Prefix C:\nim\2.2.10-patched `
#     -Bootstrap C:\nim\2.2.10-stock [-PatchDir C:\nim-patches\2.2.10] [-KochTools] [-CC vcc|gcc]
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][string]$Sha256,
    [Parameter(Mandatory = $true)][string]$Prefix,
    [Parameter(Mandatory = $true)][string]$Bootstrap,
    [string]$PatchDir,
    [switch]$KochTools,
    [ValidateSet('vcc', 'gcc')][string]$CC = 'vcc'
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Native commands don't throw on failure in PS 5.1; check exit codes explicitly.
function Exec([scriptblock]$sb) {
    & $sb
    if ($LASTEXITCODE -ne 0) { throw "command failed ($LASTEXITCODE): $sb" }
}

$tarball = "nim-$Version.tar.xz"
$cache = if ($env:TARBALL_CACHE) { $env:TARBALL_CACHE } else { $env:TEMP }
$work = Join-Path $env:TEMP "nimbuild-$Version"

# Download into the cache only on a miss; always re-verify the cached copy.
New-Item -ItemType Directory -Force -Path $cache | Out-Null
$tarPath = Join-Path $cache $tarball
if (-not (Test-Path $tarPath)) {
    Invoke-WebRequest -Uri "https://nim-lang.org/download/$tarball" -OutFile "$tarPath.tmp"
    Move-Item -Force "$tarPath.tmp" $tarPath
}
$actual = (Get-FileHash -Algorithm SHA256 $tarPath).Hash.ToLowerInvariant()
if ($actual -ne $Sha256.ToLowerInvariant()) { throw "sha256 mismatch for ${tarball}: $actual" }

if (Test-Path $work) { Remove-Item -Recurse -Force $work }
New-Item -ItemType Directory -Force -Path $work | Out-Null
Exec { tar.exe -xf $tarPath -C $work }   # Windows bsdtar handles .tar.xz
$src = Join-Path $work "nim-$Version"
Set-Location $src

# The *-amd64-windows-vcc.res files that koch.nim and compiler/nim.nim
# {.link.} under cc = vcc exist only in the git repo, not the tarball — and
# the shipped icons/*.res are no substitute: they are windres i386 COFF
# objects despite the extension, and linking one flips the target machine to
# x86 (LNK1112). Build true RES files from the shipped .rc/.ico with the SDK
# resource compiler instead. (gcc builds link nothing vcc-named; skip.)
if ($CC -eq 'vcc') {
    foreach ($n in 'koch', 'nim') {
        Exec { rc.exe /nologo /fo "icons\$n-amd64-windows-vcc.res" "icons\$n.rc" }
    }
}

# Backport patches, applied as an ordered series before `koch boot` recompiles
# the compiler (so the booted nim carries the fixes). Sorted numeric-prefix
# order (0001-..., 0002-...) keeps interdependent fixes deterministic.
if ($PatchDir) {
    Get-ChildItem (Join-Path $PatchDir '*.patch') | Sort-Object Name | ForEach-Object {
        Write-Host ">> applying patch: $($_.FullName)"
        $p = $_.FullName
        Exec { git -c core.autocrlf=false apply -p1 --verbose $p }
    }
}

# Later assignments win in nim.cfg, so this overrides the default cc = gcc
# (a no-op but explicit under -CC gcc).
Add-Content -Path (Join-Path $src 'config\nim.cfg') -Value "`ncc = $CC"

# Stage-0: the stock binary of the same version, so its stdlib expectations
# match this tree.
Copy-Item (Join-Path $Bootstrap 'bin\nim.exe') bin\

# vcc only: every boot stage must resolve vccexe.exe (cc = vcc locates cl
# through it; compiler\nim1.exe in iteration 2+ searches only its own dir, the
# cwd, and PATH) — but it must NOT sit in bin\ while building: koch tools
# relinks bin\vccexe.exe, and the linker cannot overwrite the running exe that
# drives it (LNK1104). Stage it alone in its own dir on PATH; this also keeps
# the rest of the stock bin off PATH. Under gcc, PATH already carries mingw.
if ($CC -eq 'vcc') {
    $vcctool = Join-Path $work 'vcctool'
    New-Item -ItemType Directory -Force -Path $vcctool | Out-Null
    Copy-Item (Join-Path $Bootstrap 'bin\vccexe.exe') $vcctool
    $env:PATH = $vcctool + ';' + $env:PATH
}

# --skip*Cfg keeps any ambient nim.cfg from leaking in; the tree's own
# config\nim.cfg (with cc = vcc) is the system config and still applies.
Exec { .\bin\nim.exe c --skipUserCfg --skipParentCfg koch }
Exec { .\koch.exe boot -d:release --skipUserCfg --skipParentCfg }

# Optional: the bundled tools (nimble, nimgrep, ...) for a dev image.
if ($KochTools) {
    Exec { .\koch.exe tools -d:release --skipUserCfg --skipParentCfg }
}

# The prefix needs vccexe.exe at runtime (cc = vcc resolves cl through it).
# koch tools rebuilds it into bin\; without -KochTools, take the stock one.
if ($CC -eq 'vcc' -and -not (Test-Path 'bin\vccexe.exe')) {
    Copy-Item (Join-Path $Bootstrap 'bin\vccexe.exe') bin\
}

# Runtime DLLs + CA bundle from the stock install (nimble needs OpenSSL at
# runtime; the source tarball ships none of these).
Copy-Item (Join-Path $Bootstrap 'bin\*.dll') bin\
Copy-Item (Join-Path $Bootstrap 'bin\cacert.pem') bin\

New-Item -ItemType Directory -Force -Path $Prefix | Out-Null
foreach ($d in 'bin', 'lib', 'config') {
    Copy-Item -Recurse -Force (Join-Path $src $d) (Join-Path $Prefix $d)
}

Set-Location $env:TEMP
Remove-Item -Recurse -Force $work
& (Join-Path $Prefix 'bin\nim.exe') --version | Select-Object -First 1
