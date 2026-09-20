$ErrorActionPreference = 'Stop'
$k6Version = '1.6.1'
$toolRoot = Join-Path $PSScriptRoot '.tools/k6'
$localK6 = Join-Path $toolRoot 'k6.exe'

if (Get-Command k6 -ErrorAction SilentlyContinue) {
    exit 0
}
if (Test-Path -LiteralPath $localK6) {
    exit 0
}

New-Item -ItemType Directory -Path $toolRoot -Force | Out-Null
$archive = Join-Path $PSScriptRoot ".tools/k6-$k6Version.zip"
$extract = Join-Path $PSScriptRoot ".tools/k6-$k6Version"
try {
    Write-Host "Downloading k6 v$k6Version for this repository..."
    Invoke-WebRequest -Uri "https://github.com/grafana/k6/releases/download/v$k6Version/k6-v$k6Version-windows-amd64.zip" -OutFile $archive
    Expand-Archive -LiteralPath $archive -DestinationPath $extract -Force
    $binary = Get-ChildItem -LiteralPath $extract -Recurse -Filter k6.exe | Select-Object -First 1
    if ($null -eq $binary) { throw 'k6.exe was not present in the downloaded archive.' }
    Move-Item -LiteralPath $binary.FullName -Destination $localK6 -Force
} finally {
    Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "k6 is ready: $localK6"
