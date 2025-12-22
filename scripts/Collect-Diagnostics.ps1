[CmdletBinding()]
param(
  [string]$OutDir = "$env:PUBLIC\Documents\MVCI-Diagnostics"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

"=== OS ===" | Out-File "$OutDir\os.txt"
Get-ComputerInfo | Out-File "$OutDir\os.txt" -Append

"=== PnP devices (FTDI / Serial / MVCI) ===" | Out-File "$OutDir\devices.txt"
Get-PnpDevice | Where-Object { $_.FriendlyName -match "FTDI|USB Serial|M-VCI|MVCI" } |
  Format-List * | Out-File "$OutDir\devices.txt" -Append

"=== PassThruSupport.04.04 (32-bit view) ===" | Out-File "$OutDir\passthru-reg-32.txt"
reg.exe query "HKLM\SOFTWARE\PassThruSupport.04.04" /s /reg:32 | Out-File "$OutDir\passthru-reg-32.txt" -Append

"=== PassThruSupport.04.04 (64-bit view) ===" | Out-File "$OutDir\passthru-reg-64.txt"
reg.exe query "HKLM\SOFTWARE\PassThruSupport.04.04" /s /reg:64 | Out-File "$OutDir\passthru-reg-64.txt" -Append

"=== Driver store (pnputil) ===" | Out-File "$OutDir\pnputil.txt"
pnputil /enum-drivers | Out-File "$OutDir\pnputil.txt" -Append

Write-Host "Diagnostics written to: $OutDir"

