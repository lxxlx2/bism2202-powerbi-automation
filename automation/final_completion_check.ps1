param(
    [string]$ProjectRoot = 'C:\BISM2202',
    [string]$BaselineSha = 'a1f597a46e11457a17427d2e83caac887aa27709',
    [switch]$Finalize
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Message, [int]$Code = 2) {
    Write-Host $Message -ForegroundColor Red
    exit $Code
}

function Pass([string]$Message) {
    Write-Host $Message -ForegroundColor Green
}

if (-not (Test-Path -LiteralPath $ProjectRoot)) {
    Fail "Project root not found: $ProjectRoot"
}

Set-Location $ProjectRoot
$env:BISM2202_ROOT = $ProjectRoot

Write-Host '===== BISM2202 REMOTE COMPLETION CHECK =====' -ForegroundColor Cyan

git fetch origin
if ($LASTEXITCODE -ne 0) { Fail 'git fetch origin failed.' }

$remote = (git rev-parse origin/main).Trim()
Write-Host "origin/main=$remote"
Write-Host "baseline=$BaselineSha"

if ($remote -eq $BaselineSha) {
    Write-Host 'CODEX_REMOTE_NOT_FINISHED: origin/main has not advanced past the previous baseline.' -ForegroundColor Yellow
    Write-Host 'Leave the Codex task running. Re-run this checker after Codex reports that it committed and pushed.' -ForegroundColor Yellow
    exit 3
}

$dirtyBefore = git status --porcelain
if ($dirtyBefore) {
    Fail "Local Windows repo is not clean. Do not overwrite current work. Current changes:`n$dirtyBefore" 4
}

git switch main
if ($LASTEXITCODE -ne 0) { Fail 'git switch main failed.' }
git pull --ff-only origin main
if ($LASTEXITCODE -ne 0) { Fail 'git pull --ff-only origin main failed.' }

$head = (git rev-parse HEAD).Trim()
if ($head -ne $remote) { Fail "Local HEAD does not match origin/main: HEAD=$head origin/main=$remote" }
Pass "REMOTE_CODEX_COMMIT_PRESENT: PASS ($head)"

$scripts = py -3.12 -c "import sysconfig; print(sysconfig.get_path('scripts'))"
if ($LASTEXITCODE -eq 0 -and $scripts) { $env:Path = "$env:Path;$scripts" }
if (-not (Get-Command pbi -ErrorAction SilentlyContinue)) {
    Fail 'pbi command not found. Install with: py -3.12 -m pip install --upgrade pbi-cli-tool'
}

foreach ($version in @('A','B')) {
    $report = Join-Path $ProjectRoot "PROJECT\Version_${version}_PowerBI\BISM2202_Seed.Report"
    if (-not (Test-Path -LiteralPath $report)) { Fail "Missing Version $version PBIR report: $report" }
    & pbi report -p $report validate
    if ($LASTEXITCODE -ne 0) { Fail "PBIR validation failed for Version $version" }
    Pass "VERSION_${version}_PBIR_VALIDATE: PASS"

    $shotDir = Join-Path $ProjectRoot "PROJECT\BISM2202_OUTPUT\Version_${version}\screenshots"
    $shots = if (Test-Path -LiteralPath $shotDir) { @(Get-ChildItem -LiteralPath $shotDir -Filter 'Q??.png' -File) } else { @() }
    if ($shots.Count -ne 20) { Fail "Version $version expected 20 final screenshots, found $($shots.Count): $shotDir" }
    foreach ($shot in $shots) {
        if ($shot.Length -lt 5000) { Fail "Suspiciously small screenshot: $($shot.FullName) ($($shot.Length) bytes)" }
    }
    Pass "VERSION_${version}_20_SCREENSHOTS: PASS"
}

if (-not $Finalize) {
    Write-Host 'STRUCTURAL_CHECK: PASS' -ForegroundColor Green
    Write-Host 'Run again with -Finalize to regenerate Word reports, rebuild final ZIPs, verify manifest, and publish final artifacts.' -ForegroundColor Cyan
    exit 0
}

Write-Host '===== FINALIZE REPORTS =====' -ForegroundColor Cyan
& py -3.12 .\automation\finalize_reports.py --version Both
if ($LASTEXITCODE -ne 0) { Fail 'finalize_reports.py failed.' }

