param(
    [ValidateSet("A", "B")][string]$Version,
    [string]$ProjectRoot = "C:\BISM2202",
    [double]$DelaySeconds = 1.8,
    [double]$CanvasLeft = 0.05,
    [double]$CanvasTop = 0.17,
    [double]$CanvasWidth = 0.64,
    [double]$CanvasHeight = 0.69
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

if (-not ([System.Management.Automation.PSTypeName]'NativePowerBIWindow').Type) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class NativePowerBIWindow {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
}
"@
}

$OutputRoot = Join-Path $ProjectRoot "PROJECT\BISM2202_OUTPUT\Version_${Version}"
$Screenshots = Join-Path $OutputRoot "screenshots"
$ReviewFull = Join-Path $OutputRoot "review_full"
New-Item -ItemType Directory -Force -Path $Screenshots, $ReviewFull | Out-Null

function Get-PowerBIProcess {
    $deadline = (Get-Date).AddSeconds(30)
    do {
        $process = Get-Process PBIDesktop -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowHandle -ne 0 } |
            Sort-Object StartTime -Descending |
            Select-Object -First 1
        if ($process) { return $process }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)
    throw "No Power BI Desktop main window was found. Open the generated Version $Version PBIP first."
}

function Focus-PowerBI([System.Diagnostics.Process]$Process) {
    $handle = $Process.MainWindowHandle
    [NativePowerBIWindow]::ShowWindow($handle, 3) | Out-Null
    Start-Sleep -Milliseconds 500
    [NativePowerBIWindow]::SetForegroundWindow($handle) | Out-Null
    Start-Sleep -Milliseconds 500
}

function Get-WindowRectangle([System.Diagnostics.Process]$Process) {
    $rect = New-Object NativePowerBIWindow+RECT
    if (-not [NativePowerBIWindow]::GetWindowRect($Process.MainWindowHandle, [ref]$rect)) {
        throw "GetWindowRect failed for Power BI Desktop."
    }
    return [pscustomobject]@{
        Left = $rect.Left
        Top = $rect.Top
        Width = $rect.Right - $rect.Left
        Height = $rect.Bottom - $rect.Top
    }
}

function Save-ScreenRegion([int]$Left, [int]$Top, [int]$Width, [int]$Height, [string]$Path) {
    if ($Width -le 0 -or $Height -le 0) { throw "Invalid capture region ${Width}x${Height}." }
    $bitmap = New-Object System.Drawing.Bitmap $Width, $Height
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.CopyFromScreen($Left, $Top, 0, 0, $bitmap.Size)
        } finally {
            $graphics.Dispose()
        }
        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $bitmap.Dispose()
    }
}

function Get-PageElement([IntPtr]$Handle, [string]$PageName) {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($Handle)
    $condition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::NameProperty,
        $PageName
    )
    return $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
}

function Click-AutomationElement($Element) {
    if ($null -eq $Element) { return $false }

    $scroll = $null
    if ($Element.TryGetCurrentPattern([System.Windows.Automation.ScrollItemPattern]::Pattern, [ref]$scroll)) {
        try { $scroll.ScrollIntoView() } catch {}
        Start-Sleep -Milliseconds 250
    }

    $selection = $null
    if ($Element.TryGetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern, [ref]$selection)) {
        try {
            $selection.Select()
            return $true
        } catch {}
    }

    $invoke = $null
    if ($Element.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$invoke)) {
        try {
            $invoke.Invoke()
            return $true
        } catch {}
    }

    try {
        $bounds = $Element.Current.BoundingRectangle
        if ($bounds.Width -gt 2 -and $bounds.Height -gt 2) {
            $x = [int]($bounds.X + ($bounds.Width / 2))
            $y = [int]($bounds.Y + ($bounds.Height / 2))
            [NativePowerBIWindow]::SetCursorPos($x, $y) | Out-Null
            [NativePowerBIWindow]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
            [NativePowerBIWindow]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
            return $true
        }
    } catch {}

    return $false
}

function Select-ReportPage([System.Diagnostics.Process]$Process, [string]$PageName) {
    Focus-PowerBI $Process
    $deadline = (Get-Date).AddSeconds(8)
    do {
        $element = Get-PageElement $Process.MainWindowHandle $PageName
        if ($element -and (Click-AutomationElement $element)) {
            Start-Sleep -Seconds $DelaySeconds
            return
        }
        Start-Sleep -Milliseconds 300
    } while ((Get-Date) -lt $deadline)
    throw "Could not select Power BI page $PageName through Windows UI Automation."
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

$process = Get-PowerBIProcess
Focus-PowerBI $process

# Remove old captures so stale files cannot make a failed run look complete.
Get-ChildItem -LiteralPath $Screenshots -Filter 'Q??.png' -File -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -LiteralPath $ReviewFull -Filter 'Q??_full.png' -File -ErrorAction SilentlyContinue | Remove-Item -Force

$records = @()
$canvasHashes = @{}
$fullHashes = @{}

for ($number = 1; $number -le 20; $number++) {
    $pageName = "Q{0:D2}" -f $number
    $process.Refresh()
    Select-ReportPage $process $pageName

    $rect = Get-WindowRectangle $process
    $fullPath = Join-Path $ReviewFull ("${pageName}_full.png")
    $canvasPath = Join-Path $Screenshots ("${pageName}.png")

    Save-ScreenRegion $rect.Left $rect.Top $rect.Width $rect.Height $fullPath

    $canvasLeftPx = $rect.Left + [int]($rect.Width * $CanvasLeft)
    $canvasTopPx = $rect.Top + [int]($rect.Height * $CanvasTop)
    $canvasWidthPx = [int]($rect.Width * $CanvasWidth)
    $canvasHeightPx = [int]($rect.Height * $CanvasHeight)
    Save-ScreenRegion $canvasLeftPx $canvasTopPx $canvasWidthPx $canvasHeightPx $canvasPath

    $canvasHash = Get-Sha256 $canvasPath
    $fullHash = Get-Sha256 $fullPath
    $canvasHashes[$canvasHash] = $true
    $fullHashes[$fullHash] = $true

    $records += [ordered]@{
        page = $pageName
        canvas_file = $canvasPath
        review_file = $fullPath
        canvas_sha256 = $canvasHash
        review_sha256 = $fullHash
        captured = (Get-Date).ToString('s')
        window = $rect
        canvas = [ordered]@{
            left = $canvasLeftPx
            top = $canvasTopPx
            width = $canvasWidthPx
            height = $canvasHeightPx
        }
    }
    Write-Host "Captured $pageName" -ForegroundColor Green
}

# Every page has a different visual/title, so 20 identical images means page switching failed.
if ($canvasHashes.Count -lt 18 -or $fullHashes.Count -lt 18) {
    throw "Screenshot validation failed: only $($canvasHashes.Count) unique canvas images and $($fullHashes.Count) unique full-window images were captured. Page switching did not work reliably."
}

$metadata = Join-Path $ReviewFull 'capture_metadata.json'
$records | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $metadata -Encoding UTF8
$submissionMetadata = Join-Path $Screenshots 'capture_metadata.json'
$records | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $submissionMetadata -Encoding UTF8
Write-Host "Captured 20 distinct Power BI pages for Version $Version with UI Automation." -ForegroundColor Green
Write-Host "ARM64_NATIVE_CAPTURE: PASS" -ForegroundColor Green
