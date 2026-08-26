param(
    [string]$Output = "$([Environment]::GetFolderPath('Desktop'))\BISM2202_CURRENT_PAGE_CHECK.png"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

if (-not ("PowerBICaptureNative" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class PowerBICaptureNative {
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
}
"@
}

$Process = Get-Process PBIDesktop -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne 0 } |
    Sort-Object StartTime -Descending |
    Select-Object -First 1

if (-not $Process) {
    throw "Power BI Desktop is not running or no visible main window was found."
}

$Handle = $Process.MainWindowHandle
[PowerBICaptureNative]::SetForegroundWindow($Handle) | Out-Null
Start-Sleep -Milliseconds 600
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
Start-Sleep -Milliseconds 300

$Rect = New-Object PowerBICaptureNative+RECT
if (-not [PowerBICaptureNative]::GetWindowRect($Handle, [ref]$Rect)) {
    throw "GetWindowRect failed."
}

$WindowWidth = $Rect.Right - $Rect.Left
$WindowHeight = $Rect.Bottom - $Rect.Top
if ($WindowWidth -lt 1000 -or $WindowHeight -lt 700) {
    throw "Power BI window is too small. Maximize Power BI before capture."
}

# Move the pointer outside the report canvas so no tooltip/crosshair is captured.
[System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point(($Rect.Right - 25), ($Rect.Top + 90))
Start-Sleep -Milliseconds 600

# Crop only the report page area. These ratios match the maximized Power BI layout
# used in the Windows VM and intentionally exclude the Chinese ribbon, left nav,
# right Filters/Visualizations/Data panes, bottom page tabs and Windows taskbar.
$CropLeft = $Rect.Left + [int]($WindowWidth * 0.055)
$CropTop = $Rect.Top + [int]($WindowHeight * 0.125)
$CropWidth = [int]($WindowWidth * 0.755)
$CropHeight = [int]($WindowHeight * 0.790)

$Bitmap = New-Object System.Drawing.Bitmap($CropWidth, $CropHeight)
$Graphics = [System.Drawing.Graphics]::FromImage($Bitmap)
try {
    $Graphics.CopyFromScreen(
        $CropLeft,
        $CropTop,
        0,
        0,
        (New-Object System.Drawing.Size($CropWidth, $CropHeight)),
        [System.Drawing.CopyPixelOperation]::SourceCopy
    )

    $Directory = Split-Path -Parent $Output
    if ($Directory) {
        New-Item -ItemType Directory -Force -Path $Directory | Out-Null
    }
    $Bitmap.Save($Output, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $Graphics.Dispose()
    $Bitmap.Dispose()
}

$File = Get-Item $Output
if ($File.Length -lt 5000) {
    throw "Captured image is suspiciously small: $($File.Length) bytes"
}

Write-Host "CURRENT_PAGE_CANVAS_CAPTURE: PASS" -ForegroundColor Green
Write-Host "OUTPUT: $($File.FullName)" -ForegroundColor Green
Write-Host "BYTES: $($File.Length)" -ForegroundColor Green
Start-Process $File.FullName
