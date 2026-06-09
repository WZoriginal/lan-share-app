$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Port = if ($env:LAN_SHARE_PORT) { [int]$env:LAN_SHARE_PORT } else { 8000 }
$LocalUrl = "http://127.0.0.1:$Port/"
$PidFile = Join-Path $Root ".lan-share.pid"
$UrlFile = Join-Path $Root "lan-share-url.txt"

Set-Location $Root

function Show-Message($Text) {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show($Text, "LAN Share") | Out-Null
}

function Find-Python {
    $commands = @(
        @{ File = "py"; Args = "-3" },
        @{ File = "python"; Args = "" },
        @{ File = "python3"; Args = "" }
    )

    foreach ($command in $commands) {
        $found = Get-Command $command.File -ErrorAction SilentlyContinue
        if ($found) {
            return $command
        }
    }

    Show-Message "Python 3 was not found. Please install Python 3 or add python.exe to PATH."
    exit 1
}

function Test-ServerReady {
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri "${LocalUrl}api/files" -TimeoutSec 1
        return $response.StatusCode -eq 200
    } catch {
        return $false
    }
}

function Get-LanIp {
    $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -and
            $_.IPAddress -notlike "127.*" -and
            $_.IPAddress -notlike "169.254.*" -and
            $_.IPAddress -notlike "172.16.*" -and
            $_.IPAddress -notlike "172.17.*" -and
            $_.IPAddress -notlike "172.18.*" -and
            $_.IPAddress -notlike "172.19.*"
        } |
        Select-Object -First 1 -ExpandProperty IPAddress

    if ($ip) { return $ip }

    return (ipconfig | Select-String -Pattern "IPv4" | ForEach-Object {
        ($_ -split ":\s*", 2)[1].Trim()
    } | Where-Object {
        $_ -and $_ -notlike "127.*" -and $_ -notlike "169.254.*"
    } | Select-Object -First 1)
}

if (-not (Test-ServerReady)) {
    $python = Find-Python
    $arguments = @()
    if ($python.Args) { $arguments += $python.Args }
    $arguments += "serve.py"

    $process = Start-Process -FilePath $python.File -ArgumentList $arguments -WorkingDirectory $Root -WindowStyle Hidden -PassThru
    Set-Content -Path $PidFile -Value $process.Id -Encoding ASCII
}

$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    if (Test-ServerReady) {
        $ready = $true
        break
    }
    Start-Sleep -Milliseconds 500
}

if (-not $ready) {
    Show-Message "The web service failed to start. Please check whether port $Port is already in use, then open logs/server.log."
    exit 1
}

$lanIp = Get-LanIp
$lanUrl = if ($lanIp) { "http://$lanIp`:$Port/" } else { $LocalUrl }

@"
LAN Share address file

Local URL:
$LocalUrl

LAN URL:
$lanUrl

Open the LAN URL on your phone or another computer connected to the same Wi-Fi/LAN.
If the page cannot be opened, allow port $Port in Windows Firewall.
"@ | Set-Content -Path $UrlFile -Encoding UTF8

Start-Process $lanUrl

Show-Message "LAN Share is running.`n`nLocal URL: $LocalUrl`nLAN URL: $lanUrl`n`nThe address file has been written to lan-share-url.txt."
