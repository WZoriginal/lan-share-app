$ErrorActionPreference = "SilentlyContinue"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$PidFile = Join-Path $Root ".lan-share.pid"

if (Test-Path $PidFile) {
    $pidValue = Get-Content $PidFile -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pidValue) {
        $process = Get-Process -Id ([int]$pidValue) -ErrorAction SilentlyContinue
        if ($process) {
            Stop-Process -Id $process.Id -Force
        }
    }
    Remove-Item $PidFile -Force
}

Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show("局域网共享服务已停止。", "LAN Share") | Out-Null
