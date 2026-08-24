param(
    [string]$ProjectRoot = 'C:\BISM2202'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot
$env:BISM2202_ROOT = $ProjectRoot

function Check-Exit([string]$Name) {
    if ($LASTEXITCODE -ne 0) { throw "$Name failed with exit code $LASTEXITCODE" }
}

function Stop-PowerBI {
    Get-Process PBIDesktop -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 4
}

function Assert-Pbix([string]$Version) {
    $path = Join-Path $ProjectRoot "PROJECT\BISM2202_OUTPUT\Version_${Version}\BISM2202_Assignment_${Version}.pbix"
    if (-not (Test-Path -LiteralPath $path)) { throw "PBIX missing: $path" }
    $bytes = (Get-Item -LiteralPath $path).Length
    if ($bytes -lt 100000) { throw "PBIX suspiciously small: $path ($bytes bytes)" }
    Write-Host "VERSION_${Version}_PBIX: PASS ($bytes bytes)" -ForegroundColor Green
}

function Assert-Screenshots([string]$Version) {
    $dir = Join-Path $ProjectRoot "PROJECT\BISM2202_OUTPUT\Version_${Version}\screenshots"
    $shots = if (Test-Path -LiteralPath $dir) { @(Get-ChildItem -LiteralPath $dir -Filter 'Q??.png' -File | Sort-Object Name) } else { @() }
    if ($shots.Count -ne 20) { throw "Version $Version screenshot count=$($shots.Count), expected 20" }
    foreach ($s in $shots) {
        if ($s.Length -lt 5000) { throw "Suspicious screenshot: $($s.FullName) ($($s.Length) bytes)" }
    }
    Write-Host "VERSION_${Version}_20_SCREENSHOTS: PASS" -ForegroundColor Green
}

Write-Host '===== BISM2202 RESUME FROM CURRENT WINDOWS STATE =====' -ForegroundColor Cyan
Write-Host "repo=$ProjectRoot"
Write-Host "branch=$((git branch --show-current).Trim())"
Write-Host "head=$((git rev-parse HEAD).Trim())"
Write-Host 'Existing local Codex changes are preserved. No reset, checkout, or pull will run before they are committed.' -ForegroundColor Yellow

git fetch origin
Check-Exit 'git fetch origin'

$opsRef = 'origin/ops/final-completion-check-v01'
$tempSaver = Join-Path $env:TEMP 'bism2202_save_pbix_robust.ps1'
git show "${opsRef}:automation/save_pbix_robust.ps1" | Set-Content -LiteralPath $tempSaver -Encoding UTF8
Check-Exit 'load robust saver'

# A screenshots were already captured before the repeated Save As stall. Validate them first.
Write-Host '\n===== VERSION A: VALIDATE EXISTING CAPTURE =====' -ForegroundColor Cyan
& py -3.12 "$ProjectRoot\automation\validate_screenshots.py" --version A
Check-Exit 'validate screenshots A'
Assert-Screenshots A

# Recover the currently open A Save As/overwrite state and produce a real PBIX.
Write-Host '\n===== VERSION A: ROBUST PBIX SAVE =====' -ForegroundColor Cyan
& pwsh -ExecutionPolicy Bypass -File $tempSaver -Version A -ProjectRoot $ProjectRoot -WaitSeconds 120
Check-Exit 'robust PBIX save A'
Assert-Pbix A
Stop-PowerBI

# Build/capture/save B from its PBIP source.
Write-Host '\n===== VERSION B: OPEN / CAPTURE / SAVE =====' -ForegroundColor Cyan
$pbipB = Join-Path $ProjectRoot 'PROJECT\Version_B_PowerBI\BISM2202_Seed.pbip'
if (-not (Test-Path -LiteralPath $pbipB)) { throw "Missing Version B PBIP: $pbipB" }
Start-Process $pbipB
Start-Sleep -Seconds 30

& pwsh -ExecutionPolicy Bypass -File "$ProjectRoot\automation\capture_pages_windows.ps1" -Version B -ProjectRoot $ProjectRoot
Check-Exit 'capture Version B'
& py -3.12 "$ProjectRoot\automation\validate_screenshots.py" --version B
Check-Exit 'validate screenshots B'
Assert-Screenshots B

& pwsh -ExecutionPolicy Bypass -File $tempSaver -Version B -ProjectRoot $ProjectRoot -WaitSeconds 120
Check-Exit 'robust PBIX save B'
Assert-Pbix B
Stop-PowerBI

Write-Host '\n===== REGENERATE WORD REPORTS =====' -ForegroundColor Cyan
& py -3.12 "$ProjectRoot\automation\finalize_reports.py" --version Both
Check-Exit 'finalize_reports.py'

Write-Host '\n===== BUILD FINAL PACKAGES =====' -ForegroundColor Cyan
& py -3.12 "$ProjectRoot\automation\package_final.py"
Check-Exit 'package_final.py'

foreach ($v in @('A','B')) {
    Assert-Screenshots $v
    Assert-Pbix $v

    $studentDir = Join-Path $ProjectRoot "Student_$v"
    $studentPbix = Join-Path $studentDir 'BISM2202_Assignment.pbix'
    $studentDocx = Join-Path $studentDir 'BISM2202_Report.docx'
    $zip = Join-Path $ProjectRoot "FINAL_PACKAGES\BISM2202_Student_${v}_FINAL.zip"

    foreach ($f in @($studentPbix,$studentDocx,$zip)) {
        if (-not (Test-Path -LiteralPath $f)) { throw "Missing final artifact: $f" }
    }
    if ((Get-Item -LiteralPath $studentPbix).Length -lt 100000) { throw "Student $v PBIX too small" }
    if ((Get-Item -LiteralPath $studentDocx).Length -lt 50000) { throw "Student $v DOCX too small" }

    $verify = Join-Path $env:TEMP ("BISM2202_FINAL_VERIFY_${v}_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $verify | Out-Null
    try {
        Expand-Archive -LiteralPath $zip -DestinationPath $verify -Force
        $files = @(Get-ChildItem -LiteralPath $verify -File | Sort-Object Name)
        if ($files.Count -ne 2) { throw "Version $v ZIP has $($files.Count) files, expected 2" }
        $names = @($files.Name)
        if (($names -join '|') -ne 'BISM2202_Assignment.pbix|BISM2202_Report.docx') {
            throw "Version $v ZIP contains unexpected files: $($names -join ', ')"
        }
    } finally {
        if (Test-Path -LiteralPath $verify) { Remove-Item -LiteralPath $verify -Recurse -Force }
    }
    Write-Host "VERSION_${v}_FINAL_PACKAGE: PASS" -ForegroundColor Green
}

$manifest = Join-Path $ProjectRoot 'FINAL_PACKAGES\FINAL_PACKAGE_MANIFEST.json'
if (-not (Test-Path -LiteralPath $manifest)) { throw 'FINAL_PACKAGE_MANIFEST.json missing' }
$m = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
if ($m.status -ne 'PASS') { throw "Final manifest status=$($m.status)" }
Write-Host 'FINAL_PACKAGE_MANIFEST: PASS' -ForegroundColor Green

Write-Host '\n===== COMMIT LOCAL CODEX WORK + FINAL ARTIFACTS =====' -ForegroundColor Cyan
Write-Host 'Pre-commit status:' -ForegroundColor Cyan
git status --short

git add -A
$staged = git diff --cached --name-only
if ($staged) {
    git commit -m 'fix: complete final BISM2202 A and B delivery'
    Check-Exit 'git commit'
} else {
    Write-Host 'No staged changes; using existing HEAD.' -ForegroundColor Yellow
}

# Synchronize only after local work is safely committed.
git fetch origin
Check-Exit 'final fetch'
$currentBranch = (git branch --show-current).Trim()
if ($currentBranch -ne 'main') {
    throw "Current branch is $currentBranch, expected main. Local work is safely committed; stop here and report this message."
}

$remoteMain = (git rev-parse origin/main).Trim()
$head = (git rev-parse HEAD).Trim()
if ($head -ne $remoteMain) {
    git rebase origin/main
    if ($LASTEXITCODE -ne 0) { throw 'Rebase failed. Local commit is safe. Do not reset; report the conflict.' }
}

git push origin HEAD:main
Check-Exit 'git push origin main'
git fetch origin
Check-Exit 'post-push fetch'

$head = (git rev-parse HEAD).Trim()
$origin = (git rev-parse origin/main).Trim()
if ($head -ne $origin) { throw "HEAD/origin-main mismatch: $head vs $origin" }
$dirty = git status --porcelain
if ($dirty) { throw "Worktree not clean after push:`n$dirty" }

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'BISM2202_RESUME_FINAL_PIPELINE: PASS' -ForegroundColor Green
Write-Host "FINAL_HEAD: $head" -ForegroundColor Green
Write-Host 'VERSION_A_20_SCREENSHOTS: PASS' -ForegroundColor Green
Write-Host 'VERSION_B_20_SCREENSHOTS: PASS' -ForegroundColor Green
Write-Host 'VERSION_A_PBIX: PASS' -ForegroundColor Green
Write-Host 'VERSION_B_PBIX: PASS' -ForegroundColor Green
Write-Host 'VERSION_A_REPORT: PASS' -ForegroundColor Green
Write-Host 'VERSION_B_REPORT: PASS' -ForegroundColor Green
Write-Host "FINAL_PACKAGE_A: $ProjectRoot\FINAL_PACKAGES\BISM2202_Student_A_FINAL.zip" -ForegroundColor Green
Write-Host "FINAL_PACKAGE_B: $ProjectRoot\FINAL_PACKAGES\BISM2202_Student_B_FINAL.zip" -ForegroundColor Green
Write-Host 'GIT_PUSH: PASS' -ForegroundColor Green
Write-Host 'WORKTREE_CLEAN: YES' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
