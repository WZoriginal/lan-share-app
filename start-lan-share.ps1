$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Port = if ($env:LAN_SHARE_PORT) { [int]$env:LAN_SHARE_PORT } else { 8000 }
$LocalUrl = "http://127.0.0.1:$Port/"
$PidFile = Join-Path $Root ".lan-share.pid"
$UrlFile = Join-Path $Root "lan-share-url.txt"

Set-Location $Root

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

    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show("未找到 Python。请先安装 Python 3，或把 python.exe 加入 PATH。", "LAN Share") | Out-Null
    exit 1
}

function Test-ServerReady {
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri "$LocalUrlapi/files" -TimeoutSec 1
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
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show("服务启动失败。请检查端口 $Port 是否被占用，或查看 logs/server.log。", "LAN Share") | Out-Null
    exit 1
}

$lanIp = Get-LanIp
$lanUrl = if ($lanIp) { "http://$lanIp`:$Port/" } else { $LocalUrl }

@"
本机访问地址：$LocalUrl
局域网访问地址：$lanUrl

请让手机或其他电脑连接同一个 Wi-Fi/局域网后打开局域网访问地址。
"@ | Set-Content -Path $UrlFile -Encoding UTF8

Start-Process $lanUrl

Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show("局域网共享中心已启动。`n`n本机：$LocalUrl`n局域网：$lanUrl`n`n地址已写入 lan-share-url.txt。", "LAN Share") | Out-Null
