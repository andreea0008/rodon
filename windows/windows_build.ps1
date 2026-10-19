<#
  windows_build.ps1 - builds RodON for Windows (x64) and the RodON-Setup.exe installer

  Requirements:
    - Visual Studio 2022 (workload "Desktop development with C++")
    - Qt 6.12.0, component MSVC 2022 64-bit
    - CMake (ships with Qt or VS)
    - vcpkg + libsodium:  vcpkg install libsodium:x64-windows
    - Inno Setup 6 (for the installer)
    - windows\third_party\wireguard\amd64\tunnel.dll and wireguard.dll
      windows\third_party\wireguard\include\wireguard.h  (see README there; or run windows\get_wireguard.ps1)

  Run (from project root):
    powershell -ExecutionPolicy Bypass -File windows\windows_build.ps1
#>
param(
  [string]$QtDir     = "C:\Qt\6.12.0\msvc2022_64",
  [string]$VcpkgRoot = "D:\develop\extrachain\vcpkg",
  [string]$InnoSetup = "C:\Program Files\Inno Setup 7\ISCC.exe",
  [switch]$NoInstaller
)
$ErrorActionPreference = "Stop"

$ProjectDir = Resolve-Path "$PSScriptRoot\.."
$BuildDir   = Join-Path $ProjectDir "build\windows-release"
$StageDir   = Join-Path $ProjectDir "build\windows-stage"
$Exe        = Join-Path $BuildDir "Release\RodON.exe"
$SvcExe     = Join-Path $BuildDir "Release\RodONService.exe"
$WgDir      = Join-Path $ProjectDir "windows\third_party\wireguard"

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

# ---------- 0. Prerequisites ----------
Step "Checking prerequisites"
foreach ($p in @("$QtDir\bin\windeployqt.exe", "$VcpkgRoot\scripts\buildsystems\vcpkg.cmake",
                 "$WgDir\amd64\tunnel.dll", "$WgDir\amd64\wireguard.dll", "$WgDir\include\wireguard.h")) {
  if (-not (Test-Path $p)) { throw "Not found: $p" }
}

# ---------- 1. Configure ----------
Step "CMake configure"
cmake -S $ProjectDir -B $BuildDir `
  -G "Visual Studio 17 2022" -A x64 `
  -DCMAKE_PREFIX_PATH="$QtDir" `
  -DCMAKE_TOOLCHAIN_FILE="$VcpkgRoot\scripts\buildsystems\vcpkg.cmake" `
  -DVCPKG_TARGET_TRIPLET=x64-windows
if ($LASTEXITCODE) { throw "CMake configure failed" }

# ---------- 2. Build ----------
Step "Build Release"
cmake --build $BuildDir --config Release --parallel
if ($LASTEXITCODE) { throw "Build failed" }
if (-not (Test-Path $Exe))    { throw "Not found: $Exe" }
if (-not (Test-Path $SvcExe)) { throw "Not found: $SvcExe" }

# ---------- 3. Staging + windeployqt ----------
Step "Deploying Qt (windeployqt)"
if (Test-Path $StageDir) { Remove-Item $StageDir -Recurse -Force }
New-Item -ItemType Directory $StageDir | Out-Null
Copy-Item $Exe $StageDir
# VPN service + WireGuard (tunnel.dll looks for wireguard.dll next to the exe)
Copy-Item $SvcExe $StageDir
Copy-Item "$WgDir\amd64\tunnel.dll"   $StageDir
Copy-Item "$WgDir\amd64\wireguard.dll" $StageDir
if (Test-Path "$WgDir\LICENSE-wireguard-nt.txt") { Copy-Item "$WgDir\LICENSE-*.txt" $StageDir }
# WinSparkle (auto-updates)
$WsDll = Join-Path $ProjectDir "windows\third_party\winsparkle\x64\WinSparkle.dll"
if (Test-Path $WsDll) { Copy-Item $WsDll $StageDir } else { Write-Warning "WinSparkle.dll not found - no auto-updates" }

& "$QtDir\bin\windeployqt.exe" `
  --release `
  --qmldir (Join-Path $ProjectDir "qml") `
  --compiler-runtime `
  --no-translations `
  (Join-Path $StageDir "RodON.exe")
if ($LASTEXITCODE) { throw "windeployqt failed" }

# libsodium and other vcpkg DLLs (if vcpkg did not put them next to the exe)
Get-ChildItem (Join-Path $BuildDir "Release") -Filter *.dll -ErrorAction SilentlyContinue |
  ForEach-Object { Copy-Item $_.FullName $StageDir -Force }
if (-not (Test-Path (Join-Path $StageDir "libsodium.dll"))) {
  Copy-Item "$VcpkgRoot\installed\x64-windows\bin\libsodium.dll" $StageDir
}

# ---------- 4. Smoke check ----------
Step "Smoke check"
$missing = @("Qt6Core.dll","Qt6Quick.dll","Qt6Network.dll","libsodium.dll",
             "RodONService.exe","tunnel.dll","wireguard.dll") |
  Where-Object { -not (Test-Path (Join-Path $StageDir $_)) }
if ($missing) { throw "Missing in staging: $($missing -join ', ')" }
Write-Host "OK: $StageDir"

# ---------- 5. Installer ----------
if (-not $NoInstaller) {
  Step "Building installer (Inno Setup)"
  if (-not (Test-Path $InnoSetup)) { throw "Inno Setup not found: $InnoSetup (or run with -NoInstaller)" }
  & $InnoSetup "/DStageDir=$StageDir" "/DOutDir=$ProjectDir" (Join-Path $PSScriptRoot "rodon.iss")
  if ($LASTEXITCODE) { throw "Inno Setup failed" }
  $Setup = Get-ChildItem $ProjectDir -Filter "RodON-Setup-*.exe" | Sort-Object LastWriteTime | Select-Object -Last 1
  Write-Host "`nDone: $($Setup.FullName)" -ForegroundColor Green
  Write-Host "Publish update (on Mac): ./release_update_win.sh $($Setup.Name)" -ForegroundColor Green
} else {
  Write-Host "`nDone (no installer): $StageDir\RodON.exe" -ForegroundColor Green
}