foreach ($version in @('A','B')) {
    $student = Join-Path $ProjectRoot "Student_$version"
    $pbix = Join-Path $student 'BISM2202_Assignment.pbix'
    $docx = Join-Path $student 'BISM2202_Report.docx'
    if (-not (Test-Path -LiteralPath $pbix) -or (Get-Item $pbix).Length -lt 100000) { Fail "Missing/small Student $version PBIX: $pbix" }
    if (-not (Test-Path -LiteralPath $docx) -or (Get-Item $docx).Length -lt 50000) { Fail "Missing/small Student $version DOCX: $docx" }
    Pass "STUDENT_${version}_PBIX_DOCX: PASS"
}

Write-Host '===== PACKAGE FINAL =====' -ForegroundColor Cyan
& py -3.12 .\automation\package_final.py
if ($LASTEXITCODE -ne 0) { Fail 'package_final.py failed.' }

$manifestPath = Join-Path $ProjectRoot 'FINAL_PACKAGES\FINAL_PACKAGE_MANIFEST.json'
if (-not (Test-Path -LiteralPath $manifestPath)) { Fail 'FINAL_PACKAGE_MANIFEST.json missing.' }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.status -ne 'PASS') {
    Fail ("Final package manifest failed: " + (($manifest.issues | ForEach-Object { [string]$_ }) -join '; '))
}
Pass 'FINAL_PACKAGE_MANIFEST: PASS'

foreach ($version in @('A','B')) {
    $zip = Join-Path $ProjectRoot "FINAL_PACKAGES\BISM2202_Student_${version}_FINAL.zip"
    if (-not (Test-Path -LiteralPath $zip)) { Fail "Missing final ZIP: $zip" }
    $temp = Join-Path $env:TEMP ("BISM2202_FINAL_VERIFY_" + $version + '_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $temp | Out-Null
    try {
        Expand-Archive -LiteralPath $zip -DestinationPath $temp -Force
        $files = @(Get-ChildItem -LiteralPath $temp -File)
        if ($files.Count -ne 2) { Fail "Version $version final ZIP must contain exactly 2 files; found $($files.Count)." }
        $names = @($files.Name | Sort-Object)
        $expected = @('BISM2202_Assignment.pbix','BISM2202_Report.docx') | Sort-Object
        if (($names -join '|') -ne ($expected -join '|')) { Fail "Version $version ZIP names wrong: $($names -join ', ')" }
    } finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
    }
    Pass "FINAL_ZIP_${version}_REEXTRACT: PASS"
}

$stage = @(
    'PROJECT/BISM2202_OUTPUT/Version_A/BISM2202_Report_A.docx',
    'PROJECT/BISM2202_OUTPUT/Version_B/BISM2202_Report_B.docx',
    'Student_A',
    'Student_B',
    'FINAL_PACKAGES'
)
foreach ($path in $stage) {
    if (Test-Path -LiteralPath (Join-Path $ProjectRoot ($path -replace '/', '\'))) {
        git add -- $path
    }
}

$cached = git diff --cached --name-only
if ($cached) {
    git commit -m 'chore: publish final BISM2202 delivery artifacts'
    if ($LASTEXITCODE -ne 0) { Fail 'git commit failed.' }
    git push origin main
    if ($LASTEXITCODE -ne 0) { Fail 'git push origin main failed.' }
}

$dirtyAfter = git status --porcelain
if ($dirtyAfter) { Fail "Final worktree is not clean:`n$dirtyAfter" }

$finalHead = (git rev-parse HEAD).Trim()
$originHead = (git rev-parse origin/main).Trim()
if ($finalHead -ne $originHead) { Fail "HEAD/origin-main mismatch: $finalHead vs $originHead" }

Write-Host '=========================================' -ForegroundColor Green
Write-Host 'BISM2202_FINAL_COMPLETION_CHECK: PASS' -ForegroundColor Green
Write-Host "FINAL_HEAD: $finalHead" -ForegroundColor Green
Write-Host "A: $ProjectRoot\FINAL_PACKAGES\BISM2202_Student_A_FINAL.zip" -ForegroundColor Green
Write-Host "B: $ProjectRoot\FINAL_PACKAGES\BISM2202_Student_B_FINAL.zip" -ForegroundColor Green
Write-Host "MANIFEST: $manifestPath" -ForegroundColor Green
Write-Host 'WORKTREE_CLEAN: YES' -ForegroundColor Green
Write-Host '=========================================' -ForegroundColor Green
