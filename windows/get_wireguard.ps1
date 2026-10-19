<#
  get_wireguard.ps1 - downloads wireguard.dll and builds tunnel.dll
  into windows\third_party\wireguard\

  Requires: git (https://git-scm.com). build.bat downloads Go and the compiler itself.
  Run (from project root):
    powershell -ExecutionPolicy Bypass -File windows\get_wireguard.ps1
#>
param(
  [string]$WorkDir = "C:\Develop\wg-build"   # where to clone wireguard-windows
)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Dst = Join-Path $PSScriptRoot "third_party\wireguard"
New-Item -ItemType Directory -Force "$Dst\amd64", "$Dst\include" | Out-Null
New-Item -ItemType Directory -Force $WorkDir | Out-Null
function Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }

# ---------- 1. wireguard.dll (WireGuardNT) ----------
Step "Downloading WireGuardNT"
$base  = "https://download.wireguard.com/wireguard-nt/"
$links = (Invoke-WebRequest $base -UseBasicParsing).Links.href |
         Where-Object { $_ -match 'wireguard-nt-(\d+(\.\d+)+)\.zip$' } |
         ForEach-Object { Split-Path $_ -Leaf } | Select-Object -Unique
if (-not $links) { throw "No wireguard-nt zip found at $base" }
$zip = $links | Sort-Object { [version]($_ -replace '^wireguard-nt-|\.zip$','') } | Select-Object -Last 1
Write-Host "Latest: $zip"

$zipPath = Join-Path $WorkDir $zip
$unz     = Join-Path $WorkDir "wireguard-nt"
Invoke-WebRequest ($base + $zip) -OutFile $zipPath -UseBasicParsing
if (Test-Path $unz) { Remove-Item $unz -Recurse -Force }
Expand-Archive $zipPath $unz -Force

$dll = Get-ChildItem $unz -Recurse -Filter wireguard.dll | Where-Object { $_.FullName -match '\\amd64\\' } | Select-Object -First 1
$hdr = Get-ChildItem $unz -Recurse -Filter wireguard.h | Select-Object -First 1
$lic = Get-ChildItem $unz -Recurse -Include LICENSE*, COPYING* | Select-Object -First 1
if (-not $dll) { throw "No amd64\wireguard.dll inside $zip" }
Copy-Item $dll.FullName "$Dst\amd64\wireguard.dll" -Force
if ($hdr) { Copy-Item $hdr.FullName "$Dst\include\wireguard.h" -Force }
if ($lic) { Copy-Item $lic.FullName "$Dst\LICENSE-wireguard-nt.txt" -Force }
Write-Host "OK: wireguard.dll"

# ---------- 2. tunnel.dll (embeddable-dll-service) ----------
Step "Building tunnel.dll"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "git is required (https://git-scm.com)" }
$repo = Join-Path $WorkDir "wireguard-windows"
if (-not (Test-Path $repo)) {
  git clone --depth 1 https://git.zx2c4.com/wireguard-windows $repo
  if ($LASTEXITCODE) {
    Write-Host "git.zx2c4.com unavailable, trying GitHub mirror"
    git clone --depth 1 https://github.com/WireGuard/wireguard-windows $repo
    if ($LASTEXITCODE) { throw "git clone failed" }
  }
}
Push-Location (Join-Path $repo "embeddable-dll-service")
try {
  cmd /c build.bat
  if ($LASTEXITCODE) { throw "build.bat failed" }
} finally { Pop-Location }

$tun = Join-Path $repo "embeddable-dll-service\amd64\tunnel.dll"
if (-not (Test-Path $tun)) { throw "Not found: $tun" }
Copy-Item $tun "$Dst\amd64\tunnel.dll" -Force
Copy-Item (Join-Path $repo "COPYING") "$Dst\LICENSE-wireguard-windows.txt" -Force -ErrorAction SilentlyContinue
Write-Host "OK: tunnel.dll"

Step "Done"
Get-ChildItem "$Dst\amd64" | Format-Table Name, Length