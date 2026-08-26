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

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int X, int Y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
}
"@
}

function Invoke-LeftClick {
    param(
        [Parameter(Mandatory=$true)][int]$X,
        [Parameter(Mandatory=$true)][int]$Y
    )

    [BISM2202CaptureNative]::SetCursorPos($X, $Y) | Out-Null
    Start-Sleep -Milliseconds 90
    [BISM2202CaptureNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 45
    [BISM2202CaptureNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
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
Start-Sleep -Milliseconds 900

$Rect = New-Object BISM2202CaptureNative+RECT
if (-not [BISM2202CaptureNative]::GetWindowRect($Handle, [ref]$Rect)) {
    throw "GetWindowRect failed."
}

$WindowWidth = $Rect.Right - $Rect.Left
$WindowHeight = $Rect.Bottom - $Rect.Top
if ($WindowWidth -lt 1000 -or $WindowHeight -lt 700) {
    throw "Power BI window is too small. Maximize Power BI before capture."
}

# Crop ratios independently verified against the user's accepted Q01 screenshot.
# They remove the Chinese Power BI chrome, right panes, page tabs, and Windows taskbar.
$CropLeft = $Rect.Left + [int]($WindowWidth * 0.055)
$CropTop = $Rect.Top + [int]($WindowHeight * 0.125)
$CropWidth = [int]($WindowWidth * 0.755)
$CropHeight = [int]($WindowHeight * 0.790)

$SafePoint = New-Object System.Drawing.Point(($Rect.Right - 25), ($Rect.Top + 90))

# All twenty report tabs are visible in the maximized Windows layout used for this
# assignment. Keyboard Ctrl+PgDn was observed to leave the report on Q01 while the
# old capture still reported PASS. Use deterministic mouse clicks on the visible tab
# strip instead. Coordinates are expressed as ratios so the script survives small
# resolution/DPI changes while preserving the verified layout.
$FirstTabX = $Rect.Left + [int]($WindowWidth * 0.0573)
$TabStepX = $WindowWidth * 0.0182
$TabY = $Rect.Bottom - [int]($WindowHeight * 0.043)

Write-Host ("Window={0}x{1}; firstTab=({2},{3}); tabStep={4:N2}" -f $WindowWidth, $WindowHeight, $FirstTabX, $TabY, $TabStepX) -ForegroundColor DarkGray

$FinalShotDir = Join-Path $RepoRoot "PROJECT\BISM2202_OUTPUT\Version_$Version\screenshots"
$FinalReviewDir = Join-Path $RepoRoot "PROJECT\BISM2202_OUTPUT\Version_$Version\review_full"
$StageRoot = Join-Path $env:TEMP ("bism2202_capture_{0}_{1}" -f $Version, [Guid]::NewGuid().ToString("N"))
$StageShotDir = Join-Path $StageRoot "screenshots"
$StageReviewDir = Join-Path $StageRoot "review_full"
New-Item -ItemType Directory -Force -Path $StageShotDir | Out-Null
New-Item -ItemType Directory -Force -Path $StageReviewDir | Out-Null

try {
    $Metadata = @()

    for ($Number = 1; $Number -le 20; $Number++) {
        $Name = "Q{0:D2}" -f $Number
        $TabX = $FirstTabX + [int](($Number - 1) * $TabStepX)

        [BISM2202CaptureNative]::SetForegroundWindow($Handle) | Out-Null
        Start-Sleep -Milliseconds 120
        Invoke-LeftClick -X $TabX -Y $TabY
        Start-Sleep -Milliseconds 350
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

        $ShotHash = (Get-FileHash $Shot -Algorithm SHA256).Hash
        $ReviewHash = (Get-FileHash $Review -Algorithm SHA256).Hash

        $Metadata += [pscustomobject]@{
            page = $Name
            tab_x = $TabX
            tab_y = $TabY
            canvas_file = $Shot
            canvas_bytes = $ShotInfo.Length
            canvas_sha256 = $ShotHash
            review_file = $Review
            review_bytes = $ReviewInfo.Length
            review_sha256 = $ReviewHash
            captured = (Get-Date).ToString("s")
            canvas_left = $CropLeft
            canvas_top = $CropTop
            canvas_width = $CropWidth
            canvas_height = $CropHeight
        }

        Write-Host ("Captured {0}: {1} bytes sha256={2}" -f $Name, $ShotInfo.Length, $ShotHash.Substring(0, 12)) -ForegroundColor DarkGray
    }

    $StageShots = @(Get-ChildItem $StageShotDir -Filter "Q??.png" -File | Sort-Object Name)
    $StageReviews = @(Get-ChildItem $StageReviewDir -Filter "Q??_full.png" -File | Sort-Object Name)
    if ($StageShots.Count -ne 20) {
        throw "Staging expected 20 canvas screenshots, found $($StageShots.Count)."
    }
    if ($StageReviews.Count -ne 20) {
        throw "Staging expected 20 full review screenshots, found $($StageReviews.Count)."
    }

    # Critical acceptance invariant: each question page must be visually distinct.
    # This catches the exact failure mode where Q01 was captured twenty times while
    # file-count/freshness checks still passed.
    $DuplicateCanvasGroups = @(
        $Metadata |
            Group-Object canvas_sha256 |
            Where-Object { $_.Count -gt 1 }
    )
    if ($DuplicateCanvasGroups.Count -gt 0) {
        $Details = foreach ($Group in $DuplicateCanvasGroups) {
            $Pages = ($Group.Group | ForEach-Object { $_.page }) -join ","
            "hash=$($Group.Name.Substring(0,12)) pages=$Pages"
        }
        throw "Duplicate page captures detected; refusing to publish. $($Details -join '; ')"
    }
    Write-Host "VERSION_${Version}_UNIQUE_PAGE_HASHES: 20/20 PASS" -ForegroundColor Green

    # Transactional publish: old output stays untouched until every staged page passes.
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
