# Find installed nRF Connect SDK under C:\ncs
function Find-NcsRoot {
    $ncsBase = "C:\ncs"
    if (-not (Test-Path $ncsBase)) {
        return $null
    }

    $versions = Get-ChildItem -Path $ncsBase -Directory |
        Where-Object { $_.Name -match '^v\d+\.\d+\.\d+' } |
        Sort-Object { [version]($_.Name -replace '^v', '') } -Descending

    foreach ($v in $versions) {
        $zephyrDir = Join-Path $v.FullName "zephyr"
        $westYml = Join-Path $v.FullName "west.yml"
        if ((Test-Path $zephyrDir) -and ((Test-Path $westYml) -or (Test-Path (Join-Path $v.FullName ".west")))) {
            return $v.FullName
        }
    }

    return $null
}

function Find-NcsWest {
    param([string]$NcsRoot)

    $toolchainBase = Join-Path "C:\ncs" "toolchains"
    if (-not (Test-Path $toolchainBase)) {
        return $null
    }

    $toolchains = Get-ChildItem -Path $toolchainBase -Directory |
        Sort-Object LastWriteTime -Descending

    foreach ($tc in $toolchains) {
        $west = Get-ChildItem -Path $tc.FullName -Recurse -Filter "west.exe" -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($west) {
            return $west.FullName
        }
    }

    return $null
}

function Get-NcsEnv {
    $ncsRoot = Find-NcsRoot
    if (-not $ncsRoot) {
        throw "nRF Connect SDK not found. Install via Cursor nRF Connect panel (Manage SDKs)."
    }

    $westExe = Find-NcsWest -NcsRoot $ncsRoot
    if (-not $westExe) {
        throw "west.exe not found. Install Toolchain via nRF Connect panel (Manage toolchains)."
    }

    $toolchainDir = Split-Path (Split-Path $westExe -Parent) -Parent
    $envDir = Join-Path $toolchainDir "opt\binaries\0\bin"
    if (-not (Test-Path $envDir)) {
        $envDir = Split-Path $westExe -Parent
    }

    return @{
        NcsRoot = $ncsRoot
        WestExe = $westExe
        EnvDir  = $envDir
        ZephyrBase = Join-Path $ncsRoot "zephyr"
    }
}
