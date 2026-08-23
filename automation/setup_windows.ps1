Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")
$log = Start-BismTranscript "setup_windows"
try {
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) { throw "winget is missing. Update Microsoft App Installer, then rerun this script." }

    function Install-OfficialPackage([string]$Id, [string]$Label) {
        $listed = (& $winget.Source list --id $Id -e --accept-source-agreements --disable-interactivity 2>&1 | Out-String)
        if ($LASTEXITCODE -eq 0 -and $listed -match [regex]::Escape($Id)) {
            Write-Host "$Label already installed." -ForegroundColor Green
            return
        }
        Write-Host "Installing $Label ..." -ForegroundColor Cyan
        & $winget.Source install --id $Id -e --source winget --accept-package-agreements --accept-source-agreements --silent --disable-interactivity
        if ($LASTEXITCODE -ne 0) { throw "$Label installation failed ($LASTEXITCODE)." }
    }

    Install-OfficialPackage "Git.Git" "Git"
    Install-OfficialPackage "Python.Python.3.12" "Python 3.12"
    Install-OfficialPackage "Microsoft.PowerShell" "PowerShell 7"
    Install-OfficialPackage "Microsoft.Edge" "Microsoft Edge"
    Install-OfficialPackage "Microsoft.EdgeWebView2Runtime" "Microsoft Edge WebView2 Runtime"
    Install-OfficialPackage "Microsoft.VCRedist.2015+.x64" "Microsoft Visual C++ Runtime x64"
    Install-OfficialPackage "Microsoft.PowerBI" "Microsoft Power BI Desktop"

    $python = Get-BismPython
    $prefix = @()
    if ($python.Count -gt 1) { $prefix = @($python[1..($python.Count - 1)]) }
    & $python[0] @prefix -m pip install --upgrade pip
    & $python[0] @prefix -m pip install pandas openpyxl python-docx Pillow mss pywinauto pywin32 jsonschema
    if ($LASTEXITCODE -ne 0) { throw "Python package installation failed." }
    Write-Host "Environment installation completed. No macOS restart is requested by this script." -ForegroundColor Green
} finally {
    Stop-Transcript | Out-Null
}
