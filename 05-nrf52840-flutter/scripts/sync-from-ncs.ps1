# Sync peripheral_uart sample from NCS into app_nus/
param(
    [string]$NcsRoot = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot "ncs-env.ps1")

if (-not $NcsRoot) {
    $env = Get-NcsEnv
    $NcsRoot = $env.NcsRoot
}

$src = Join-Path $NcsRoot "nrf\samples\bluetooth\peripheral_uart"
if (-not (Test-Path $src)) {
    throw "peripheral_uart not found at: $src"
}

$dst = Join-Path $root "app_nus"
$filesToCopy = @(
    "CMakeLists.txt",
    "prj.conf",
    "Kconfig",
    "Kconfig.sysbuild"
)

Write-Host "Syncing peripheral_uart from NCS..." -ForegroundColor Cyan
Write-Host "  Source: $src"
Write-Host "  Target: $dst"

foreach ($f in $filesToCopy) {
    $from = Join-Path $src $f
    if (Test-Path $from) {
        Copy-Item -Path $from -Destination (Join-Path $dst $f) -Force
        Write-Host "  Copied $f"
    }
}

# Copy src/
$srcDir = Join-Path $src "src"
$dstSrc = Join-Path $dst "src"
if (-not (Test-Path $dstSrc)) {
    New-Item -ItemType Directory -Path $dstSrc -Force | Out-Null
}
Copy-Item -Path (Join-Path $srcDir "*") -Destination $dstSrc -Recurse -Force
Write-Host "  Copied src/"

# Copy boards/ if present
$boardsDir = Join-Path $src "boards"
if (Test-Path $boardsDir) {
    $dstBoards = Join-Path $dst "boards"
    Copy-Item -Path $boardsDir -Destination $dstBoards -Recurse -Force
    Write-Host "  Copied boards/"
}

Write-Host "Done. Build with: west build -b nrf52840dk/nrf52840 -d build" -ForegroundColor Green
