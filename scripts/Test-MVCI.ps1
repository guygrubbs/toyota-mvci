[CmdletBinding()]
param(
  [string]$InstallDir = "$env:ProgramFiles(x86)\MVCI-J2534",
  [string]$DllName = "mvci32.dll"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

