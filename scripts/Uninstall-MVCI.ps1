[CmdletBinding()]
param(
  [string]$InstallDir = "$env:ProgramFiles(x86)\MVCI-J2534",
  [string]$DeviceKeyName = "XHorse - MVCI"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run this script in an elevated (Administrator) PowerShell."
  }
}

Assert-Admin

$k = "HKLM\SOFTWARE\PassThruSupport.04.04\$DeviceKeyName"
& reg.exe delete $k /f /reg:32 2>$null | Out-Null
& reg.exe delete $k /f /reg:64 2>$null | Out-Null

if (Test-Path $InstallDir) {
  Remove-Item $InstallDir -Recurse -Force
}

Write-Host "Removed PassThru registry keys and deleted: $InstallDir"
Write-Host "FTDI drivers were not removed."

