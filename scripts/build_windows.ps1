# Duplix Windows Build Script (PowerShell)
$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSScriptRoot
$DistDir = Join-Path $RootDir "dist\windows"

Write-Host "==> Building Duplix for Windows (Release)..." -ForegroundColor Cyan
Set-Location $RootDir

swift build -c release --product duplix

if (!(Test-Path $DistDir)) {
    New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
}

$BinPath = Join-Path $RootDir ".build\release\duplix.exe"
if (Test-Path $BinPath) {
    Copy-Item $BinPath (Join-Path $DistDir "duplix.exe") -Force
    Write-Host "==> Windows build successful at: $DistDir\duplix.exe" -ForegroundColor Green
} else {
    Write-Host "==> Binary built at: .build\release\duplix" -ForegroundColor Yellow
}
