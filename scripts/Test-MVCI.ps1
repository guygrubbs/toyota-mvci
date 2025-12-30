[CmdletBinding()]
param(
	# Optional override for where mvci32.dll is installed. If not provided,
	# the path is read from the 32-bit PassThruSupport.04.04 registry entry.
	[string]$InstallDir,

	# Optional override for the DLL filename. If not provided, it is taken
	# from the FunctionLibrary registry value.
	[string]$DllName,

	# J2534 device registry key name to probe.
	[string]$DeviceKeyName = "XHorse - MVCI"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# mvci32.dll is a 32-bit library. If we're currently in a 64-bit PowerShell host,
# transparently re-launch this script in the 32-bit Windows PowerShell (x86)
# so the DLL can be loaded, instead of forcing the user to select the right host.
if ([IntPtr]::Size -ne 4) {
	$sysWowPs = Join-Path $env:WINDIR "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
	if (-not (Test-Path $sysWowPs)) {
		throw "Test-MVCI.ps1 must load 32-bit mvci32.dll, but a 32-bit Windows PowerShell host was not found at '$sysWowPs'. Run this script from a 32-bit PowerShell (e.g. 'Windows PowerShell (x86)')."
	}
	if (-not $PSCommandPath) {
		throw "Test-MVCI.ps1 auto-relaunch only works when invoked as a script file (e.g. '.\\Test-MVCI.ps1')."
	}

	$argList = @(
		"-NoProfile"
		"-ExecutionPolicy"
		"Bypass"
		"-File"
		$PSCommandPath
	)

	if ($PSBoundParameters.ContainsKey("InstallDir")) {
		$argList += @("-InstallDir", $InstallDir)
	}
	if ($PSBoundParameters.ContainsKey("DllName")) {
		$argList += @("-DllName", $DllName)
	}
	if ($PSBoundParameters.ContainsKey("DeviceKeyName")) {
		$argList += @("-DeviceKeyName", $DeviceKeyName)
	}

	Write-Host "64-bit PowerShell detected; relaunching Test-MVCI.ps1 in 32-bit Windows PowerShell..."
	& $sysWowPs @argList
	$exitCode = $LASTEXITCODE
	exit $exitCode
}

if (-not $InstallDir -or -not $DllName) {
  $regPath = "HKLM:\SOFTWARE\PassThruSupport.04.04\$DeviceKeyName"
  try {
    $funcLib = (Get-ItemProperty -Path $regPath -Name FunctionLibrary -ErrorAction Stop).FunctionLibrary
  } catch {
    throw "FunctionLibrary not found at '$regPath'. Run Install-MVCI.ps1 first."
  }

  if (-not $funcLib) {
    throw "FunctionLibrary value at '$regPath' is empty. Run Install-MVCI.ps1 first."
  }

  if (-not $InstallDir) {
    $InstallDir = Split-Path -Path $funcLib -Parent
  }
  if (-not $DllName) {
    $DllName = Split-Path -Path $funcLib -Leaf
  }
}

$dllPath = Join-Path $InstallDir $DllName
if (-not (Test-Path $dllPath)) { throw "DLL not found: $dllPath. Run Install-MVCI.ps1 first." }

# Ensure loader can find the DLL by adding install dir to PATH for this process.
$oldPath = $env:PATH
$env:PATH = "$InstallDir;$env:PATH"

$cs = @"
using System;
using System.Runtime.InteropServices;

public static class J2534 {
  [DllImport("mvci32.dll", CallingConvention=CallingConvention.StdCall)]
  public static extern Int32 PassThruOpen(IntPtr pName, ref UInt32 pDeviceID);

  [DllImport("mvci32.dll", CallingConvention=CallingConvention.StdCall)]
  public static extern Int32 PassThruClose(UInt32 deviceID);
}
"@

try {
  Add-Type -TypeDefinition $cs -ErrorAction Stop
  [UInt32]$dev = 0
  $rc = [J2534]::PassThruOpen([IntPtr]::Zero, [ref]$dev)
  Write-Host "PassThruOpen rc=$rc deviceId=$dev"
  if ($rc -eq 0 -and $dev -ne 0) {
    $rc2 = [J2534]::PassThruClose($dev)
    Write-Host "PassThruClose rc=$rc2"
  }
  if ($rc -ne 0) {
    Write-Host "Non-zero return code usually indicates driver/device/D2XX issues."
  }
}
finally {
  $env:PATH = $oldPath
}

