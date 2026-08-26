param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("A", "B")]
    [string]$Version
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

Write-Host "===== CLEAN POWER BI CAPTURE: VERSION $Version =====" -ForegroundColor Cyan

$PowerBI = Get-Process PBIDesktop -ErrorAction SilentlyContinue
if (-not $PowerBI) {
    throw "Power BI Desktop is not running. Open the correct saved Version $Version report first."
}

$Start = Get-Date

pwsh -ExecutionPolicy Bypass `
  -File .\automation\capture_pages_robust.ps1 `
  -Version $Version `
  -DelaySeconds 1.8

if ($LASTEXITCODE -ne 0) {
    throw "Robust 20-page capture failed with exit code $LASTEXITCODE"
}

$ShotDir = Join-Path $RepoRoot "PROJECT\BISM2202_OUTPUT\Version_$Version\screenshots"
$Shots = @(Get-ChildItem $ShotDir -Filter "Q??.png" -File | Sort-Object Name)
if ($Shots.Count -ne 20) {
    throw "Version $Version expected 20 screenshots, found $($Shots.Count)"
}

$Stale = @($Shots | Where-Object { $_.LastWriteTime -lt $Start })
if ($Stale.Count -gt 0) {
    throw "Version $Version has stale screenshots: $($Stale.Name -join ', ')"
}

$Tiny = @($Shots | Where-Object { $_.Length -lt 5000 })
if ($Tiny.Count -gt 0) {
    throw "Version $Version has suspiciously small screenshots: $($Tiny.Name -join ', ')"
}

Write-Host "VERSION_${Version}_SCREENSHOTS: 20 FRESH PASS" -ForegroundColor Green
Write-Host "VERSION_${Version}_HOVER_SAFE_CAPTURE: PASS" -ForegroundColor Green
Write-Host "VERSION_${Version}_TRANSACTIONAL_CAPTURE: PASS" -ForegroundColor Green
Write-Host "Next: close Power BI after capture. When both A and B are captured, run teacher_feedback_workflow.ps1 -Stage Finalize." -ForegroundColor Yellow
