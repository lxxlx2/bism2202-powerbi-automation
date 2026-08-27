param(
    [string]$ProjectRoot = "C:\BISM2202"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path

function Assert-NativeExit([string]$Name) {
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE"
    }
}

function Count-DocxMedia([string]$Path) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        return @($zip.Entries | Where-Object { $_.FullName -like "word/media/*" -and -not $_.FullName.EndsWith("/") }).Count
    }
    finally {
        $zip.Dispose()
    }
}

function Assert-VersionReady([ValidateSet("A", "B")][string]$Version) {
    $output = Join-Path $RepoRoot "PROJECT\BISM2202_OUTPUT\Version_$Version"
    $source = Join-Path $RepoRoot "PROJECT\Version_${Version}_PowerBI"
    $reportSource = Join-Path $source "BISM2202_Seed.Report"
    $pbix = Join-Path $output "BISM2202_Assignment_${Version}.pbix"
    $shotsDir = Join-Path $output "screenshots"

    if (-not (Test-Path -LiteralPath $pbix)) {
        throw "Version $Version PBIX missing: $pbix"
    }
    $pbixItem = Get-Item -LiteralPath $pbix
    if ($pbixItem.Length -lt 100000) {
        throw "Version $Version PBIX is suspiciously small: $($pbixItem.Length) bytes"
    }

    $shots = @(Get-ChildItem -LiteralPath $shotsDir -Filter "Q??.png" -File -ErrorAction SilentlyContinue | Sort-Object Name)
    if ($shots.Count -ne 20) {
        throw "Version $Version screenshot count is $($shots.Count); expected 20"
    }
    foreach ($shot in $shots) {
        if ($shot.Length -lt 8000) {
            throw "Version $Version screenshot $($shot.Name) is suspiciously small: $($shot.Length) bytes"
        }
    }
    $hashes = @($shots | Get-FileHash -Algorithm SHA256)
    $unique = @($hashes.Hash | Sort-Object -Unique).Count
    if ($unique -ne 20) {
        throw "Version $Version screenshot uniqueness is $unique/20"
    }

    $han = '[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]'
    $chineseHits = @()
    Get-ChildItem -LiteralPath (Join-Path $reportSource "definition\pages") -Filter "visual.json" -File -Recurse | ForEach-Object {
        $raw = Get-Content -LiteralPath $_.FullName -Raw
        if ($raw -match $han) {
            $chineseHits += $_.FullName
        }
    }
    if ($chineseHits.Count -gt 0) {
        $chineseHits | ForEach-Object { Write-Host "VISIBLE_CHINESE_SOURCE: $_" -ForegroundColor Red }
        throw "Version $Version visible visual definitions contain explicit Chinese characters"
    }

    if (Get-Command pbi -ErrorAction SilentlyContinue) {
        & pbi report -p $reportSource validate | Out-Host
        Assert-NativeExit "PBIR validation Version $Version"
    }
    else {
        Write-Host "PBI CLI unavailable; continuing with source checks and already-saved PBIX." -ForegroundColor Yellow
    }

    Write-Host "VERSION_${Version}_PBIX: PASS ($($pbixItem.Length) bytes)" -ForegroundColor Green
    Write-Host "VERSION_${Version}_SCREENSHOTS: 20/20 PASS" -ForegroundColor Green
    Write-Host "VERSION_${Version}_UNIQUE_HASHES: 20/20 PASS" -ForegroundColor Green
    Write-Host "VERSION_${Version}_VISIBLE_CHINESE_SOURCE: 0 PASS" -ForegroundColor Green
}

