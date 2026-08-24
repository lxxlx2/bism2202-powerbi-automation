param(
    [string]$ProjectRoot = 'C:\BISM2202'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot

Write-Host '===== BISM2202 PID HOTFIX + RESUME =====' -ForegroundColor Cyan

git fetch origin
if ($LASTEXITCODE -ne 0) { throw 'git fetch origin failed' }

$opsRef = 'origin/ops/final-completion-check-v01'
$tempFinish = Join-Path $env:TEMP 'bism2202_finish_from_current_state_hotfixed.ps1'
$tempSaver  = Join-Path $env:TEMP 'bism2202_save_pbix_robust.ps1'

# Load the robust saver and patch the PowerShell automatic $PID name collision.
$saverText = (git show "${opsRef}:automation/save_pbix_robust.ps1") -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'Could not load save_pbix_robust.ps1 from ops branch' }

$saverText = $saverText.Replace('function Get-DialogForPid([int]$Pid) {','function Get-DialogForPid([int]$ProcessId) {')
$saverText = $saverText.Replace('if ($w.Current.ProcessId -eq $Pid -and $w.Current.IsOffscreen -eq $false) {','if ($w.Current.ProcessId -eq $ProcessId -and $w.Current.IsOffscreen -eq $false) {')
$saverText = $saverText.Replace('function Dismiss-WrongOverwritePrompt([int]$Pid) {','function Dismiss-WrongOverwritePrompt([int]$ProcessId) {')
$saverText = $saverText.Replace('if ($w.Current.ProcessId -ne $Pid) { continue }','if ($w.Current.ProcessId -ne $ProcessId) { continue }')
Set-Content -LiteralPath $tempSaver -Value $saverText -Encoding UTF8

# Load the continuation driver and make it use the already-hotfixed temp saver.
$finishText = (git show "${opsRef}:automation/finish_from_current_state.ps1") -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'Could not load finish_from_current_state.ps1 from ops branch' }

$oldBlock = @'
$opsRef = 'origin/ops/final-completion-check-v01'
$tempSaver = Join-Path $env:TEMP 'bism2202_save_pbix_robust.ps1'
git show "${opsRef}:automation/save_pbix_robust.ps1" | Set-Content -LiteralPath $tempSaver -Encoding UTF8
Check-Exit 'load robust saver'
'@

$newBlock = @'
$opsRef = 'origin/ops/final-completion-check-v01'
$tempSaver = Join-Path $env:TEMP 'bism2202_save_pbix_robust.ps1'
if (-not (Test-Path -LiteralPath $tempSaver)) { throw "Hotfixed robust saver missing: $tempSaver" }
Write-Host "Using PID-hotfixed robust saver: $tempSaver" -ForegroundColor Green
'@

if (-not $finishText.Contains($oldBlock)) {
    throw 'Continuation driver layout changed; refusing to patch blindly.'
}
$finishText = $finishText.Replace($oldBlock,$newBlock)
Set-Content -LiteralPath $tempFinish -Value $finishText -Encoding UTF8

Write-Host 'PID collision patched: PASS' -ForegroundColor Green
Write-Host 'Resuming from existing Version A screenshots...' -ForegroundColor Cyan

& pwsh -ExecutionPolicy Bypass -File $tempFinish -ProjectRoot $ProjectRoot
exit $LASTEXITCODE
