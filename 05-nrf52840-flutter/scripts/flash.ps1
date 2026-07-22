param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("app", "app_nus")]
    [string]$App,

    [string]$Board = "nrf52840dk/nrf52840",
    [string]$Runner = "jlink"
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$appDir = Join-Path $root $App
$buildDir = Join-Path $appDir "build"

if (-not (Test-Path $buildDir)) {
    throw "Build directory not found. Run build first: scripts/build.ps1 -App $App"
}

Write-Host "Flashing $App ($Board)..." -ForegroundColor Cyan
Write-Host "Ensure nRF52840 DK is connected via J-Link USB port." -ForegroundColor Yellow
Write-Host ""

Push-Location $appDir
try {
    $westCmd = Get-Command west -ErrorAction SilentlyContinue
    if (-not $westCmd) {
        . (Join-Path $PSScriptRoot "ncs-env.ps1")
        $envInfo = Get-NcsEnv
        $env:ZEPHYR_BASE = $envInfo.ZephyrBase
        $envPath = $envInfo.EnvDir
        if (Test-Path $envPath) {
            $env:PATH = "$envPath;$($envInfo.NcsRoot);$env:PATH"
        }
        $westExe = $envInfo.WestExe
    } else {
        $westExe = "west"
    }

    & $westExe flash -d build --runner $Runner
    if ($LASTEXITCODE -ne 0) {
        throw "west flash failed with exit code $LASTEXITCODE"
    }

    Write-Host ""
    Write-Host "Flash succeeded." -ForegroundColor Green
} finally {
    Pop-Location
}
