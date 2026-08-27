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
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

if (-not ("BISM2202DotNetUiaNative" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class BISM2202DotNetUiaNative {
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

    [BISM2202DotNetUiaNative]::SetCursorPos($X, $Y) | Out-Null
    Start-Sleep -Milliseconds 80
    [BISM2202DotNetUiaNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 40
    [BISM2202DotNetUiaNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
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

function Get-PageElement {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Automation.AutomationElement]$Root,
        [Parameter(Mandatory=$true)][string]$Name
    )

    $Condition = [System.Windows.Automation.PropertyCondition]::new(
        [System.Windows.Automation.AutomationElement]::NameProperty,
        $Name
    )
    return $Root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $Condition)
}

function Invoke-PageElement {
    param(
        [Parameter(Mandatory=$true)][System.Windows.Automation.AutomationElement]$Element,
        [Parameter(Mandatory=$true)][string]$Name
    )

    $Pattern = $null
    if ($Element.TryGetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern, [ref]$Pattern)) {
        ([System.Windows.Automation.SelectionItemPattern]$Pattern).Select()
        return "SelectionItem"
    }

    $Pattern = $null
    if ($Element.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$Pattern)) {
        ([System.Windows.Automation.InvokePattern]$Pattern).Invoke()
        return "Invoke"
    }

    $Pattern = $null
    if ($Element.TryGetCurrentPattern([System.Windows.Automation.LegacyIAccessiblePattern]::Pattern, [ref]$Pattern)) {
        ([System.Windows.Automation.LegacyIAccessiblePattern]$Pattern).DoDefaultAction()
        return "LegacyDefaultAction"
    }

    $Bounds = $Element.Current.BoundingRectangle
    if ($Bounds.IsEmpty -or $Bounds.Width -lt 2 -or $Bounds.Height -lt 2) {
        throw "UIA page tab $Name has no actionable pattern and no usable bounding rectangle."
    }

    $X = [int]($Bounds.Left + ($Bounds.Width / 2.0))
    $Y = [int]($Bounds.Top + ($Bounds.Height / 2.0))
    Invoke-LeftClick -X $X -Y $Y
    return "UIABoundsClick"
}

Write-Host "===== NATIVE .NET UIA POWER BI CAPTURE: VERSION $Version =====" -ForegroundColor Cyan

$Process = Get-Process PBIDesktop -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne 0 } |
    Sort-Object StartTime -Descending |
    Select-Object -First 1

if (-not $Process) {
    throw "Power BI Desktop is not running or no visible report window was found."
}

$Handle = $Process.MainWindowHandle
[BISM2202DotNetUiaNative]::ShowWindow($Handle, 3) | Out-Null
[BISM2202DotNetUiaNative]::SetForegroundWindow($Handle) | Out-Null
Start-Sleep -Milliseconds 1000

$Rect = New-Object BISM2202DotNetUiaNative+RECT
if (-not [BISM2202DotNetUiaNative]::GetWindowRect($Handle, [ref]$Rect)) {
    throw "GetWindowRect failed."
}

$WindowWidth = $Rect.Right - $Rect.Left
$WindowHeight = $Rect.Bottom - $Rect.Top
if ($WindowWidth -lt 1000 -or $WindowHeight -lt 700) {
    throw "Power BI window is too small. Maximize Power BI before capture."
}

$Root = [System.Windows.Automation.AutomationElement]::FromHandle($Handle)
if (-not $Root) {
    throw "Unable to obtain the Power BI UI Automation root element."
}

$PageElements = @{}
$Missing = @()
for ($Number = 1; $Number -le 20; $Number++) {
    $Name = "Q{0:D2}" -f $Number
    $Element = Get-PageElement -Root $Root -Name $Name
    if ($null -eq $Element) {
        $Missing += $Name
    }
    else {
        $PageElements[$Name] = $Element
    }
}

$DiscoveredNames = @($PageElements.Keys | Sort-Object)
Write-Host ("DOTNET_UIA_PAGE_TABS_DISCOVERED: {0}/20" -f $DiscoveredNames.Count) -ForegroundColor DarkGray
Write-Host ("DOTNET_UIA_PAGE_TAB_NAMES: {0}" -f ($DiscoveredNames -join ",")) -ForegroundColor DarkGray
if ($Missing.Count -gt 0) {
    throw "Native .NET UIA could not discover all Power BI report tabs. Missing: $($Missing -join ',')"
}
Write-Host "DOTNET_UIA_PAGE_TABS_DISCOVERED: 20/20 PASS" -ForegroundColor Green

