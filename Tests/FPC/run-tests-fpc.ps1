# Builds and runs the fpcunit tests of ideal-library with the Free Pascal compiler only (no Lazarus).
# Usage:  powershell -ExecutionPolicy Bypass -File Tests\FPC\run-tests-fpc.ps1 [-Fpc C:\FPC\3.2.2\bin\i386-win32\fpc.exe] [-OutDir <folder>]
# Build output goes to Tests\FPC\lib (ignored by git) unless -OutDir is given.
param(
  [string]$Fpc = 'C:\FPC\3.2.2\bin\i386-win32\fpc.exe',
  [string]$OutDir = (Join-Path $PSScriptRoot 'lib')
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $OutDir | Out-Null
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Push-Location $PSScriptRoot
try {
  & $Fpc -B "-FU$OutDir" "-FE$OutDir" "-Fu$root\Api" "-Fu$root\Api\Bitcoin" "-Fu$root\Tests\Shared" IdeaLLibTestsFpc.lpr
  if ($LASTEXITCODE -ne 0) { throw "Compilation failed ($LASTEXITCODE)" }
  & (Join-Path $OutDir 'IdeaLLibTestsFpc.exe') --all --format=plain
  exit $LASTEXITCODE
}
finally {
  Pop-Location
}
