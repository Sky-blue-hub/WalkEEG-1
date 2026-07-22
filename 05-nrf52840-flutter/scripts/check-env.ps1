# Check nRF52840 DK development environment readiness
$ErrorActionPreference = "Continue"
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot "ncs-env.ps1")

Write-Host "=== nRF52840 DK Environment Check ===" -ForegroundColor Cyan
Write-Host ""

$ok = $true

# Cursor extensions
Write-Host "[Extensions]"
$required = @(
    "nordic-semiconductor.nrf-connect",
    "nordic-semiconductor.nrf-terminal",
    "ms-vscode.cmake-tools"
)
foreach ($ext in $required) {
    $found = cursor --list-extensions 2>$null | Select-String -Pattern ([regex]::Escape($ext))
    if ($found) {
        Write-Host "  OK  $ext" -ForegroundColor Green
    } else {
        Write-Host "  MISSING  $ext" -ForegroundColor Red
        $ok = $false
    }
}
Write-Host ""

# NCS SDK
Write-Host "[nRF Connect SDK]"
$ncsRoot = Find-NcsRoot
if ($ncsRoot) {
    Write-Host "  OK  SDK at $ncsRoot" -ForegroundColor Green
    Write-Host "  Update .vscode/settings.json:" -ForegroundColor Yellow
    $topdir = $ncsRoot -replace '\\', '/'
    Write-Host "    `"nrf-connect.topdir`": `"$topdir`""
} else {
    Write-Host "  MISSING  C:\ncs\vX.Y.Z not found" -ForegroundColor Red
    Write-Host "  Install: Cursor -> nRF Connect -> Manage SDKs -> Install SDK"
    $ok = $false
}
Write-Host ""

# west
Write-Host "[west tool]"
$westExe = if ($ncsRoot) { Find-NcsWest -NcsRoot $ncsRoot } else { $null }
if ($westExe) {
    Write-Host "  OK  $westExe" -ForegroundColor Green
} else {
    Write-Host "  MISSING  Install Toolchain via nRF Connect panel" -ForegroundColor Red
    $ok = $false
}
Write-Host ""

# J-Link (nRF52840 DK has onboard J-Link)
Write-Host "[J-Link]"
$jlinkPaths = @(
    "C:\Program Files\SEGGER\JLink\JLink.exe",
    "${env:ProgramFiles(x86)}\SEGGER\JLink\JLink.exe"
)
$jlinkFound = $false
foreach ($p in $jlinkPaths) {
    if (Test-Path $p) {
        Write-Host "  OK  $p" -ForegroundColor Green
        $jlinkFound = $true
        break
    }
}
if (-not $jlinkFound) {
    Write-Host "  INFO  J-Link not in Program Files (may come with nRF Connect toolchain)" -ForegroundColor Yellow
}
Write-Host ""

# Project apps
Write-Host "[Applications]"
foreach ($app in @("app", "app_nus")) {
    $cmake = Join-Path $root "$app\CMakeLists.txt"
    if (Test-Path $cmake) {
        Write-Host "  OK  $app/" -ForegroundColor Green
    } else {
        Write-Host "  MISSING  $app/" -ForegroundColor Red
        $ok = $false
    }
}

$nusMain = Join-Path $root "app_nus\src\main.c"
$nusContent = Get-Content $nusMain -Raw -ErrorAction SilentlyContinue
if ($nusContent -match "Placeholder") {
    Write-Host "  WARN  app_nus/src/main.c is placeholder - run Sync NUS sample task after SDK install" -ForegroundColor Yellow
}
Write-Host ""

if ($ok -and $ncsRoot) {
    Write-Host "Environment ready. Use nRF Connect Terminal for build/flash." -ForegroundColor Green
    exit 0
} else {
    Write-Host "Environment not ready. Complete SDK installation first." -ForegroundColor Red
    exit 1
}