# Ratios independently accepted for the clean report-canvas screenshots.
$CropLeft = $Rect.Left + [int]($WindowWidth * 0.055)
$CropTop = $Rect.Top + [int]($WindowHeight * 0.125)
$CropWidth = [int]($WindowWidth * 0.755)
$CropHeight = [int]($WindowHeight * 0.790)
$SafePoint = New-Object System.Drawing.Point(($Rect.Right - 25), ($Rect.Top + 90))

$FinalShotDir = Join-Path $RepoRoot "PROJECT\BISM2202_OUTPUT\Version_$Version\screenshots"
$FinalReviewDir = Join-Path $RepoRoot "PROJECT\BISM2202_OUTPUT\Version_$Version\review_full"
$StageRoot = Join-Path $env:TEMP ("bism2202_dotnet_uia_{0}_{1}" -f $Version, [Guid]::NewGuid().ToString("N"))
$StageShotDir = Join-Path $StageRoot "screenshots"
$StageReviewDir = Join-Path $StageRoot "review_full"
New-Item -ItemType Directory -Force -Path $StageShotDir | Out-Null
New-Item -ItemType Directory -Force -Path $StageReviewDir | Out-Null

try {
    $Metadata = @()

    for ($Number = 1; $Number -le 20; $Number++) {
        $Name = "Q{0:D2}" -f $Number

        [BISM2202DotNetUiaNative]::SetForegroundWindow($Handle) | Out-Null
        Start-Sleep -Milliseconds 120

        # Re-resolve every page before action because Power BI may recreate tab controls.
        $Element = Get-PageElement -Root $Root -Name $Name
        if ($null -eq $Element) {
            throw "Power BI UIA page tab $Name disappeared before capture."
        }

        $Driver = Invoke-PageElement -Element $Element -Name $Name
        Start-Sleep -Milliseconds 450
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
        $Bounds = $Element.Current.BoundingRectangle

        $Metadata += [pscustomobject]@{
            page = $Name
            driver = $Driver
            tab_left = $Bounds.Left
            tab_top = $Bounds.Top
            tab_width = $Bounds.Width
            tab_height = $Bounds.Height
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

        Write-Host ("Captured {0} via {1}: {2} bytes sha256={3}" -f $Name, $Driver, $ShotInfo.Length, $ShotHash.Substring(0, 12)) -ForegroundColor DarkGray
    }

    $StageShots = @(Get-ChildItem $StageShotDir -Filter "Q??.png" -File | Sort-Object Name)
    $StageReviews = @(Get-ChildItem $StageReviewDir -Filter "Q??_full.png" -File | Sort-Object Name)
    if ($StageShots.Count -ne 20) {
        throw "Staging expected 20 canvas screenshots, found $($StageShots.Count)."
    }
    if ($StageReviews.Count -ne 20) {
        throw "Staging expected 20 full review screenshots, found $($StageReviews.Count)."
    }

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
    $PublishedHashes = @($PublishedShots | Get-FileHash -Algorithm SHA256 | Select-Object -ExpandProperty Hash -Unique)
    if ($PublishedHashes.Count -ne 20) {
        throw "Published screenshots are not unique: $($PublishedHashes.Count)/20"
    }

    Write-Host "CLEAN_CAPTURE_${Version}: 20/20 PASS" -ForegroundColor Green
    Write-Host "VERSION_${Version}_SCREENSHOTS: 20 FRESH PASS" -ForegroundColor Green
    Write-Host "VERSION_${Version}_UNIQUE_FINAL_HASHES: 20/20 PASS" -ForegroundColor Green
    Write-Host "VERSION_${Version}_HOVER_SAFE_CAPTURE: PASS" -ForegroundColor Green
    Write-Host "VERSION_${Version}_TRANSACTIONAL_PUBLISH: PASS" -ForegroundColor Green
}
finally {
    if (Test-Path $StageRoot) {
        Remove-Item $StageRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
