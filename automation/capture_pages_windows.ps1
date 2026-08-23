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
    Start-Sleep -Milliseconds 700
    [NativePowerBIWindow]::SetForegroundWindow($handle) | Out-Null
    Start-Sleep -Milliseconds 700
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

function Send-Key([string]$Keys) {
    [System.Windows.Forms.SendKeys]::SendWait($Keys)
    Start-Sleep -Milliseconds 180
}

$process = Get-PowerBIProcess
Focus-PowerBI $process

# Deterministically move to the first report page. Ctrl+PageUp stops at Q01.
for ($i = 0; $i -lt 30; $i++) { Send-Key '^{PGUP}' }
Start-Sleep -Seconds $DelaySeconds

$records = @()
for ($number = 1; $number -le 20; $number++) {
    $process.Refresh()
    Focus-PowerBI $process
    if ($number -gt 1) {
        Send-Key '^{PGDN}'
        Start-Sleep -Seconds $DelaySeconds
    }

    $rect = Get-WindowRectangle $process
    $fullPath = Join-Path $ReviewFull ("Q{0:D2}_full.png" -f $number)
    $canvasPath = Join-Path $Screenshots ("Q{0:D2}.png" -f $number)

    Save-ScreenRegion $rect.Left $rect.Top $rect.Width $rect.Height $fullPath

    $canvasLeftPx = $rect.Left + [int]($rect.Width * $CanvasLeft)
    $canvasTopPx = $rect.Top + [int]($rect.Height * $CanvasTop)
    $canvasWidthPx = [int]($rect.Width * $CanvasWidth)
    $canvasHeightPx = [int]($rect.Height * $CanvasHeight)
    Save-ScreenRegion $canvasLeftPx $canvasTopPx $canvasWidthPx $canvasHeightPx $canvasPath

    $records += [ordered]@{
        page = ("Q{0:D2}" -f $number)
        canvas_file = $canvasPath
        review_file = $fullPath
        captured = (Get-Date).ToString('s')
        window = $rect
        canvas = [ordered]@{
            left = $canvasLeftPx
            top = $canvasTopPx
            width = $canvasWidthPx
            height = $canvasHeightPx
        }
    }
    Write-Host ("Captured Q{0:D2}" -f $number) -ForegroundColor Green
}

$metadata = Join-Path $ReviewFull 'capture_metadata.json'
$records | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $metadata -Encoding UTF8
Write-Host "Captured 20 Power BI pages for Version $Version without Python/pywin32." -ForegroundColor Green
Write-Host "ARM64_NATIVE_CAPTURE: PASS" -ForegroundColor Green
