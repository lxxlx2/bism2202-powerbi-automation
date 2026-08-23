param([ValidateSet("A", "B", "Both")][string]$Version = "Both")
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")
$log = Start-BismTranscript "run_all"
try {
    & (Join-Path $PSScriptRoot "environment_check.ps1")
    & (Join-Path $PSScriptRoot "setup_windows.ps1")
    & (Join-Path $PSScriptRoot "environment_check.ps1")
    Invoke-BismPython -Arguments @((Join-Path $PSScriptRoot "build_powerbi_project.py"), "--version", $Version)
    Write-Host "Preparation is complete." -ForegroundColor Green
    Write-Host "The script does not fabricate a PBIX. Once Q01-Q20 exist in genuine Power BI Desktop, run capture_pages.py, validate_powerbi.py, and finalize_reports.py."
} finally {
    Stop-Transcript | Out-Null
}
