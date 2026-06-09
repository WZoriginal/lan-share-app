$ErrorActionPreference = "SilentlyContinue"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$PidFile = Join-Path $Root ".lan-share.pid"
$stopped = $false

if (Test-Path $PidFile) {
    $pidValue = Get-Content $PidFile -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pidValue) {
        $process = Get-Process -Id ([int]$pidValue) -ErrorAction SilentlyContinue
        if ($process) {
            Stop-Process -Id $process.Id -Force
            $stopped = $true
        }
    }
    Remove-Item $PidFile -Force
}

Add-Type -AssemblyName PresentationFramework
if ($stopped) {
    [System.Windows.MessageBox]::Show("LAN Share has been stopped.", "LAN Share") | Out-Null
} else {
    [System.Windows.MessageBox]::Show("No running LAN Share process was found from this launcher.", "LAN Share") | Out-Null
}
