param([Parameter(Mandatory = $true)][string]$InstallerPath)
$ErrorActionPreference = 'Stop'
# Never install or uninstall software in the user's local session for this test.
if ($env:GITHUB_ACTIONS -ne 'true' -or -not $env:RUNNER_TEMP) {
  throw 'Installer upgrade tests are restricted to disposable GitHub Actions runners.'
}
$installer = (Resolve-Path -LiteralPath $InstallerPath).Path
$testRoot = Join-Path $env:RUNNER_TEMP 'PaperPlay upgrade test'
$installRoot = Join-Path $testRoot '安装目录'
$baselineRoot = Join-Path $testRoot 'baseline'
New-Item -ItemType Directory -Path $baselineRoot -Force | Out-Null
$shortcut = Join-Path ([Environment]::GetFolderPath('Programs')) 'PaperPlay/PaperPlay.lnk'
$expectedId = 'QianYuan1437.PaperPlay'
$exe = Join-Path $installRoot 'paperplay.exe'
. (Join-Path $PSScriptRoot 'read_windows_shortcut.ps1')

function Run-Setup([string]$Path, [string[]]$Extra = @()) {
  $setupLog = Join-Path $testRoot ('setup-' + [guid]::NewGuid().ToString('N') + '.log')
  $arguments = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', "/LOG=`"$setupLog`"") + $Extra
  Write-Output "Running setup: $Path $arguments"
  $process = Start-Process -FilePath $Path -ArgumentList $arguments -WindowStyle Hidden -PassThru -Wait
  if ($process.ExitCode -ne 0) { throw "Installer failed: $($process.ExitCode)" }
}
function Read-Link([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "Missing shortcut: $Path" }
  $link = [PaperPlayShortcut]::Read($Path)
  $shell = New-Object -ComObject Shell.Application
  $item = $shell.Namespace((Split-Path $Path)).ParseName((Split-Path $Path -Leaf))
  return [pscustomobject]@{ Target=$link[0]; WorkingDir=$link[1]; Icon=$link[2]; AppId=$item.ExtendedProperty('System.AppUserModel.ID') }
}
function Assert-Link([string]$Path) {
  $link = Read-Link $Path
  if ($link.Target -ne $exe -or -not (Test-Path -LiteralPath $link.Target)) { throw "Broken target: $($link.Target)" }
  if ($link.WorkingDir -ne $installRoot) { throw 'Shortcut working directory changed' }
  if ($link.Icon -ne "$exe,0") { throw "Wrong icon: $($link.Icon)" }
  if ($link.AppId -ne $expectedId) { throw "AppUserModelID mismatch: $($link.AppId)" }
}

try {
  gh release download v1.0.2 -R QianYuan1437/PaperPlay --pattern '*windows-x64-setup.exe' --dir $baselineRoot
  if ($LASTEXITCODE -ne 0) { throw 'Could not download baseline installer' }
  $oldInstaller = (Get-ChildItem -LiteralPath $baselineRoot -Filter '*.exe').FullName
  Run-Setup $oldInstaller @("/DIR=`"$installRoot`"", '/GROUP=PaperPlay')
  $oldLink = Read-Link $shortcut
  Write-Output "Expected executable: $exe"
  Write-Output ($oldLink | ConvertTo-Json -Compress)
  if ($oldLink.Target -ne $exe) { throw "Baseline directory mismatch: expected '$exe', got '$($oldLink.Target)'" }
  Write-Output "Baseline shortcut AppUserModelID: '$($oldLink.AppId)'"
  # No /DIR: this verifies that an update reuses the original custom directory.
  Run-Setup $installer
  Assert-Link $shortcut
  $retainedLink = Join-Path $testRoot 'Retained PaperPlay.lnk'
  Copy-Item -LiteralPath $shortcut -Destination $retainedLink
  Run-Setup $installer
  Assert-Link $shortcut
  Assert-Link $retainedLink
  $registeredPath = (Get-Item 'HKCU:/Software/Microsoft/Windows/CurrentVersion/App Paths/paperplay.exe').GetValue('')
  if ($registeredPath -ne $exe) { throw 'Shell application path does not match the installed executable' }
  Add-Type -AssemblyName System.Drawing
  $icon = [Drawing.Icon]::ExtractAssociatedIcon($exe)
  if (-not $icon) { throw 'Installed executable icon cannot be extracted' }
  $icon.Dispose()
  $app = Start-Process -FilePath $exe -WorkingDirectory $env:WINDIR -WindowStyle Hidden -PassThru
  for ($attempt = 0; $attempt -lt 30; $attempt++) {
    Start-Sleep -Milliseconds 500
    $app.Refresh()
    if ($app.HasExited) { throw 'Installed application exited during startup' }
    if ($app.MainWindowHandle -ne 0 -and $app.Responding) { break }
  }
  if ($app.MainWindowHandle -eq 0 -or -not $app.Responding) { throw 'Installed application did not show a responsive window' }
  Write-Output 'PASS: legacy upgrade, retained install/shortcut paths, stable AppUserModelID and icon, repeat installation, foreign working directory launch'
} catch {
  Get-ChildItem -LiteralPath $testRoot -Filter 'setup-*.log' | ForEach-Object {
    Get-Content -LiteralPath $_.FullName | Select-String 'command line|directory|shortcut|error|exception|filename' -CaseSensitive:$false | ForEach-Object { $_.Line }
  }
  throw
} finally {
  # Only this disposable test installation may be stopped/uninstalled.
  Get-Process paperplay -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe } | Stop-Process
  $uninstaller = Join-Path $installRoot 'unins000.exe'
  if (Test-Path -LiteralPath $uninstaller) { Run-Setup $uninstaller }
}
