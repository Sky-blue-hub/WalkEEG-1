# Read COM6 for 15s — board must run app_nus (UART heartbeat every 3s)
param(
    [string]$Port = "COM6",
    [int]$Baud = 115200,
    [int]$Seconds = 15
)

$ErrorActionPreference = "Stop"

Write-Host "Opening $Port @ $Baud for $Seconds seconds..." -ForegroundColor Cyan
Write-Host "Close PuTTY/Cursor COM6 first!" -ForegroundColor Yellow
Write-Host ""

try {
    $sp = New-Object System.IO.Ports.SerialPort $Port, $Baud, "None", 8, "One"
    $sp.DtrEnable = $true
    $sp.RtsEnable = $true
    $sp.ReadTimeout = 1000
    $sp.Open()

    $deadline = (Get-Date).AddSeconds($Seconds)
    $gotData = $false

    while ((Get-Date) -lt $deadline) {
        if ($sp.BytesToRead -gt 0) {
            $chunk = $sp.ReadExisting()
            if ($chunk.Length -gt 0) {
                $gotData = $true
                Write-Host $chunk -NoNewline
            }
        }
        Start-Sleep -Milliseconds 100
    }

    $sp.Close()

    Write-Host ""
    if ($gotData) {
        Write-Host "OK: Received data on $Port" -ForegroundColor Green
        exit 0
    }

    Write-Host "FAIL: No data on $Port (J-Link VCOM path broken)" -ForegroundColor Red
    exit 1
} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 2
}
