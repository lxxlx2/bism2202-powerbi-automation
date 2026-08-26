param(
    [ValidateSet("A", "B", "Both")]
    [string]$Version = "Both"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

Write-Host "===== TEACHER FEEDBACK RICH VISUAL POLISH =====" -ForegroundColor Cyan

$PowerBI = Get-Process PBIDesktop -ErrorAction SilentlyContinue
if ($PowerBI) {
    throw "Power BI Desktop is still running. Close it before patching PBIR source files."
}

Write-Host "Checking Python script syntax..." -ForegroundColor Cyan
py -3.12 -m py_compile .\automation\polish_teacher_feedback_visuals.py
if ($LASTEXITCODE -ne 0) {
    throw "Python syntax validation failed with exit code $LASTEXITCODE"
}
Write-Host "VISUAL_POLISH_PYTHON_SYNTAX: PASS" -ForegroundColor Green

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
Write-Host "TEACHER_FEEDBACK_RICH_VISUAL_POLISH: PASS" -ForegroundColor Green
Write-Host "Changes include labels, meaningful sorting, semantic colors, concise subtitles, corrected Q07 tied-leader styling, and Q15 share ranking." -ForegroundColor Green
Write-Host "Power BI saving/export is intentionally NOT automated." -ForegroundColor Yellow
Write-Host "Next: open A, inspect Q01/Q02/Q04/Q07/Q09/Q13/Q15/Q20, Ctrl+S and Save As final PBIX only after visual approval." -ForegroundColor Yellow
