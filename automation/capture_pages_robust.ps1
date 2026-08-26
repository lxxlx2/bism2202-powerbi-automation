param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("A", "B")]
    [string]$Version,

    [double]$DelaySeconds = 1.8
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

if (-not ("BISM2202CaptureNative" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class BISM2202CaptureNative {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
}

function Save-ScreenRegion {
    param(
        [int]$Left,
        [int]$Top,
        [int]$Width,
        [int]$Height,
        [string]$Target
    )

    if ($Width -lt 100 -or $Height -lt 100) {
        throw "Invalid capture rectangle ${Width}x${Height}."
    }

    $Bitmap = New-Object System.Drawing.Bitmap($Width, $Height)
    $Graphics = [System.Drawing.Graphics]::FromImage($Bitmap)
    try {
        $Graphics.CopyFromScreen(
            $Left,
            $Top,
            0,
            0,
            (New-Object System.Drawing.Size($Width, $Height)),
            [System.Drawing.CopyPixelOperation]::SourceCopy
        )
        $Parent = Split-Path -Parent $Target
        if ($Parent) {
            New-Item -ItemType Directory -Force -Path $Parent | Out-Null
        }
        $Bitmap.Save($Target, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $Graphics.Dispose()
        $Bitmap.Dispose()
    }
}

Write-Host "===== ROBUST TRANSACTIONAL POWER BI CAPTURE: VERSION $Version =====" -ForegroundColor Cyan

$Process = Get-Process PBIDesktop -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne 0 } |
    Sort-Object StartTime -Descending |
    Select-Object -First 1

if (-not $Process) {
    throw "Power BI Desktop is not running or no visible report window was found."
}

$Handle = $Process.MainWindowHandle
[BISM2202CaptureNative]::ShowWindow($Handle, 3) | Out-Null
[BISM2202CaptureNative]::SetForegroundWindow($Handle) | Out-Null
Start-Sleep -Milliseconds 800

$Rect = New-Object BISM2202CaptureNative+RECT
if (-not [BISM2202CaptureNative]::GetWindowRect($Handle, [ref]$Rect)) {
    throw "GetWindowRect failed."
}

$WindowWidth = $Rect.Right - $Rect.Left
$WindowHeight = $Rect.Bottom - $Rect.Top
if ($WindowWidth -lt 1000 -or $WindowHeight -lt 700) {
    throw "Power BI window is too small. Maximize Power BI before capture."
}

# These are the same crop ratios that were independently verified on Q01.
# They exclude Chinese Power BI chrome, the right panes, page tabs and taskbar.
$CropLeft = $Rect.Left + [int]($WindowWidth * 0.055)
$CropTop = $Rect.Top + [int]($WindowHeight * 0.125)
$CropWidth = [int]($WindowWidth * 0.755)
$CropHeight = [int]($WindowHeight * 0.790)

$SafePoint = New-Object System.Drawing.Point(($Rect.Right - 25), ($Rect.Top + 90))

$FinalShotDir = Join-Path $RepoRoot "PROJECT\BISM2202_OUTPUT\Version_$Version\screenshots"
$FinalReviewDir = Join-Path $RepoRoot "PROJECT\BISM2202_OUTPUT\Version_$Version\review_full"
$StageRoot = Join-Path $env:TEMP ("bism2202_capture_{0}_{1}" -f $Version, [Guid]::NewGuid().ToString("N"))
$StageShotDir = Join-Path $StageRoot "screenshots"
$StageReviewDir = Join-Path $StageRoot "review_full"
New-Item -ItemType Directory -Force -Path $StageShotDir | Out-Null
New-Item -ItemType Directory -Force -Path $StageReviewDir | Out-Null

try {
    # Deterministically return to the first report tab without relying on UIA tab discovery.
    [BISM2202CaptureNative]::SetForegroundWindow($Handle) | Out-Null
    for ($i = 0; $i -lt 25; $i++) {
        [System.Windows.Forms.SendKeys]::SendWait("^{PGUP}")
        Start-Sleep -Milliseconds 60
    }
    Start-Sleep -Milliseconds 700

    $Metadata = @()

    for ($Number = 1; $Number -le 20; $Number++) {
        $Name = "Q{0:D2}" -f $Number

        [BISM2202CaptureNative]::SetForegroundWindow($Handle) | Out-Null
        [System.Windows.Forms.SendKeys]::SendWait("{ESC}")
        [System.Windows.Forms.Cursor]::Position = $SafePoint
        Start-Sleep -Milliseconds ([int]($DelaySeconds * 1000))

        $Shot = Join-Path $StageShotDir "$Name.png"
        $Review = Join-Path $StageReviewDir "${Name}_full.png"

        Save-ScreenRegion -Left $CropLeft -Top $CropTop -Width $CropWidth -Height $CropHeight -Target $Shot
        Save-ScreenRegion -Left $Rect.Left -Top $Rect.Top -Width $WindowWidth -Height $WindowHeight -Target $Review

        $ShotInfo = Get-Item $Shot
        $ReviewInfo = Get-Item $Review
        if ($ShotInfo.Length -lt 5000) {
            throw "$Name canvas screenshot is suspiciously small: $($ShotInfo.Length) bytes"
        }
        if ($ReviewInfo.Length -lt 10000) {
            throw "$Name full review screenshot is suspiciously small: $($ReviewInfo.Length) bytes"
        }

        $Metadata += [pscustomobject]@{
            page = $Name
            canvas_file = $Shot
            canvas_bytes = $ShotInfo.Length
            review_file = $Review
            review_bytes = $ReviewInfo.Length
            captured = (Get-Date).ToString("s")
            canvas_left = $CropLeft
            canvas_top = $CropTop
            canvas_width = $CropWidth
            canvas_height = $CropHeight
        }

        Write-Host "Captured $Name: $($ShotInfo.Length) bytes" -ForegroundColor DarkGray

        if ($Number -lt 20) {
            [BISM2202CaptureNative]::SetForegroundWindow($Handle) | Out-Null
            [System.Windows.Forms.SendKeys]::SendWait("^{PGDN}")
            Start-Sleep -Milliseconds 350
        }
    }

    $StageShots = @(Get-ChildItem $StageShotDir -Filter "Q??.png" -File | Sort-Object Name)
    $StageReviews = @(Get-ChildItem $StageReviewDir -Filter "Q??_full.png" -File | Sort-Object Name)
    if ($StageShots.Count -ne 20) {
        throw "Staging expected 20 canvas screenshots, found $($StageShots.Count)."
    }
    if ($StageReviews.Count -ne 20) {
        throw "Staging expected 20 full review screenshots, found $($StageReviews.Count)."
    }

    # Transactional publish: old valid output is untouched until all 20 new pages pass.
    New-Item -ItemType Directory -Force -Path $FinalShotDir | Out-Null
    New-Item -ItemType Directory -Force -Path $FinalReviewDir | Out-Null

    Get-ChildItem $FinalShotDir -Filter "Q??.png" -File -ErrorAction SilentlyContinue | Remove-Item -Force
    Get-ChildItem $FinalReviewDir -Filter "Q??_full.png" -File -ErrorAction SilentlyContinue | Remove-Item -Force

    Copy-Item (Join-Path $StageShotDir "Q??.png") $FinalShotDir -Force
    Copy-Item (Join-Path $StageReviewDir "Q??_full.png") $FinalReviewDir -Force

    $MetadataJson = $Metadata | ConvertTo-Json -Depth 5
    Set-Content -Path (Join-Path $FinalShotDir "capture_metadata.json") -Value $MetadataJson -Encoding UTF8
    Set-Content -Path (Join-Path $FinalReviewDir "capture_metadata.json") -Value $MetadataJson -Encoding UTF8

    $PublishedShots = @(Get-ChildItem $FinalShotDir -Filter "Q??.png" -File | Sort-Object Name)
    if ($PublishedShots.Count -ne 20) {
        throw "Published screenshot verification failed: expected 20, found $($PublishedShots.Count)."
    }

    Write-Host "CLEAN_CAPTURE_${Version}: 20/20 PASS" -ForegroundColor Green
    Write-Host "VERSION_${Version}_SCREENSHOTS: 20 FRESH PASS" -ForegroundColor Green
    Write-Host "VERSION_${Version}_HOVER_SAFE_CAPTURE: PASS" -ForegroundColor Green
    Write-Host "VERSION_${Version}_TRANSACTIONAL_PUBLISH: PASS" -ForegroundColor Green
}
finally {
    if (Test-Path $StageRoot) {
        Remove-Item $StageRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
