param(
    [ValidateSet("A", "B", "Both")]
    [string]$Version = "Both"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

Write-Host "===== TEACHER FEEDBACK VISUAL POLISH =====" -ForegroundColor Cyan

$PowerBI = Get-Process PBIDesktop -ErrorAction SilentlyContinue
if ($PowerBI) {
    throw "Power BI Desktop is still running. Close it before patching PBIR source files."
}

py -3.12 .\automation\polish_teacher_feedback_visuals.py --version $Version
if ($LASTEXITCODE -ne 0) {
    throw "polish_teacher_feedback_visuals.py failed with exit code $LASTEXITCODE"
}

$Versions = if ($Version -eq "Both") { @("A", "B") } else { @($Version) }

foreach ($V in $Versions) {
    $Report = if ($V -eq "A") {
        Join-Path $RepoRoot "PROJECT\Version_A_PowerBI\BISM2202_Seed.Report"
    } else {
        Join-Path $RepoRoot "PROJECT\Version_B_PowerBI\BISM2202_Seed.Report"
    }

    Write-Host "Validating Version $V PBIR..." -ForegroundColor Cyan
    pbi report -p $Report validate
    if ($LASTEXITCODE -ne 0) {
        throw "Version $V PBIR validation failed with exit code $LASTEXITCODE"
    }
    Write-Host "VERSION_${V}_POLISH_PBIR_VALIDATION: PASS" -ForegroundColor Green
}

Write-Host "" 
Write-Host "TEACHER_FEEDBACK_VISUAL_POLISH: PASS" -ForegroundColor Green
Write-Host "Power BI saving is intentionally NOT automated." -ForegroundColor Yellow
Write-Host "Next: open each PBIP, visually inspect, Ctrl+S, Save As/replace its final PBIX, keep Power BI open, then run CaptureA/CaptureB." -ForegroundColor Yellow
