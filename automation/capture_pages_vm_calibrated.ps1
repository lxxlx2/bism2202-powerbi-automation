param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("A", "B")]
    [string]$Version,

    [double]$DelaySeconds = 1.8
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Source = Join-Path $PSScriptRoot "capture_pages_robust.ps1"
if (-not (Test-Path $Source)) {
    throw "Base robust capture script not found: $Source"
}

# The current Parallels/Windows layout shows all Q01-Q20 tabs with centers spaced
# ~1.82% of the Power BI window width apart. The previous first-tab offset (5.73%)
# landed in the navigation area to the left of Q01, so page clicks progressively
# missed the actual tabs and duplicate page captures were correctly rejected.
# Current VM calibration from the user's maximized 1920-wide Power BI layout:
# Q01 center ~= 8.58% of window width; Q20 center ~= 43.16%.
$Original = Get-Content $Source -Raw
$Needle = '$FirstTabX = $Rect.Left + [int]($WindowWidth * 0.0573)'
$Replacement = '$FirstTabX = $Rect.Left + [int]($WindowWidth * 0.0858)'

if (-not $Original.Contains($Needle)) {
    throw "Expected first-tab calibration line was not found in base script; refusing to patch blindly."
}

$Patched = $Original.Replace($Needle, $Replacement)
$Temp = Join-Path $env:TEMP ("bism2202_capture_calibrated_{0}_{1}.ps1" -f $Version, [Guid]::NewGuid().ToString("N"))

try {
    Set-Content -Path $Temp -Value $Patched -Encoding UTF8

    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $Temp,
        [ref]$tokens,
        [ref]$errors
    ) | Out-Null

    if ($errors.Count -gt 0) {
        $errors | Format-List
        throw "Calibrated capture script syntax check failed."
    }

    Write-Host "CAPTURE_TAB_CALIBRATION: Q01=8.58% STEP=1.82% PASS" -ForegroundColor Green

    & pwsh -ExecutionPolicy Bypass -File $Temp -Version $Version -DelaySeconds $DelaySeconds
    if ($LASTEXITCODE -ne 0) {
        throw "Calibrated robust capture failed with exit code $LASTEXITCODE"
    }
}
finally {
    Remove-Item $Temp -Force -ErrorAction SilentlyContinue
}
