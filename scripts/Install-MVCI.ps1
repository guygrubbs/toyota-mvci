[CmdletBinding()]
param(
  # Where mvci32.dll will be installed (do not use ProgramFiles for 32-bit apps)
  [string]$InstallDir = "$env:ProgramFiles(x86)\MVCI-J2534",

  # Optional: automatically install FTDI drivers from the official FTDI package.
  # Set -AcceptFtdiLicense to enable.
  [switch]$InstallFtdiDrivers,
  [switch]$AcceptFtdiLicense,

  # Official FTDI driver package URL (example current link from ftdichip.com drivers page).
  # You may update this value if FTDI changes the filename.
  [string]$FtdiPackageUrl = "https://ftdichip.com/wp-content/uploads/2025/03/CDM2123620_Setup.zip",

  # If you already downloaded the FTDI zip locally, pass this instead of using the URL.
  [string]$FtdiPackageZipPath = "",

  # Registry device name (displayed to J2534 apps)
  [string]$DeviceKeyName = "XHorse - MVCI",

  # Default matches MVCI-J2534 behavior
  [string]$UsbDescription = "M-VCI",

  # Recommended by MVCI-J2534 for Windows
  [int]$UseD2XX = 1
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

function Ensure-FileExists([string]$Path, [string]$Message) {
  if (-not (Test-Path $Path)) { throw $Message }
}

function Get-BaseKey([Microsoft.Win32.RegistryView]$View) {
  return [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $View)
}

function Set-PassThruRegistry([Microsoft.Win32.RegistryView]$View, [string]$Name, [string]$DllPath, [string]$UsbDesc, [int]$UseD2XXFlag) {
  $base = Get-BaseKey $View
  $keyPath = "SOFTWARE\PassThruSupport.04.04\$Name"

  $k = $base.CreateSubKey($keyPath)

  # Common J2534 discovery fields used by many applications.
  # Registry structure and FunctionLibrary are part of typical J2534 discovery patterns.
  $k.SetValue("Name", $Name, "String")
  $k.SetValue("Vendor", "XHorse", "String")
  $k.SetValue("FunctionLibrary", $DllPath, "String")
  $k.SetValue("APIVersion", "04.04", "String")

  # Protocol flags (safe to advertise these as supported; apps may ignore unsupported ones at runtime).
  foreach ($p in @("CAN","ISO15765","ISO9141","ISO14230","J1850PWM","J1850VPW")) {
    $k.SetValue($p, 1, "DWord")
  }

  # MVCI-J2534 Parameters per its documentation
  $param = $base.CreateSubKey("$keyPath\Parameters")
  $param.SetValue("USBDescription", $UsbDesc, "String")
  $param.SetValue("UseD2XX", $UseD2XXFlag, "DWord")

  $param.Close()
  $k.Close()
  $base.Close()
}

function Install-MvciDll([string]$DestDir) {
  $src = Resolve-Path (Join-Path $PSScriptRoot "..\bin\mvci32.dll") -ErrorAction Stop
  Ensure-FileExists $src.Path "Missing bin\mvci32.dll. Build it via CI or locally, then re-run."

  New-Item -ItemType Directory -Force -Path $DestDir | Out-Null
  $dst = Join-Path $DestDir "mvci32.dll"
  Copy-Item $src.Path $dst -Force
  return $dst
}

function Install-FtdiDrivers-FromZip([string]$ZipPath) {
  Ensure-FileExists $ZipPath "FTDI package not found: $ZipPath"

  $tmp = Join-Path $env:TEMP ("ftdi_" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  Expand-Archive -Path $ZipPath -DestinationPath $tmp -Force

  # Find INF files and install via pnputil (reliable for automation).
  $infs = Get-ChildItem -Path $tmp -Recurse -Filter *.inf | Select-Object -ExpandProperty FullName
  if (-not $infs -or $infs.Count -eq 0) {
    throw "No INF files found after extracting FTDI zip."
  }

  foreach ($inf in $infs) {
    Write-Host "Installing driver INF: $inf"
    & pnputil.exe /add-driver $inf /install | Out-Host
  }
}

function Download-File([string]$Url, [string]$OutPath) {
  Write-Host "Downloading: $Url"
  Invoke-WebRequest -Uri $Url -OutFile $OutPath
}

# Main
Assert-Admin

if ($InstallFtdiDrivers) {
  if (-not $AcceptFtdiLicense) {
    throw "Refusing to install FTDI drivers without -AcceptFtdiLicense. Install via Windows Update or run again with -AcceptFtdiLicense."
  }

  $zip = $FtdiPackageZipPath
  if ([string]::IsNullOrWhiteSpace($zip)) {
    $zip = Join-Path $env:TEMP ("ftdi_cdm_" + [guid]::NewGuid().ToString("N") + ".zip")
    Download-File -Url $FtdiPackageUrl -OutPath $zip
  }
  Install-FtdiDrivers-FromZip -ZipPath $zip
  Write-Host "FTDI driver install attempted. (Windows Update may also install silently when online.)"
}

$dllPath = Install-MvciDll -DestDir $InstallDir

# Register both 32-bit and 64-bit registry views.
# Many J2534 apps (Techstream commonly) are 32-bit; registering Registry32 is important.
Set-PassThruRegistry -View ([Microsoft.Win32.RegistryView]::Registry32) -Name $DeviceKeyName -DllPath $dllPath -UsbDesc $UsbDescription -UseD2XXFlag $UseD2XX
Set-PassThruRegistry -View ([Microsoft.Win32.RegistryView]::Registry64) -Name $DeviceKeyName -DllPath $dllPath -UsbDesc $UsbDescription -UseD2XXFlag $UseD2XX

Write-Host ""
Write-Host "Installed mvci32.dll to: $dllPath"
Write-Host "Registered PassThruSupport.04.04 entries for: $DeviceKeyName"
Write-Host "Next: run scripts\Test-MVCI.ps1 and scripts\List-PassThru.ps1"

