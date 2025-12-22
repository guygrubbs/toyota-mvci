[CmdletBinding()]
param(
  [string]$OutZip = "mvci-j2534-win-installer.zip"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$zipPath = Join-Path $root $OutZip

if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

# Create a staging dir so we exclude git internals and CI configs if desired
$stage = Join-Path $env:TEMP ("mvci_stage_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $stage | Out-Null

$include = @(
  "README.md","LICENSE","NOTICE.md",".gitignore",
  "bin","docs","scripts","third_party"
)

foreach ($item in $include) {
  Copy-Item -Path (Join-Path $root $item) -Destination (Join-Path $stage $item) -Recurse -Force
}

Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zipPath -Force
Remove-Item $stage -Recurse -Force

Write-Host "Release zip created: $zipPath"

