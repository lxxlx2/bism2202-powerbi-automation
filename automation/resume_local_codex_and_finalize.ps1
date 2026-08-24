param(
    [string]$ProjectRoot = 'C:\BISM2202'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Run-Step([string]$Name, [scriptblock]$Action) {
    Write-Host "`n===== $Name =====" -ForegroundColor Cyan
    & $Action
    if ($LASTEXITCODE -ne 0) { throw "$Name failed with exit code $LASTEXITCODE" }
}

function Require-Path([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "Missing required path: $Path" }
}

Set-Location $ProjectRoot
$env:BISM2202_ROOT = $ProjectRoot

Write-Host '===== BISM2202 LOCAL RESUME + FINALIZE =====' -ForegroundColor Cyan
Write-Host "ProjectRoot=$ProjectRoot"

Require-Path (Join-Path $ProjectRoot 'automation')
Require-Path (Join-Path $ProjectRoot 'PROJECT')

$branch = (git branch --show-current).Trim()
if ($branch -ne 'main') {
    throw "Expected to run from local main branch, current branch is '$branch'."
}

# Preserve any local Codex edits. Do not pull/reset/checkout over them.
$before = git status --porcelain
Write-Host 'LOCAL_WORKTREE_BEFORE:' -ForegroundColor Yellow
if ($before) { $before | ForEach-Object { Write-Host $_ } } else { Write-Host '(clean)' }

# Make sure required CLI is reachable.
$scripts = py -3.12 -c "import sysconfig; print(sysconfig.get_path('scripts'))"
if ($LASTEXITCODE -eq 0 -and $scripts) { $env:Path = "$env:Path;$scripts" }
if (-not (Get-Command pbi -ErrorAction SilentlyContinue)) {
    throw 'pbi command not found. Install with: py -3.12 -m pip install --upgrade pbi-cli-tool'
}

# Close Power BI before PBIR/TMDL offline modification.
Get-Process PBIDesktop -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3

Run-Step 'FINAL AUDIT FIXES A+B' {
    pwsh -ExecutionPolicy Bypass -File .\automation\final_audit_fixes.ps1 -Version Both -ForceClosePowerBI
}

foreach ($v in @('A','B')) {
    $report = Join-Path $ProjectRoot "PROJECT\Version_${v}_PowerBI\BISM2202_Seed.Report"
    Require-Path $report
    Run-Step "PBIR VALIDATE $v" { pbi report -p $report validate }
}

# Re-open each PBIP and let Power BI materialize the latest PBIR/TMDL.
foreach ($v in @('A','B')) {
    $pbip = Join-Path $ProjectRoot "PROJECT\Version_${v}_PowerBI\BISM2202_Seed.pbip"
    Require-Path $pbip
    Write-Host "Opening Version $v PBIP..." -ForegroundColor Cyan
    Start-Process $pbip
    Start-Sleep -Seconds 18

    Run-Step "CAPTURE Q01-Q20 $v" { py -3.12 .\automation\capture_pages.py --version $v }
    Run-Step "SCREENSHOT VALIDATION $v" { py -3.12 .\automation\validate_screenshots.py --version $v }
    Run-Step "POWER BI VALIDATION $v" { py -3.12 .\automation\validate_powerbi.py --version $v --reopen }

    if (Test-Path -LiteralPath .\automation\powerbi_ui.ps1) {
        Run-Step "SAVE PBIX $v" { pwsh -ExecutionPolicy Bypass -File .\automation\powerbi_ui.ps1 -Version $v -Action SaveAs -ProjectRoot $ProjectRoot }
    }

    Get-Process PBIDesktop -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 3
}

Run-Step 'FINALIZE WORD REPORTS A+B' {
    py -3.12 .\automation\finalize_reports.py --version Both
}

Run-Step 'PACKAGE FINAL ZIPs' {
    py -3.12 .\automation\package_final.py
}

foreach ($v in @('A','B')) {
    $shotDir = Join-Path $ProjectRoot "PROJECT\BISM2202_OUTPUT\Version_${v}\screenshots"
    $shots = @(Get-ChildItem -LiteralPath $shotDir -Filter 'Q??.png' -File)
    if ($shots.Count -ne 20) { throw "Version $v expected 20 screenshots, found $($shots.Count)" }
    foreach ($shot in $shots) {
        if ($shot.Length -lt 5000) { throw "Suspiciously small screenshot: $($shot.FullName)" }
    }

    $student = Join-Path $ProjectRoot "Student_$v"
    $pbix = Join-Path $student 'BISM2202_Assignment.pbix'
    $docx = Join-Path $student 'BISM2202_Report.docx'
    if (-not (Test-Path $pbix) -or (Get-Item $pbix).Length -lt 100000) { throw "Missing/small final PBIX: $pbix" }
    if (-not (Test-Path $docx) -or (Get-Item $docx).Length -lt 50000) { throw "Missing/small final DOCX: $docx" }

    $zip = Join-Path $ProjectRoot "FINAL_PACKAGES\BISM2202_Student_${v}_FINAL.zip"
    Require-Path $zip
    $tmp = Join-Path $env:TEMP ("BISM2202_VERIFY_${v}_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
        Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force
        $files = @(Get-ChildItem -LiteralPath $tmp -File)
        $names = @($files.Name | Sort-Object)
        $expected = @('BISM2202_Assignment.pbix','BISM2202_Report.docx') | Sort-Object
        if (($names -join '|') -ne ($expected -join '|')) { throw "Version $v ZIP contents wrong: $($names -join ', ')" }
    }
    finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host "VERSION_${v}_FINAL_ARTIFACTS: PASS" -ForegroundColor Green
}

$manifestPath = Join-Path $ProjectRoot 'FINAL_PACKAGES\FINAL_PACKAGE_MANIFEST.json'
Require-Path $manifestPath
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.status -ne 'PASS') {
    throw ('FINAL_PACKAGE_MANIFEST failed: ' + (($manifest.issues | ForEach-Object { [string]$_ }) -join '; '))
}
Write-Host 'FINAL_PACKAGE_MANIFEST: PASS' -ForegroundColor Green

