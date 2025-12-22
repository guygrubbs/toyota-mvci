[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function List-View([string]$ViewName, [string]$RegArg) {
  Write-Host "=== PassThruSupport.04.04 ($ViewName) ==="
  $base = "HKLM\SOFTWARE\PassThruSupport.04.04"
  $out = & reg.exe query $base /s /reg:$RegArg 2>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "(none found)"
    return
  }
  $out | ForEach-Object { $_ }
}

List-View -ViewName "32-bit view" -RegArg "32"
Write-Host ""
List-View -ViewName "64-bit view" -RegArg "64"