Push-Location $RepoRoot
try {
    Write-Host "===== REVIEW-ONLY FINALIZATION =====" -ForegroundColor Cyan

    if (Get-Process PBIDesktop -ErrorAction SilentlyContinue) {
        throw "Close Power BI Desktop before finalization"
    }

    $Branch = (& git branch --show-current).Trim()
    Assert-NativeExit "git branch --show-current"
    if (-not $Branch) {
        throw "Detached HEAD is not allowed"
    }
    if ($Branch -eq "main") {
        throw "Review-only finalization refuses to run on main"
    }
    if ($Branch -notlike "review/*") {
        throw "Review-only finalization requires a review/* branch. Current branch: $Branch"
    }

    & git fetch origin main
    Assert-NativeExit "git fetch origin main"
    $MainBefore = (& git rev-parse origin/main).Trim()
    Assert-NativeExit "git rev-parse origin/main"
    $SourceCommit = (& git rev-parse HEAD).Trim()
    Assert-NativeExit "git rev-parse HEAD"

    Write-Host "BRANCH: $Branch"
    Write-Host "SOURCE_COMMIT: $SourceCommit"
    Write-Host "MAIN_BEFORE: $MainBefore"

    Write-Host "`n===== PRE-FINAL VALIDATION =====" -ForegroundColor Cyan
    Assert-VersionReady "A"
    Assert-VersionReady "B"

    $auditPath = Join-Path $RepoRoot "PROJECT\BISM2202_OUTPUT\COMMON\q01_q20_validation.json"
    if (-not (Test-Path -LiteralPath $auditPath)) {
        throw "Q01-Q20 validation file missing"
    }
    $audit = Get-Content -LiteralPath $auditPath -Raw | ConvertFrom-Json
    if ($audit.status -ne "PASS") {
        throw "Q01-Q20 validation status is not PASS"
    }
    if ($audit.q09.points -ne 31 -or -not $audit.q09.chronological -or -not $audit.q09.reconciles_to_total) {
        throw "Q09 audit invariants failed"
    }
    if (-not $audit.q19.all_rows_sum_to_100_percent -or -not $audit.q19.order_time_slicer_context_preserved) {
        throw "Q19 audit invariants failed"
    }
    Write-Host "Q01_Q20_DATA_AUDIT: PASS" -ForegroundColor Green
    Write-Host "Q09_CHRONOLOGY: PASS" -ForegroundColor Green
    Write-Host "Q19_PERCENT_AND_SLICER: PASS" -ForegroundColor Green

    Write-Host "`n===== REBUILD REPORTS =====" -ForegroundColor Cyan
    & py -3.12 (Join-Path $RepoRoot "automation\finalize_reports.py") --version Both | Out-Host
    Assert-NativeExit "finalize_reports.py"

    foreach ($Version in @("A", "B")) {
        $docx = Join-Path $RepoRoot "PROJECT\BISM2202_OUTPUT\Version_$Version\BISM2202_Report_${Version}.docx"
        if (-not (Test-Path -LiteralPath $docx)) {
            throw "Version $Version report missing after rebuild"
        }
        $media = Count-DocxMedia $docx
        if ($media -ne 20) {
            throw "Version $Version DOCX contains $media embedded images; expected 20"
        }
        Write-Host "VERSION_${Version}_REPORT_IMAGES: 20/20 PASS" -ForegroundColor Green
    }

    & git add -- PROJECT/BISM2202_OUTPUT/Version_A PROJECT/BISM2202_OUTPUT/Version_B Student_A Student_B
    Assert-NativeExit "git add rebuilt reports"
    & git diff --cached --quiet
    $diffExit = $LASTEXITCODE
    if ($diffExit -eq 1) {
        & git commit -m "review: rebuild final reports from approved screenshots"
        Assert-NativeExit "git commit rebuilt reports"
    }
    elseif ($diffExit -ne 0) {
        throw "git diff --cached --quiet failed with exit code $diffExit"
    }
    else {
        Write-Host "No report-content changes required a new commit." -ForegroundColor Yellow
    }
    $ContentCommit = (& git rev-parse HEAD).Trim()
    Assert-NativeExit "git rev-parse report commit"

    Write-Host "`n===== BUILD FINAL PACKAGES =====" -ForegroundColor Cyan
    & py -3.12 (Join-Path $RepoRoot "automation\package_final.py") --source-commit $SourceCommit --final-commit $ContentCommit | Out-Host
    Assert-NativeExit "package_final.py"

    $manifestPath = Join-Path $RepoRoot "FINAL_PACKAGES\FINAL_PACKAGE_MANIFEST.json"
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw "Final package manifest missing"
    }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.status -ne "PASS") {
        throw "Final package manifest status is not PASS"
    }
    foreach ($Version in @("A", "B")) {
        $zipPath = Join-Path $RepoRoot "FINAL_PACKAGES\BISM2202_Student_${Version}_FINAL.zip"
        if (-not (Test-Path -LiteralPath $zipPath)) {
            throw "Version $Version final ZIP missing"
        }
        if ((Get-Item -LiteralPath $zipPath).Length -lt 100000) {
            throw "Version $Version final ZIP is suspiciously small"
        }
    }
    Write-Host "FINAL_PACKAGE_MANIFEST: PASS" -ForegroundColor Green
    Write-Host "FINAL_PACKAGE_A: PASS" -ForegroundColor Green
    Write-Host "FINAL_PACKAGE_B: PASS" -ForegroundColor Green

    & git add -- FINAL_PACKAGES FINAL_DELIVERABLES PROJECT/BISM2202_OUTPUT/Version_A PROJECT/BISM2202_OUTPUT/Version_B Student_A Student_B
    Assert-NativeExit "git add final review packages"
    & git diff --cached --quiet
    $packageDiffExit = $LASTEXITCODE
    if ($packageDiffExit -eq 1) {
        & git commit -m "review: publish final BISM2202 packages for independent acceptance"
        Assert-NativeExit "git commit final review packages"
    }
    elseif ($packageDiffExit -ne 0) {
        throw "git diff --cached --quiet failed with exit code $packageDiffExit"
    }
    else {
        Write-Host "No package changes required a new commit." -ForegroundColor Yellow
    }

    $FinalHead = (& git rev-parse HEAD).Trim()
    Assert-NativeExit "git rev-parse final HEAD"

    Write-Host "`n===== PUSH REVIEW BRANCH ONLY =====" -ForegroundColor Cyan
    & git push -u origin "HEAD:refs/heads/$Branch"
    Assert-NativeExit "git push review branch"
    & git fetch origin $Branch
    Assert-NativeExit "git fetch review branch"
    $RemoteHead = (& git rev-parse "origin/$Branch").Trim()
    Assert-NativeExit "git rev-parse remote review branch"
    if ($FinalHead -ne $RemoteHead) {
        throw "Local and remote review branch HEAD mismatch"
    }

    & git fetch origin main
    Assert-NativeExit "git fetch origin main after finalization"
    $MainAfter = (& git rev-parse origin/main).Trim()
    Assert-NativeExit "git rev-parse origin/main after finalization"
    if ($MainAfter -ne $MainBefore) {
        throw "origin/main changed during review-only finalization"
    }

    Write-Host "`nREVIEW_ONLY_FINALIZATION: PASS" -ForegroundColor Green
    Write-Host "REPORTS_REBUILT: PASS" -ForegroundColor Green
    Write-Host "FINAL_PACKAGES_BUILT: PASS" -ForegroundColor Green
    Write-Host "REVIEW_BRANCH_PUSH: PASS" -ForegroundColor Green
    Write-Host "LOCAL_REMOTE_MATCH: PASS" -ForegroundColor Green
    Write-Host "MAIN_UPDATED: NO" -ForegroundColor Green
    Write-Host "READY_FOR_INDEPENDENT_FINAL_REVIEW: YES" -ForegroundColor Green
    Write-Host "FINAL_REVIEW_HEAD: $FinalHead"
}
finally {
    Pop-Location
}