# Commit local/Codex work first.
git add -A
$staged = git diff --cached --name-only
if ($staged) {
    git commit -m 'fix: complete final BISM2202 A and B deliverables'
    if ($LASTEXITCODE -ne 0) { throw 'git commit failed' }
} else {
    Write-Host 'No new local changes to commit.' -ForegroundColor Yellow
}

# The helper script itself may have been added to origin/main after the local Windows
# workspace was created. Integrate remote main only after local work is safely committed.
git fetch origin
if ($LASTEXITCODE -ne 0) { throw 'git fetch origin failed' }
$localHeadBeforeRebase = (git rev-parse HEAD).Trim()
$originMain = (git rev-parse origin/main).Trim()
if ($localHeadBeforeRebase -ne $originMain) {
    Write-Host "Rebasing local completed work onto origin/main ($originMain)..." -ForegroundColor Cyan
    git rebase origin/main
    if ($LASTEXITCODE -ne 0) {
        throw 'git rebase origin/main failed. Stop here and send the terminal output for review; do not reset or abort manually.'
    }
}

git push origin HEAD:main
if ($LASTEXITCODE -ne 0) { throw 'git push failed' }

$head = (git rev-parse HEAD).Trim()
git fetch origin | Out-Host
$remote = (git rev-parse origin/main).Trim()
if ($head -ne $remote) { throw "HEAD/origin-main mismatch: $head vs $remote" }

$dirty = git status --porcelain
if ($dirty) { throw "Worktree still dirty after finalization:`n$dirty" }

Write-Host ''
Write-Host '==============================================' -ForegroundColor Green
Write-Host 'BISM2202_LOCAL_RESUME_FINALIZE: PASS' -ForegroundColor Green
Write-Host "FINAL_HEAD: $head" -ForegroundColor Green
Write-Host "A: $ProjectRoot\FINAL_PACKAGES\BISM2202_Student_A_FINAL.zip" -ForegroundColor Green
Write-Host "B: $ProjectRoot\FINAL_PACKAGES\BISM2202_Student_B_FINAL.zip" -ForegroundColor Green
Write-Host "MANIFEST: $manifestPath" -ForegroundColor Green
Write-Host 'WORKTREE_CLEAN: YES' -ForegroundColor Green
Write-Host '==============================================' -ForegroundColor Green
