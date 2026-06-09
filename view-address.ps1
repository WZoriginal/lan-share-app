$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$AddressFile = Join-Path $Root "lan-share-url.txt"
$ViewFile = Join-Path $Root "address-view.html"

if (-not (Test-Path $AddressFile)) {
    @"
LAN Share address file

Local URL:
http://127.0.0.1:8000/

LAN URL:
Run the startup script first. The real LAN URL will be written here automatically.
"@ | Set-Content -Path $AddressFile -Encoding UTF8
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

$localUrl = Get-AddressValue "Local URL" "http://127.0.0.1:8000/"
$lanUrl = Get-AddressValue "LAN URL" "Run the startup script first."
$updated = (Get-Item $AddressFile).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")

$viewUri = (New-Object System.Uri($ViewFile)).AbsoluteUri
$query = "?local=" + [uri]::EscapeDataString($localUrl) +
    "&lan=" + [uri]::EscapeDataString($lanUrl) +
    "&updated=" + [uri]::EscapeDataString($updated)

Start-Process ($viewUri + $query)
