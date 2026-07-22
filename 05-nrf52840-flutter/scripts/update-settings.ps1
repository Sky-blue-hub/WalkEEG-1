# Auto-update nrf-connect.topdir in .vscode/settings.json
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot "ncs-env.ps1")

$ncsRoot = Find-NcsRoot
if (-not $ncsRoot) {
    Write-Host "NCS not found at C:\ncs. Install SDK first." -ForegroundColor Red
    exit 1
}

$topdir = $ncsRoot -replace '\\', '/'
$settingsPath = Join-Path $root ".vscode\settings.json"
$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
$settings.'nrf-connect.topdir' = $topdir
$settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8

Write-Host "Updated nrf-connect.topdir to: $topdir" -ForegroundColor Green
