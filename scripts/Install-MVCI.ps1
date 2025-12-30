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
  try {
    Expand-Archive -Path $ZipPath -DestinationPath $tmp -Force
  } catch {
    throw "Failed to extract FTDI package zip '$ZipPath'. The downloaded file may be HTML or corrupted. Inner error: $($_.Exception.Message)"
  }

  # Preferred path: find INF files and install via pnputil (reliable for automation).
  $infs = Get-ChildItem -Path $tmp -Recurse -Filter *.inf | Select-Object -ExpandProperty FullName
  if ($infs -and $infs.Count -gt 0) {
    foreach ($inf in $infs) {
      Write-Host "Installing driver INF: $inf"
      & pnputil.exe /add-driver $inf /install | Out-Host
    }
    return
  }

  # Some FTDI packages (e.g., CDM2123620_Setup.zip) contain only a setup EXE.
  # In that case, fall back to running the official FTDI installer executable.
  $setupExe = Get-ChildItem -Path $tmp -Recurse -Filter *.exe |
    Where-Object { $_.Name -match 'CDM.*Setup' -or $_.Name -match 'CDM[0-9]+' } |
    Select-Object -First 1

  if ($null -ne $setupExe) {
    Write-Host "No INF files found after extracting FTDI zip. " -NoNewline
    Write-Host "Falling back to running FTDI setup executable: $($setupExe.FullName)"
    Write-Host "This runs the official FTDI installer from FTDI's site. Press Ctrl+C now to abort if you do not accept the FTDI license."

    # Many FTDI installers support /quiet; if not, this will still launch the UI.
    Start-Process -FilePath $setupExe.FullName -ArgumentList "/quiet" -Wait
    return
  }

  throw "No INF files or setup executables found after extracting FTDI zip at '$tmp'. Check that the package is a valid FTDI driver download."
}

function Download-File([string]$Url, [string]$OutPath) {
  Write-Host "Downloading: $Url"
  try {
    $resp = Invoke-WebRequest -Uri $Url -OutFile $OutPath -UseBasicParsing -PassThru
  } catch {
    throw "Failed to download FTDI package from '$Url'. HTTP/network error: $($_.Exception.Message). " +
          "You may be behind a firewall or the URL may have changed. Download the package manually from FTDI and re-run with -FtdiPackageZipPath <path>."
  }

  # Basic sanity check that we received a ZIP (starts with 'PK').
  try {
    $fs = [System.IO.File]::OpenRead($OutPath)
    try {
      $buffer = New-Object byte[] 2
      $read = $fs.Read($buffer, 0, 2)
      if ($read -ne 2 -or $buffer[0] -ne 0x50 -or $buffer[1] -ne 0x4B) {
        throw "Downloaded file does not look like a ZIP (missing PK header). It may be an HTML error page instead of the driver package."
      }
    } finally {
      $fs.Dispose()
    }
  } catch {
    throw "Downloaded FTDI package to '$OutPath' but validation failed: $($_.Exception.Message). " +
          "Download the package manually and use -FtdiPackageZipPath <path>."
  }
}

# Main
Assert-Admin

if ($InstallFtdiDrivers) {
  if (-not $AcceptFtdiLicense) {
    throw "Refusing to install FTDI drivers without -AcceptFtdiLicense. Install via Windows Update or run again with -AcceptFtdiLicense."
  }

  $zip = $FtdiPackageZipPath
  if ([string]::IsNullOrWhiteSpace($zip)) {
      # Prefer a repo-bundled FTDI CDM package if present.
      $bundledPath = Join-Path $PSScriptRoot "..\third_party\ftdi\CDM2123620_Setup.zip"
      $resolvedBundled = Resolve-Path $bundledPath -ErrorAction SilentlyContinue
      if ($null -ne $resolvedBundled) {
        $zip = $resolvedBundled.Path
        Write-Host "Using bundled FTDI driver package: $zip"
      }
    }

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

