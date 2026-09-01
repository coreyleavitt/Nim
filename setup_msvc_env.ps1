# Find vcvarsall.bat and bake its environment into the machine-level env vars
$vcvars = Get-ChildItem 'C:\Program Files (x86)\Microsoft Visual Studio' -Recurse -Filter 'vcvarsall.bat' | Select-Object -First 1
if (-not $vcvars) {
    Write-Error "vcvarsall.bat not found"
    exit 1
}

# Write a batch file that calls vcvarsall then dumps env
$batContent = "@call `"$($vcvars.FullName)`" x64 >nul 2>&1`r`nset"
[System.IO.File]::WriteAllText('C:\getvars.bat', $batContent)

# Run it and parse the output
$output = cmd /c C:\getvars.bat
foreach ($line in $output) {
    if ($line -match '^([^=]+)=(.*)$') {
        [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Machine')
    }
}

Remove-Item -Force C:\getvars.bat
Write-Host "MSVC environment baked into machine env vars"
