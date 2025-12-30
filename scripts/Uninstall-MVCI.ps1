[CmdletBinding()]
param(
	  # Default uninstall location matches Install-MVCI.ps1. Use ProgramFilesX86 via
	  # Environment.SpecialFolder to avoid malformed paths like "C:\Program Files (x86)(x86)".
	  [string]$InstallDir = (Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'MVCI-J2534'),
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

function Remove-Ftd2xxRuntime {
  $stateDir = Join-Path $env:ProgramData 'MVCI-J2534'
  $statePath = Join-Path $stateDir 'installer_state.json'

  if (-not (Test-Path $statePath)) {
    Write-Host "No MVCI-J2534 installer state file found; leaving any system-wide FTD2XX.dll in place."
    return
  }

  try {
    $json = Get-Content $statePath -Raw
    $state = $json | ConvertFrom-Json
  } catch {
    Write-Warning "Failed to read installer state at '$statePath'. Leaving any system-wide FTD2XX.dll in place. Error: $($_.Exception.Message)"
    return
  }

  $destWow = $null
  if ($state.PSObject.Properties.Name -contains 'SysWowFtd2xxPath') {
    $destWow = [string]$state.SysWowFtd2xxPath
  }

  $installedByInstaller = $false
  if ($state.PSObject.Properties.Name -contains 'SysWowFtd2xxInstalledByInstaller') {
    $installedByInstaller = [bool]$state.SysWowFtd2xxInstalledByInstaller
  }

  if ($installedByInstaller -and -not [string]::IsNullOrWhiteSpace($destWow) -and (Test-Path $destWow)) {
    try {
      Remove-Item $destWow -Force
      Write-Host "Removed FTD2XX runtime installed by this toolkit: $destWow"
    } catch {
      Write-Warning "Failed to remove FTD2XX.dll at '$destWow': $($_.Exception.Message)"
    }
  } else {
    Write-Host "Leaving system-wide FTD2XX.dll in place (either it pre-existed or installer state does not indicate ownership)."
  }

  # Best-effort cleanup of installer state directory.
  try {
    Remove-Item $statePath -Force
    if (Test-Path $stateDir -and -not (Get-ChildItem $stateDir -ErrorAction SilentlyContinue)) {
      Remove-Item $stateDir -Force
    }
  } catch {
    Write-Warning "Failed to fully clean up MVCI-J2534 installer state: $($_.Exception.Message)"
  }
}

Assert-Admin

$k = "HKLM\SOFTWARE\PassThruSupport.04.04\$DeviceKeyName"
& reg.exe delete $k /f /reg:32 2>$null | Out-Null
& reg.exe delete $k /f /reg:64 2>$null | Out-Null

Remove-Ftd2xxRuntime

if (Test-Path $InstallDir) {
  Remove-Item $InstallDir -Recurse -Force
}

Write-Host "Removed PassThru registry keys and deleted: $InstallDir"
Write-Host "FTDI drivers were not removed."

