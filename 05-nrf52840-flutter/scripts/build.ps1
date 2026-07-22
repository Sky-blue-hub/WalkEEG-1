param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("app", "app_nus")]
    [string]$App,

    [string]$Board = "nrf52840dk/nrf52840",
    [switch]$Pristine
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$appDir = Join-Path $root $App
$buildDir = Join-Path $appDir "build"

if (-not (Test-Path $appDir)) {
    throw "Application not found: $appDir"
}

Write-Host "Building $App for board $Board..." -ForegroundColor Cyan
Write-Host "NOTE: Run this from nRF Connect Terminal for best results." -ForegroundColor Yellow
Write-Host ""

Push-Location $appDir
try {
    if ($Pristine -and (Test-Path $buildDir)) {
        Write-Host "Pristine rebuild: removing $buildDir"
        Remove-Item -Recurse -Force $buildDir
    }

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

    & $westExe build -b $Board -d build
    if ($LASTEXITCODE -ne 0) {
        throw "west build failed with exit code $LASTEXITCODE"
    }

    Write-Host ""
    Write-Host "Build succeeded: $buildDir" -ForegroundColor Green
} finally {
    Pop-Location
}
