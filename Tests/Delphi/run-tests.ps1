# Builds and runs the DUnitX tests of ideal-library (Win64, RAD Studio 12).
# Usage:  powershell -ExecutionPolicy Bypass -File Tests\Delphi\run-tests.ps1 [-OutDir <folder>]
# Build output (.dcu/.exe/.xml) goes to Tests\Delphi\Win64 (ignored by git) unless -OutDir is given.
param(
  [string]$OutDir = (Join-Path $PSScriptRoot 'Win64'),
  [string]$Dcc = 'dcc64'
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $OutDir | Out-Null
Push-Location $PSScriptRoot
try {
  & $Dcc -B -Q '-NSSystem;Winapi;System.Win' "-NU$OutDir" "-E$OutDir" IdeaLLibTests.dpr
  if ($LASTEXITCODE -ne 0) { throw "Compilation failed ($LASTEXITCODE)" }
  & (Join-Path $OutDir 'IdeaLLibTests.exe') "--xmlfile:$(Join-Path $OutDir 'dunitx-results.xml')" '--exitbehavior:Continue'
  exit $LASTEXITCODE
}
finally {
  Pop-Location
}
