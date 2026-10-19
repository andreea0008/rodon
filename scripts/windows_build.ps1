<#
  windows_build.ps1 — збірка RodON для Windows (x64) і інсталятора RodON-Setup.exe

  Потрібно встановити:
    - Visual Studio 2022 (workload "Desktop development with C++")
    - Qt 6.11.2, компонент MSVC 2022 64-bit
    - CMake (йде з Qt або з VS)
    - vcpkg + libsodium:  vcpkg install libsodium:x64-windows
    - Inno Setup 6 (для інсталятора)

  Запуск (PowerShell, з кореня проєкту):
    powershell -ExecutionPolicy Bypass -File windows\windows_build.ps1
#>
param(
  [string]$QtDir     = "C:\Qt\6.11.2\msvc2022_64",
  [string]$VcpkgRoot = "D:\develop\extrachain\vcpkg",
  [string]$InnoSetup = "C:\Program Files\Inno Setup 7\ISCC.exe",
  [switch]$NoInstaller
)
$ErrorActionPreference = "Stop"

$ProjectDir = Resolve-Path "$PSScriptRoot\.."
$BuildDir   = Join-Path $ProjectDir "build\windows-release"
$StageDir   = Join-Path $ProjectDir "build\windows-stage"
$Exe        = Join-Path $BuildDir "Release\RodON.exe"

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

# ---------- 0. Перевірки ----------
Step "Checking prerequisites"
foreach ($p in @("$QtDir\bin\windeployqt.exe", "$VcpkgRoot\scripts\buildsystems\vcpkg.cmake")) {
  if (-not (Test-Path $p)) { throw "Не знайдено: $p" }
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
if (-not (Test-Path $Exe)) { throw "Не знайдено $Exe" }

# ---------- 3. Staging + windeployqt ----------
Step "Deploying Qt (windeployqt)"
if (Test-Path $StageDir) { Remove-Item $StageDir -Recurse -Force }
New-Item -ItemType Directory $StageDir | Out-Null
Copy-Item $Exe $StageDir

& "$QtDir\bin\windeployqt.exe" `
  --release `
  --qmldir (Join-Path $ProjectDir "qml") `
  --compiler-runtime `
  --no-translations `
  (Join-Path $StageDir "RodON.exe")
if ($LASTEXITCODE) { throw "windeployqt failed" }

# libsodium та інші DLL з vcpkg (якщо vcpkg не поклав їх поруч з exe)
Get-ChildItem (Join-Path $BuildDir "Release") -Filter *.dll -ErrorAction SilentlyContinue |
  ForEach-Object { Copy-Item $_.FullName $StageDir -Force }
if (-not (Test-Path (Join-Path $StageDir "libsodium.dll"))) {
  Copy-Item "$VcpkgRoot\installed\x64-windows\bin\libsodium.dll" $StageDir
}

# ---------- 4. Швидка перевірка ----------
Step "Smoke check"
$missing = @("Qt6Core.dll","Qt6Quick.dll","libsodium.dll") |
  Where-Object { -not (Test-Path (Join-Path $StageDir $_)) }
if ($missing) { throw "У staging бракує: $($missing -join ', ')" }
Write-Host "OK: $StageDir"

# ---------- 5. Інсталятор ----------
if (-not $NoInstaller) {
  Step "Building installer (Inno Setup)"
  if (-not (Test-Path $InnoSetup)) { throw "Не знайдено Inno Setup: $InnoSetup (або запусти з -NoInstaller)" }
  & $InnoSetup "/DStageDir=$StageDir" "/DOutDir=$ProjectDir" (Join-Path $PSScriptRoot "rodon.iss")
  if ($LASTEXITCODE) { throw "Inno Setup failed" }
  Write-Host "`nГотово: $ProjectDir\RodON-Setup.exe" -ForegroundColor Green
} else {
  Write-Host "`nГотово (без інсталятора): $StageDir\RodON.exe" -ForegroundColor Green
}
