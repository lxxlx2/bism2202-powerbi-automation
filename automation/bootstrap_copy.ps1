Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$source = Split-Path -Parent $PSScriptRoot
$destination = "C:\BISM2202"
New-Item -ItemType Directory -Path $destination -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $source "INPUTS") -Destination $destination -Recurse -Force
Copy-Item -LiteralPath (Join-Path $source "PROJECT") -Destination $destination -Recurse -Force
Copy-Item -LiteralPath (Join-Path $source "automation") -Destination $destination -Recurse -Force
$readme = Get-ChildItem -LiteralPath $source -Filter "README*.md" -File -ErrorAction SilentlyContinue | Select-Object -First 1
if ($readme) { Copy-Item -LiteralPath $readme.FullName -Destination (Join-Path $destination "README.md") -Force }
Write-Host "Copied BISM2202 package to $destination. Mac source files were not moved or deleted."
