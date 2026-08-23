Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")
$log = Start-BismTranscript "environment_check"
try {
    $root = Get-BismRoot
    $report = Join-Path $root "WINDOWS_ENVIRONMENT_REPORT.md"
    $os = Get-CimInstance Win32_OperatingSystem
    $computer = Get-CimInstance Win32_ComputerSystem
    $video = Get-CimInstance Win32_VideoController | Sort-Object CurrentHorizontalResolution -Descending | Select-Object -First 1
    $build = [int](Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber
    $ubr = [int](Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").UBR
    $fullBuild = [version]"$build.$ubr"
    $minimum24H2 = [version]"26100.6725"
    $minimum25H2 = [version]"26200.6725"
    $kb = Get-HotFix -Id KB5065789 -ErrorAction SilentlyContinue
    $armUpdateOk = [bool]$kb -or (($build -eq 26100) -and ($fullBuild -ge $minimum24H2)) -or ($build -gt 26100)
    if ($build -eq 26200) { $armUpdateOk = $fullBuild -ge $minimum25H2 }
    if ($build -gt 26200) { $armUpdateOk = $true }

    $dpi = (Get-ItemProperty "HKCU:\Control Panel\Desktop\WindowMetrics" -ErrorAction SilentlyContinue).AppliedDPI
    if (-not $dpi) { $dpi = 96 }
    $scale = [math]::Round(($dpi / 96) * 100)
    $powerBI = Find-PowerBIExecutable
    $items = @(
        "# BISM2202 Windows Environment Report", "",
        "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K')", "",
        "| Check | Result | Status |", "|---|---|---|",
        "| Windows | $($os.Caption), $($os.OSArchitecture), build $fullBuild | $(if ($os.Caption -match 'Windows 11') {'PASS'} else {'FAIL'}) |",
        "| Windows on ARM cumulative update | KB5065789 present=$([bool]$kb); build threshold satisfied=$armUpdateOk | $(if ($armUpdateOk) {'PASS'} else {'FAIL'}) |",
        "| RAM | $([math]::Round($computer.TotalPhysicalMemory / 1GB, 1)) GB | $(if ($computer.TotalPhysicalMemory -ge 8GB) {'PASS'} else {'FAIL'}) |",
        "| Display | $($video.CurrentHorizontalResolution)x$($video.CurrentVerticalResolution), scale ${scale}% | $(if ($video.CurrentHorizontalResolution -ge 1600 -and $video.CurrentVerticalResolution -ge 900 -and $scale -eq 100) {'PASS'} else {'CHECK'}) |",
        "| Git | $([bool](Get-Command git.exe -ErrorAction SilentlyContinue)) | INFO |",
        "| Python | $([bool](Get-Command py.exe -ErrorAction SilentlyContinue)) | INFO |",
        "| PowerShell 7 | $([bool](Get-Command pwsh.exe -ErrorAction SilentlyContinue)) | INFO |",
        "| Power BI Desktop | $(if ($powerBI) {$powerBI} else {'NOT FOUND'}) | $(if ($powerBI) {'PASS'} else {'MISSING'}) |",
        "", "Microsoft requirement used: Windows on ARM needs KB5065789 or a later cumulative build; display must be at least 1600x900 and 100% scaling is preferred.",
        "", "Log: $log"
    )
    $items | Set-Content -LiteralPath $report -Encoding UTF8
    $items | ForEach-Object { Write-Host $_ }
    if (-not $armUpdateOk) { Write-Warning "Run Windows Update until the OS build is at least 26100.6725/26200.6725 or newer." }
} finally {
    Stop-Transcript | Out-Null
}
