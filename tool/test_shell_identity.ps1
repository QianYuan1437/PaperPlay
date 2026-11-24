$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$vsWhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$installation = & $vsWhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
$vsVersion = & $vsWhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationVersion
$major = ([version]$vsVersion).Major
$generator = if ($major -ge 18) { 'Visual Studio 18 2026' } else { 'Visual Studio 17 2022' }
$cmakePath = Join-Path $installation 'Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe'
if (-not (Test-Path -LiteralPath $cmakePath)) { $cmakePath = (Get-Command cmake -ErrorAction Stop).Source }
$outputDirectory = Join-Path $projectRoot "build/shell_identity_tests/vs-$major"
& $cmakePath -S (Join-Path $projectRoot 'windows/tests') -B $outputDirectory -G $generator -A x64
if ($LASTEXITCODE -ne 0) { throw 'Shell test configuration failed' }
& $cmakePath --build $outputDirectory --config Release
if ($LASTEXITCODE -ne 0) { throw 'Shell test compilation failed' }
& (Join-Path $outputDirectory 'Release/PaperPlay shell test.exe')
if ($LASTEXITCODE -ne 0) { throw 'Shell identity regression failed' }
