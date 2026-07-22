# Run full pipeline after NCS SDK is installed.
# Usage: powershell -File scripts/run-all.ps1 [-SkipFlash]
param([switch]$SkipFlash)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent

Write-Host "=== nRF52840 DK Full Pipeline ===" -ForegroundColor Cyan

& (Join-Path $PSScriptRoot "check-env.ps1")
if ($LASTEXITCODE -ne 0) { exit 1 }

& (Join-Path $PSScriptRoot "update-settings.ps1")
& (Join-Path $PSScriptRoot "sync-from-ncs.ps1")

& (Join-Path $PSScriptRoot "build.ps1") -App app -Board nrf52840dk/nrf52840
if (-not $SkipFlash) {
    & (Join-Path $PSScriptRoot "flash.ps1") -App app -Board nrf52840dk/nrf52840
}

& (Join-Path $PSScriptRoot "build.ps1") -App app_nus -Board nrf52840dk/nrf52840
if (-not $SkipFlash) {
    & (Join-Path $PSScriptRoot "flash.ps1") -App app_nus -Board nrf52840dk/nrf52840
}

Write-Host ""
Write-Host "Pipeline complete." -ForegroundColor Green
Write-Host "Mobile test: see docs/NUS_MOBILE_TEST.md" -ForegroundColor Yellow
