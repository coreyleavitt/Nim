# Stage the minimal MSVC + Windows SDK subset Nim needs into C:\staging\msvc,
# for COPY --from into the final image. x64-hosted, x64-targeting only.
# vccexe runs cl from PATH with the ambient env when vcvarsall.bat is absent
# (tools/vccexe/vccexe.nim), so none of the VS installer machinery is needed —
# just these trees plus INCLUDE/LIB/PATH baked in the final stage.
$ErrorActionPreference = 'Stop'

$vs = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools'
$msvc = (Get-ChildItem "$vs\VC\Tools\MSVC" -Directory | Sort-Object Name -Descending | Select-Object -First 1).FullName
$sdkRoot = 'C:\Program Files (x86)\Windows Kits\10'
$sdkVer = (Get-ChildItem "$sdkRoot\Include" -Directory | Sort-Object Name -Descending | Select-Object -First 1).Name
Write-Host "MSVC: $msvc"
Write-Host "SDK:  $sdkVer"

$out = 'C:\staging\msvc'
New-Item -ItemType Directory -Force -Path "$out\vc", "$out\sdk\include", "$out\sdk\lib", "$out\sdk\bin" | Out-Null

# Compiler, C/C++ headers, x64 libs. Skips Hostx86/x86/onecore variants.
Copy-Item -Recurse "$msvc\bin\Hostx64\x64" "$out\vc\bin"
Copy-Item -Recurse "$msvc\include" "$out\vc\include"
Copy-Item -Recurse "$msvc\lib\x64" "$out\vc\lib"

# VC runtime DLLs next to the tools: cl defaults to /MT so Nim-built exes are
# self-contained, but anything built /MD resolves the redist via PATH.
$crt = Get-ChildItem "$vs\VC\Redist\MSVC" -Recurse -Directory -Filter 'Microsoft.VC*.CRT' |
    Where-Object FullName -Match '\\x64\\' | Select-Object -First 1
if ($crt) { Copy-Item "$($crt.FullName)\*.dll" "$out\vc\bin" }

# Windows SDK: C headers, x64 import libs, resource compiler.
foreach ($d in 'ucrt', 'um', 'shared') {
    Copy-Item -Recurse "$sdkRoot\Include\$sdkVer\$d" "$out\sdk\include\$d"
}
Copy-Item -Recurse "$sdkRoot\Lib\$sdkVer\ucrt\x64" "$out\sdk\lib\ucrt"
Copy-Item -Recurse "$sdkRoot\Lib\$sdkVer\um\x64" "$out\sdk\lib\um"
Copy-Item "$sdkRoot\bin\$sdkVer\x64\rc.exe", "$sdkRoot\bin\$sdkVer\x64\rcdll.dll" "$out\sdk\bin"

$size = (Get-ChildItem -Recurse -Force $out | Measure-Object Length -Sum).Sum
Write-Host ("staged {0:N0} MB" -f ($size / 1MB))
