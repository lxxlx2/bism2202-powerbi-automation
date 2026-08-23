param(
    [ValidateSet("A", "B")][string]$Version,
    [string]$ProjectRoot = "C:\BISM2202",
    [switch]$ForceClosePowerBI,
    [switch]$OpenProject,
    [int]$WaitSeconds = 14
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$PowerBIExe = "C:\Program Files\Microsoft Power BI Desktop\bin\PBIDesktop.exe"
$ProjectDir = Join-Path $ProjectRoot "PROJECT\Version_${Version}_PowerBI"
$Pbip = Join-Path $ProjectDir "BISM2202_Seed.pbip"
$ReportDefinition = Join-Path $ProjectDir "BISM2202_Seed.Report\definition"
$CaptureScript = Join-Path $ProjectRoot "automation\capture_pages.py"
$OutputRoot = Join-Path $ProjectRoot "PROJECT\BISM2202_OUTPUT\Version_${Version}"
$Screenshots = Join-Path $OutputRoot "screenshots"
$ReviewFull = Join-Path $OutputRoot "review_full"

function Assert-Path([string]$Path, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "$Label not found: $Path" }
}

Assert-Path $ProjectRoot "Project root"
Assert-Path $Pbip "Version $Version PBIP"
Assert-Path $ReportDefinition "Version $Version PBIR definition"
Assert-Path $CaptureScript "Capture script"
Assert-Path $PowerBIExe "Power BI Desktop"

Set-Location $ProjectRoot

$running = Get-Process PBIDesktop -ErrorAction SilentlyContinue
if ($ForceClosePowerBI -and $running) {
    Write-Host "Closing existing Power BI Desktop windows..." -ForegroundColor Yellow
    $running | Stop-Process -Force
    Start-Sleep -Seconds 3
    $running = $null
}

if ($OpenProject -or -not $running) {
    Write-Host "Opening Version $Version for screenshot capture..." -ForegroundColor Cyan
    Start-Process -FilePath $PowerBIExe -ArgumentList ('"' + $Pbip + '"')
    Start-Sleep -Seconds $WaitSeconds
}

Write-Host "Ensuring screenshot dependencies are installed..." -ForegroundColor Cyan
py -3.12 -c "import mss, pywinauto" 2>$null
if ($LASTEXITCODE -ne 0) {
    py -3.12 -m pip install --upgrade mss pywinauto
    if ($LASTEXITCODE -ne 0) { throw "Failed to install screenshot dependencies." }
}

Write-Host "Capturing Q01-Q20 in both canvas-only and full-review forms..." -ForegroundColor Cyan
py -3.12 $CaptureScript --version $Version --keyboard-fallback
if ($LASTEXITCODE -ne 0) { throw "capture_pages.py failed." }

Assert-Path $Screenshots "Canvas screenshots"
Assert-Path $ReviewFull "Full review screenshots"

$canvasCount = @(Get-ChildItem -LiteralPath $Screenshots -Filter "Q??.png" -File).Count
$fullCount = @(Get-ChildItem -LiteralPath $ReviewFull -Filter "Q??_full.png" -File).Count
if ($canvasCount -ne 20 -or $fullCount -ne 20) {
    throw "Expected 20 canvas + 20 full screenshots; found canvas=$canvasCount full=$fullCount"
}

$reviewStatus = Join-Path $OutputRoot "AUTOMATED_REVIEW_CAPTURE.md"
@"
# Automated Review Capture

- Version: $Version
- Captured: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz")
- Canvas screenshots: 20
- Full-window QA screenshots: 20
- PBIR source included in Git review commit: yes

`review_full/` is for QA only and can contain localized Power BI UI text.
`screenshots/` contains cropped report-canvas images intended for final report use after QA approval.
"@ | Set-Content -LiteralPath $reviewStatus -Encoding UTF8

Write-Host "Publishing screenshots and PBIR source to GitHub for AI review..." -ForegroundColor Cyan
$paths = @(
    "PROJECT/BISM2202_OUTPUT/Version_${Version}/screenshots",
    "PROJECT/BISM2202_OUTPUT/Version_${Version}/review_full",
    "PROJECT/BISM2202_OUTPUT/Version_${Version}/AUTOMATED_REVIEW_CAPTURE.md",
    "PROJECT/Version_${Version}_PowerBI/BISM2202_Seed.Report/definition",
    "PROJECT/Version_${Version}_PowerBI/BISM2202_Seed.pbip"
)
foreach ($path in $paths) { git add -- $path }

$changes = git diff --cached --name-only
if ($changes) {
    $stamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
    git commit -m "Review capture Version $Version $stamp"
    if ($LASTEXITCODE -ne 0) { throw "git commit failed." }
} else {
    Write-Host "No new review files to commit." -ForegroundColor Yellow
}

git push
if ($LASTEXITCODE -ne 0) { throw "git push failed." }

Write-Host "VERSION_${Version}_REVIEW_PUBLISHED: PASS" -ForegroundColor Green
Write-Host "GitHub review paths:" -ForegroundColor Green
Write-Host "  PROJECT/BISM2202_OUTPUT/Version_${Version}/screenshots/"
Write-Host "  PROJECT/BISM2202_OUTPUT/Version_${Version}/review_full/"
Write-Host "  PROJECT/Version_${Version}_PowerBI/BISM2202_Seed.Report/definition/"
