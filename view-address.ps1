$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Port = if ($env:LAN_SHARE_PORT) { [int]$env:LAN_SHARE_PORT } else { 8000 }
$AddressFile = Join-Path $Root "lan-share-url.txt"
$ViewFile = Join-Path $Root "address-view.html"

function Get-LanIp {
    $virtualPattern = "VMware|VirtualBox|Hyper-V|WSL|Docker|TAP|Loopback|Npcap|Bluetooth|vEthernet|Virtual"

    $primary = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPv4Address -and
            $_.IPv4DefaultGateway -and
            $_.NetAdapter.Status -eq "Up" -and
            $_.InterfaceAlias -notmatch $virtualPattern -and
            $_.InterfaceDescription -notmatch $virtualPattern
        } |
        Select-Object -First 1

    if ($primary) {
        return $primary.IPv4Address.IPAddress
    }

    $ip = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPv4Address -and
            $_.NetAdapter.Status -eq "Up" -and
            $_.InterfaceAlias -notmatch $virtualPattern -and
            $_.InterfaceDescription -notmatch $virtualPattern
        } |
        ForEach-Object { $_.IPv4Address.IPAddress } |
        Where-Object {
            $_ -and
            $_ -notlike "127.*" -and
            $_ -notlike "169.254.*"
        } |
        Select-Object -First 1

    if ($ip) { return $ip }

    return (ipconfig | Select-String -Pattern "IPv4" | ForEach-Object {
        ($_ -split ":\s*", 2)[1].Trim()
    } | Where-Object {
        $_ -and
        $_ -notlike "127.*" -and
        $_ -notlike "169.254.*" -and
        $_ -notlike "192.168.216.*" -and
        $_ -notlike "192.168.238.*"
    } | Select-Object -First 1)
}

if (-not (Test-Path $AddressFile)) {
    New-Item -ItemType File -Path $AddressFile -Force | Out-Null
}

if (-not (Test-Path $ViewFile)) {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show("address-view.html was not found. Please put it in the same folder as this launcher.", "LAN Share") | Out-Null
    exit 1
}

$content = Get-Content -Path $AddressFile -Raw -Encoding UTF8

function Get-AddressValue($Label, $DefaultValue) {
    $pattern = "(?ms)^" + [regex]::Escape($Label) + "\s*:\s*(.+?)(?:\r?\n\s*\r?\n|$)"
    $match = [regex]::Match($content, $pattern)
    if ($match.Success) {
        $value = $match.Groups[1].Value.Trim()
        if ($value) { return $value }
    }
    return $DefaultValue
}

$localUrl = Get-AddressValue "Local URL" "http://127.0.0.1:$Port/"
if ($localUrl -notmatch "^https?://") {
    $localUrl = "http://127.0.0.1:$Port/"
}

$lanUrl = Get-AddressValue "LAN URL" ""
$lanIp = Get-LanIp
if ($lanIp) {
    $lanUrl = "http://$lanIp`:$Port/"
} elseif ($lanUrl -notmatch "^https?://") {
    $lanUrl = "No LAN adapter was found. Please connect to Wi-Fi or Ethernet first."
}

@"
LAN Share address file

Local URL:
$localUrl

LAN URL:
$lanUrl

Open the LAN URL on your phone or another computer connected to the same Wi-Fi/LAN.
If the page cannot be opened, allow port $Port in Windows Firewall.
"@ | Set-Content -Path $AddressFile -Encoding UTF8

$updated = (Get-Item $AddressFile).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")

$viewUri = (New-Object System.Uri($ViewFile)).AbsoluteUri
$query = "?local=" + [uri]::EscapeDataString($localUrl) +
    "&lan=" + [uri]::EscapeDataString($lanUrl) +
    "&updated=" + [uri]::EscapeDataString($updated)

Start-Process ($viewUri + $query)
