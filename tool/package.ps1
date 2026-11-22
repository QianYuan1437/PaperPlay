param(
  [Parameter(Mandatory = $true)][string]$Version,
  [string]$BuildDirectory = 'build/windows/x64/runner/Release',
  [switch]$SkipInstaller
)
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Version must be X.Y.Z' }
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$releaseRoot = (Resolve-Path (Join-Path $projectRoot $BuildDirectory)).Path
$outputRoot = Join-Path $projectRoot 'dist'
New-Item -ItemType Directory -Force $outputRoot | Out-Null
foreach ($required in @('paperplay.exe', 'flutter_windows.dll', 'libmpv-2.dll', 'data')) {
  if (-not (Test-Path -LiteralPath (Join-Path $releaseRoot $required))) { throw "Incomplete bundle: $required" }
}
# App-local MSVC runtime makes the portable bundle usable on a clean Windows PC.
$vsWhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$vsInstall = & $vsWhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vsInstall) { throw 'Visual C++ redistributable directory not found' }
$redistRoot = Join-Path $vsInstall 'VC/Redist/MSVC'
$crtDirectory = Get-ChildItem -LiteralPath $redistRoot -Directory |
  Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
  Sort-Object { [version]$_.Name } -Descending |
  ForEach-Object { Get-ChildItem -Path (Join-Path $_.FullName 'x64/Microsoft.VC*.CRT') -Directory -ErrorAction SilentlyContinue } |
  Select-Object -First 1
if (-not $crtDirectory) { throw 'Visual C++ x64 release CRT not found' }
Copy-Item -Path (Join-Path $crtDirectory.FullName '*.dll') -Destination $releaseRoot
Copy-Item -LiteralPath (Join-Path $projectRoot 'LICENSE'), (Join-Path $projectRoot 'THIRD_PARTY_NOTICES.md'), (Join-Path $projectRoot 'README.md') -Destination $releaseRoot
$licenseRoot = Join-Path $releaseRoot 'licenses'
New-Item -ItemType Directory -Force $licenseRoot | Out-Null
Copy-Item -Path (Join-Path $projectRoot 'licenses/*') -Destination $licenseRoot
$config = Get-Content (Join-Path $projectRoot '.dart_tool/package_config.json') -Raw | ConvertFrom-Json
$configUri = [Uri]::new((Join-Path $projectRoot '.dart_tool/package_config.json'))
foreach ($package in $config.packages) {
  $packagePath = [Uri]::new($configUri, $package.rootUri).LocalPath
  $license = Join-Path $packagePath 'LICENSE'
  if (Test-Path -LiteralPath $license) { Copy-Item -LiteralPath $license -Destination (Join-Path $licenseRoot "$($package.name).txt") }
}
# Preserve the native distribution's notices alongside Dart package licenses.
foreach ($native in @('build/windows/x64/libmpv', 'build/windows/x64/ANGLE')) {
  $nativePath = Join-Path $projectRoot $native
  if (Test-Path -LiteralPath $nativePath) {
    Get-ChildItem -LiteralPath $nativePath -Recurse -File | Where-Object { $_.Name -match '^(LICENSE|COPYING|Copyright)' } | ForEach-Object {
      $name = ($_.FullName.Substring($nativePath.Length).TrimStart('\') -replace '[\\/]', '_')
      Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $licenseRoot "$((Split-Path $nativePath -Leaf))_$name")
    }
  }
}
$buildInfo = [ordered]@{ app = 'PaperPlay'; version = $Version; platform = 'windows-x64'; commit = (git -C $projectRoot rev-parse HEAD); flutter = '3.41.7'; builtAtUtc = [DateTime]::UtcNow.ToString('o') }
$buildInfo | ConvertTo-Json | Set-Content (Join-Path $outputRoot "PaperPlay-$Version-build-info.json") -Encoding utf8
Copy-Item (Join-Path $outputRoot "PaperPlay-$Version-build-info.json") $releaseRoot
$zipPath = Join-Path $outputRoot "PaperPlay-$Version-windows-x64.zip"
Compress-Archive -Path (Join-Path $releaseRoot '*') -DestinationPath $zipPath -Force
if (-not $SkipInstaller) {
  $compiler = @('C:\Program Files (x86)\Inno Setup 6\ISCC.exe', 'D:\Inno Setup 6\ISCC.exe') | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
  if (-not $compiler) { throw 'Inno Setup 6 is required to create the installer.' }
  & $compiler "/DAppVersion=$Version" "/DSourceDir=$releaseRoot" "/DOutputDir=$outputRoot" (Join-Path $projectRoot 'windows/installer.iss')
  if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed' }
}
Get-ChildItem -LiteralPath $outputRoot -File | Where-Object { $_.Name -like "PaperPlay-$Version-*" -and $_.Extension -in @('.zip', '.exe', '.json') } | ForEach-Object {
  $hash = Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256
  "$($hash.Hash.ToLower())  $($_.Name)"
} | Set-Content (Join-Path $outputRoot "PaperPlay-$Version-SHA256SUMS.txt") -Encoding ascii
Write-Output "Packages ready in $outputRoot"
