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

Write-Host "Checking Python scripts..." -ForegroundColor Cyan
$Scripts = @(
    ".\automation\polish_teacher_feedback_visuals.py",
    ".\automation\fix_remaining_visual_issues.py",
    ".\automation\upgrade_mini_dashboards.py",
    ".\automation\fix_dashboard_capture_layout.py"
)
foreach ($Script in $Scripts) {
    py -3.12 -m py_compile $Script
    if ($LASTEXITCODE -ne 0) {
        throw "$Script syntax validation failed with exit code $LASTEXITCODE"
    }
}
Write-Host "VISUAL_POLISH_PYTHON_SYNTAX: PASS" -ForegroundColor Green

py -3.12 .\automation\polish_teacher_feedback_visuals.py --version $Version
if ($LASTEXITCODE -ne 0) {
    throw "polish_teacher_feedback_visuals.py failed with exit code $LASTEXITCODE"
}

py -3.12 .\automation\fix_remaining_visual_issues.py --version $Version
if ($LASTEXITCODE -ne 0) {
    throw "fix_remaining_visual_issues.py failed with exit code $LASTEXITCODE"
}

py -3.12 .\automation\upgrade_mini_dashboards.py --version $Version
if ($LASTEXITCODE -ne 0) {
    throw "upgrade_mini_dashboards.py failed with exit code $LASTEXITCODE"
}

# Live-review correction: remove duplicate clipped KPI measure labels and restore
# enough vertical space for dense charts to render completely without an internal
# scrollbar while keeping the full page screenshot-friendly via FitToPage.
py -3.12 .\automation\fix_dashboard_capture_layout.py --version $Version
if ($LASTEXITCODE -ne 0) {
    throw "fix_dashboard_capture_layout.py failed with exit code $LASTEXITCODE"
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
Write-Host "Q07 tie-safe title/subtitle: PASS" -ForegroundColor Green
Write-Host "Q15 deterministic complexity ordering: PASS" -ForegroundColor Green
Write-Host "Q01/Q04/Q07/Q09/Q13/Q15 MINI_DASHBOARDS: PASS" -ForegroundColor Green
Write-Host "KPI duplicate labels hidden: PASS" -ForegroundColor Green
Write-Host "Dashboard capture layout: PASS" -ForegroundColor Green
Write-Host "Power BI saving/export is intentionally NOT automated." -ForegroundColor Yellow
Write-Host "Next: open A and inspect Q01/Q04/Q07/Q09/Q13/Q15/Q20, then Ctrl+S and Save As final PBIX only after visual approval." -ForegroundColor Yellow
