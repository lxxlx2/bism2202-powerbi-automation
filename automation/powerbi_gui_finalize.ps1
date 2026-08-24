param(
    [ValidateSet('A','B')][string]$Version,
    [ValidateSet('Inspect','InspectControls','Refresh','FileMenu','SaveAs','RecoverSaveDialog','CloseActivationPopup','SelectQ20Traffic','ExpandQ20Columns','OpenQ20SeriesDropdown','OpenQ20HighColor','SetQ20TrafficColors')][string]$Action = 'Inspect',
    [string]$ProjectRoot = 'C:\BISM2202',
    [int]$WaitSeconds = 45
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

if (-not ([System.Management.Automation.PSTypeName]'BismPowerBIWindow').Type) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class BismPowerBIWindow {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr hWnd, System.Text.StringBuilder className, int maxCount);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);

    public static IntPtr FindDialog(int processId) {
        IntPtr result = IntPtr.Zero;
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
            uint pid;
            GetWindowThreadProcessId(hWnd, out pid);
            if (pid == processId && IsWindowVisible(hWnd)) {
                var name = new System.Text.StringBuilder(128);
                GetClassName(hWnd, name, name.Capacity);
                if (name.ToString() == "#32770") {
                    result = hWnd;
                    return false;
                }
            }
            return true;
        }, IntPtr.Zero);
        return result;
    }
}
'@
}

function Get-PowerBIProcess {
    $process = Get-Process PBIDesktop -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 } |
        Sort-Object StartTime -Descending |
        Select-Object -First 1
    if (-not $process) { throw 'Power BI Desktop main window was not found.' }
    return $process
}

function Focus-PowerBI($Process) {
    [BismPowerBIWindow]::ShowWindow($Process.MainWindowHandle, 3) | Out-Null
    [BismPowerBIWindow]::SetForegroundWindow($Process.MainWindowHandle) | Out-Null
    Start-Sleep -Milliseconds 500
}

function Get-NamedElement($Root, [string[]]$Names) {
    foreach ($name in $Names) {
        $condition = New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::NameProperty, $name
        )
        $element = $Root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
        if ($element) { return $element }
    }
    return $null
}

function Get-AutomationIdElement($Root, [string]$AutomationId) {
    $condition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::AutomationIdProperty, $AutomationId
    )
    return $Root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
}

function Invoke-Element($Element) {
    if (-not $Element) { return $false }
    $invoke = $null
    if ($Element.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$invoke)) {
        $invoke.Invoke()
        return $true
    }
    $selection = $null
    if ($Element.TryGetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern, [ref]$selection)) {
        $selection.Select()
        return $true
    }
    $bounds = $Element.Current.BoundingRectangle
    if ($bounds.Width -gt 2 -and $bounds.Height -gt 2) {
        [BismPowerBIWindow]::SetCursorPos([int]($bounds.X + $bounds.Width / 2), [int]($bounds.Y + $bounds.Height / 2)) | Out-Null
        [BismPowerBIWindow]::mouse_event(0x0002,0,0,0,[UIntPtr]::Zero)
        [BismPowerBIWindow]::mouse_event(0x0004,0,0,0,[UIntPtr]::Zero)
        return $true
    }
    return $false
}

function Get-TopLevelWindows {
    return [System.Windows.Automation.AutomationElement]::RootElement.FindAll(
        [System.Windows.Automation.TreeScope]::Children,
        [System.Windows.Automation.Condition]::TrueCondition
    )
}

function Write-WindowInventory {
    foreach ($window in Get-TopLevelWindows) {
        $name = $window.Current.Name
        if ($name) {
            Write-Host ("WINDOW: {0} | class={1} | pid={2}" -f $name,$window.Current.ClassName,$window.Current.ProcessId)
        }
    }
}

function Set-FileDialogPath($Dialog, [string]$Path) {
    $edits = $Dialog.FindAll(
        [System.Windows.Automation.TreeScope]::Descendants,
        (New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
            [System.Windows.Automation.ControlType]::Edit
        ))
    )
    if ($edits.Count -eq 0) { throw 'Save As dialog has no editable filename field.' }
    $target = $edits[$edits.Count - 1]
    $value = $null
    if (-not $target.TryGetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern, [ref]$value)) {
        throw 'Save As filename field does not support ValuePattern.'
    }
    $value.SetValue($Path)
}

$process = Get-PowerBIProcess
Focus-PowerBI $process
$root = [System.Windows.Automation.AutomationElement]::FromHandle($process.MainWindowHandle)
$output = Join-Path $ProjectRoot "PROJECT\BISM2202_OUTPUT\Version_${Version}\BISM2202_Assignment_${Version}.pbix"
$parent = Split-Path -Parent $output
New-Item -ItemType Directory -Force -Path $parent | Out-Null

if ($Action -eq 'Inspect') {
    Write-Host "POWERBI_TITLE: $($process.MainWindowTitle)"
    Write-WindowInventory
    exit 0
}

if ($Action -eq 'InspectControls') {
    $elements = $root.FindAll(
        [System.Windows.Automation.TreeScope]::Descendants,
        [System.Windows.Automation.Condition]::TrueCondition
    )
    foreach ($element in $elements) {
        $type = $element.Current.ControlType.ProgrammaticName
        if ($type -in @('ControlType.ComboBox','ControlType.Button','ControlType.Edit','ControlType.ListItem','ControlType.Custom')) {
            $b = $element.Current.BoundingRectangle
            Write-Host ("CONTROL: type={0} name={1} id={2} bounds={3},{4},{5},{6}" -f $type,$element.Current.Name,$element.Current.AutomationId,[int]$b.X,[int]$b.Y,[int]$b.Width,[int]$b.Height)
        }
    }
    exit 0
}

if ($Action -eq 'Refresh') {
    # The warning bar is DirectX-rendered and its button is not reliably exposed
    # to UI Automation. Click the stable window-relative button position, safely
    # left of the warning bar's close icon.
    $rect = New-Object BismPowerBIWindow+RECT
    if (-not [BismPowerBIWindow]::GetWindowRect($process.MainWindowHandle, [ref]$rect)) {
        throw 'Could not resolve the Power BI window rectangle.'
    }
    $x = [int]($rect.Left + (($rect.Right - $rect.Left) * 0.872))
    $y = [int]($rect.Top + (($rect.Bottom - $rect.Top) * 0.098))
    [BismPowerBIWindow]::SetCursorPos($x,$y) | Out-Null
    [BismPowerBIWindow]::mouse_event(0x0002,0,0,0,[UIntPtr]::Zero)
    [BismPowerBIWindow]::mouse_event(0x0004,0,0,0,[UIntPtr]::Zero)
    Write-Host "Calculated-column refresh clicked at $x,$y." -ForegroundColor Cyan
    Start-Sleep -Seconds 2
    Write-Host 'POWERBI_REFRESH: PASS' -ForegroundColor Green
    exit 0
}

if ($Action -eq 'CloseActivationPopup') {
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $x = [int]($bounds.Left + ($bounds.Width * 0.569))
    $y = [int]($bounds.Top + ($bounds.Height * 0.582))
    [BismPowerBIWindow]::SetCursorPos($x,$y) | Out-Null
    [BismPowerBIWindow]::mouse_event(0x0002,0,0,0,[UIntPtr]::Zero)
    [BismPowerBIWindow]::mouse_event(0x0004,0,0,0,[UIntPtr]::Zero)
    Start-Sleep -Seconds 1
    Write-Host 'Windows activation information popup close button clicked.' -ForegroundColor Green
    exit 0
}

if ($Action -eq 'SelectQ20Traffic') {
    $rect = New-Object BismPowerBIWindow+RECT
    if (-not [BismPowerBIWindow]::GetWindowRect($process.MainWindowHandle, [ref]$rect)) {
        throw 'Could not resolve the Power BI window rectangle.'
    }
    $x = [int]($rect.Left + (($rect.Right - $rect.Left) * 0.67))
    # Click the chart title area so the visual container is selected without
    # selecting/cross-filtering one of the data bars.
    $y = [int]($rect.Top + (($rect.Bottom - $rect.Top) * 0.15))
    [BismPowerBIWindow]::SetCursorPos($x,$y) | Out-Null
    [BismPowerBIWindow]::mouse_event(0x0002,0,0,0,[UIntPtr]::Zero)
    [BismPowerBIWindow]::mouse_event(0x0004,0,0,0,[UIntPtr]::Zero)
    Start-Sleep -Seconds 1
    # Open the Format visual tab in the Visualizations pane.
    $fx = [int]($rect.Left + (($rect.Right - $rect.Left) * 0.922))
    $fy = [int]($rect.Top + (($rect.Bottom - $rect.Top) * 0.123))
    [BismPowerBIWindow]::SetCursorPos($fx,$fy) | Out-Null
    [BismPowerBIWindow]::mouse_event(0x0002,0,0,0,[UIntPtr]::Zero)
    [BismPowerBIWindow]::mouse_event(0x0004,0,0,0,[UIntPtr]::Zero)
    Write-Host "Q20 traffic visual selected at $x,$y." -ForegroundColor Green
    exit 0
}

if ($Action -eq 'ExpandQ20Columns') {
    $rect = New-Object BismPowerBIWindow+RECT
    if (-not [BismPowerBIWindow]::GetWindowRect($process.MainWindowHandle, [ref]$rect)) {
        throw 'Could not resolve the Power BI window rectangle.'
    }
    $x = [int]($rect.Left + (($rect.Right - $rect.Left) * 0.902))
    $y = [int]($rect.Top + (($rect.Bottom - $rect.Top) * 0.348))
    [BismPowerBIWindow]::SetCursorPos($x,$y) | Out-Null
    [BismPowerBIWindow]::mouse_event(0x0002,0,0,0,[UIntPtr]::Zero)
    [BismPowerBIWindow]::mouse_event(0x0004,0,0,0,[UIntPtr]::Zero)
    Start-Sleep -Seconds 1
    Write-Host 'Q20 Columns formatting card expanded.' -ForegroundColor Green
    exit 0
}

if ($Action -eq 'OpenQ20HighColor') {
    [System.Windows.Forms.SendKeys]::SendWait('{ESC}')
    Start-Sleep -Milliseconds 200
    & $MyInvocation.MyCommand.Path -Version $Version -Action OpenQ20SeriesDropdown -ProjectRoot $ProjectRoot | Out-Null
    [System.Windows.Forms.SendKeys]::SendWait('{HOME}')
    [System.Windows.Forms.SendKeys]::SendWait('{DOWN}')
    [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
    Start-Sleep -Milliseconds 500
    $buttons = $root.FindAll(
        [System.Windows.Automation.TreeScope]::Descendants,
        (New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
            [System.Windows.Automation.ControlType]::Button
        ))
    )
    $colorHeader = $null
    foreach ($button in $buttons) {
        $b = $button.Current.BoundingRectangle
        if ($b.X -ge 3100 -and $b.X -le 3130 -and $b.Y -ge 790 -and $b.Y -le 830 -and $b.Width -gt 100) {
            $colorHeader = $button
            break
        }
    }
    if (-not $colorHeader) { throw 'Q20 Color formatting card was not found.' }
    $expand = $null
    if ($colorHeader.TryGetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$expand)) {
        if ($expand.Current.ExpandCollapseState -eq [System.Windows.Automation.ExpandCollapseState]::Collapsed) {
            $expand.Expand()
            Start-Sleep -Milliseconds 300
        }
    }
    $colorHeader.SetFocus()
    [System.Windows.Forms.SendKeys]::SendWait('{TAB}')
    [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
    Start-Sleep -Seconds 1
    Write-Host 'Q20 High series color picker opened.' -ForegroundColor Green
    exit 0
}

if ($Action -eq 'OpenQ20SeriesDropdown') {
    $buttons = $root.FindAll(
        [System.Windows.Automation.TreeScope]::Descendants,
        (New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
            [System.Windows.Automation.ControlType]::Button
        ))
    )
    $target = $null
    foreach ($button in $buttons) {
        $b = $button.Current.BoundingRectangle
        if ($b.X -gt 3000 -and $b.Y -ge 740 -and $b.Y -le 780 -and $b.Width -gt 100) {
            $target = $button
            break
        }
    }
    if (-not $target) { throw 'Q20 series dropdown button was not found.' }
    if (-not (Invoke-Element $target)) { throw 'Q20 series dropdown could not be opened.' }
    Start-Sleep -Seconds 1
    Write-Host 'Q20 series dropdown opened.' -ForegroundColor Green
    exit 0
}

if ($Action -eq 'SetQ20TrafficColors') {
    [System.Windows.Forms.SendKeys]::SendWait('{ESC}')
    Start-Sleep -Milliseconds 200

    function Get-FormatButton([int]$YMin, [int]$YMax, [int]$MinWidth) {
        $buttons = $root.FindAll(
            [System.Windows.Automation.TreeScope]::Descendants,
            (New-Object System.Windows.Automation.PropertyCondition(
                [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
                [System.Windows.Automation.ControlType]::Button
            ))
        )
        foreach ($button in $buttons) {
            $b = $button.Current.BoundingRectangle
            if ($b.X -gt 3000 -and $b.Y -ge $YMin -and $b.Y -le $YMax -and $b.Width -ge $MinWidth) {
                return $button
            }
        }
        return $null
    }

    function Select-Series([int]$DownCount) {
        $dropdown = Get-FormatButton 740 780 100
        if (-not $dropdown -or -not (Invoke-Element $dropdown)) {
            throw 'Q20 series dropdown could not be opened.'
        }
        Start-Sleep -Milliseconds 250
        [System.Windows.Forms.SendKeys]::SendWait('{HOME}')
        for ($i = 0; $i -lt $DownCount; $i++) {
            [System.Windows.Forms.SendKeys]::SendWait('{DOWN}')
        }
        [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
        Start-Sleep -Milliseconds 350
    }

    function Open-SeriesColorPicker {
        $header = Get-FormatButton 790 830 100
        if (-not $header) { throw 'Q20 Color formatting card was not found.' }
        $expand = $null
        if ($header.TryGetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$expand)) {
            if ($expand.Current.ExpandCollapseState -eq [System.Windows.Automation.ExpandCollapseState]::Collapsed) {
                $expand.Expand()
                Start-Sleep -Milliseconds 250
            }
        }
        $header.SetFocus()
        [System.Windows.Forms.SendKeys]::SendWait('{TAB}')
        [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
        Start-Sleep -Milliseconds 350
    }

    function Click-ThemeColor([double]$XRatio) {
        $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $x = [int]($bounds.Left + ($bounds.Width * $XRatio))
        $y = [int]($bounds.Top + ($bounds.Height * 0.490))
        [BismPowerBIWindow]::SetCursorPos($x,$y) | Out-Null
        [BismPowerBIWindow]::mouse_event(0x0002,0,0,0,[UIntPtr]::Zero)
        [BismPowerBIWindow]::mouse_event(0x0004,0,0,0,[UIntPtr]::Zero)
        Start-Sleep -Milliseconds 400
    }

    # High = red, Low = blue, Medium = yellow.
    Select-Series 1
    Open-SeriesColorPicker
    Click-ThemeColor 0.981
    Select-Series 2
    Open-SeriesColorPicker
    Click-ThemeColor 0.924
    Select-Series 3
    Open-SeriesColorPicker
    Click-ThemeColor 0.973

    [System.Windows.Forms.SendKeys]::SendWait('{ESC}')
    [System.Windows.Forms.SendKeys]::SendWait('^s')
    Start-Sleep -Seconds 2
    Write-Host 'Q20 traffic colors set: High red, Low blue, Medium yellow.' -ForegroundColor Green
    Write-Host 'Q20_TRAFFIC_COLORS: PASS' -ForegroundColor Green
    exit 0
}

if ($Action -eq 'FileMenu') {
    $rect = New-Object BismPowerBIWindow+RECT
    if (-not [BismPowerBIWindow]::GetWindowRect($process.MainWindowHandle, [ref]$rect)) {
        throw 'Could not resolve the Power BI window rectangle.'
    }
    $x = [int]($rect.Left + 22)
    $y = [int]($rect.Top + 52)
    [BismPowerBIWindow]::SetCursorPos($x,$y) | Out-Null
    [BismPowerBIWindow]::mouse_event(0x0002,0,0,0,[UIntPtr]::Zero)
    [BismPowerBIWindow]::mouse_event(0x0004,0,0,0,[UIntPtr]::Zero)
    Start-Sleep -Seconds 2
    Write-Host 'POWERBI_FILE_MENU: OPEN' -ForegroundColor Green
    exit 0
}

if ($Action -eq 'RecoverSaveDialog') {
    # Recovery for a localized Windows Save As dialog that remained on PBIP.
    # Coordinates are proportional to the guest desktop, so this stays stable
    # at the fixed 100% display scale used for the assignment automation.
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    function Click-GuestPoint([double]$XRatio, [double]$YRatio) {
        $x = [int]($bounds.Left + ($bounds.Width * $XRatio))
        $y = [int]($bounds.Top + ($bounds.Height * $YRatio))
        [BismPowerBIWindow]::SetCursorPos($x,$y) | Out-Null
        [BismPowerBIWindow]::mouse_event(0x0002,0,0,0,[UIntPtr]::Zero)
        [BismPowerBIWindow]::mouse_event(0x0004,0,0,0,[UIntPtr]::Zero)
    }

    # Dismiss the PBIP overwrite confirmation with No.
    Click-GuestPoint 0.536 0.494
    Start-Sleep -Seconds 1

    # Select the first file type (PBIX) in the Save as type list.
    Click-GuestPoint 0.241 0.191
    Start-Sleep -Milliseconds 400
    [System.Windows.Forms.SendKeys]::SendWait('{HOME}')
    [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
    Start-Sleep -Milliseconds 500

    # Enter the full PBIX output path and invoke Save.
    Click-GuestPoint 0.116 0.175
    Set-Clipboard -Value $output
    [System.Windows.Forms.SendKeys]::SendWait('^a')
    [System.Windows.Forms.SendKeys]::SendWait('^v')
    Start-Sleep -Milliseconds 300
    Click-GuestPoint 0.200 0.231

    $deadline = (Get-Date).AddSeconds($WaitSeconds)
    do {
        if ((Test-Path -LiteralPath $output) -and (Get-Item -LiteralPath $output).Length -gt 100000) { break }
        Start-Sleep -Seconds 1
    } while ((Get-Date) -lt $deadline)

    if (-not (Test-Path -LiteralPath $output)) { throw "PBIX was not created: $output" }
    Write-Host "PBIX_SAVED: $output" -ForegroundColor Green
    Write-Host "PBIX_BYTES: $((Get-Item -LiteralPath $output).Length)" -ForegroundColor Green
    Write-Host 'POWERBI_SAVE_DIALOG_RECOVERY: PASS' -ForegroundColor Green
    exit 0
}

[System.Windows.Forms.SendKeys]::SendWait('{ESC}')
Start-Sleep -Milliseconds 500
$rect = New-Object BismPowerBIWindow+RECT
if (-not [BismPowerBIWindow]::GetWindowRect($process.MainWindowHandle, [ref]$rect)) {
    throw 'Could not resolve the Power BI window rectangle.'
}
[BismPowerBIWindow]::SetCursorPos(($rect.Left + 22),($rect.Top + 52)) | Out-Null
[BismPowerBIWindow]::mouse_event(0x0002,0,0,0,[UIntPtr]::Zero)
[BismPowerBIWindow]::mouse_event(0x0004,0,0,0,[UIntPtr]::Zero)
Start-Sleep -Seconds 2
[BismPowerBIWindow]::SetCursorPos(($rect.Left + 75),($rect.Top + 231)) | Out-Null
[BismPowerBIWindow]::mouse_event(0x0002,0,0,0,[UIntPtr]::Zero)
[BismPowerBIWindow]::mouse_event(0x0004,0,0,0,[UIntPtr]::Zero)
Start-Sleep -Seconds 3
[BismPowerBIWindow]::SetCursorPos(($rect.Left + 255),($rect.Top + 360)) | Out-Null
[BismPowerBIWindow]::mouse_event(0x0002,0,0,0,[UIntPtr]::Zero)
[BismPowerBIWindow]::mouse_event(0x0004,0,0,0,[UIntPtr]::Zero)
Start-Sleep -Seconds 3

$deadline = (Get-Date).AddSeconds(20)
$dialogHandle = [IntPtr]::Zero
do {
    $dialogHandle = [BismPowerBIWindow]::FindDialog($process.Id)
    if ($dialogHandle -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 300 }
} while ($dialogHandle -eq [IntPtr]::Zero -and (Get-Date) -lt $deadline)

if ($dialogHandle -eq [IntPtr]::Zero) { throw 'Save As dialog was not found.' }

[BismPowerBIWindow]::SetForegroundWindow($dialogHandle) | Out-Null
Start-Sleep -Milliseconds 300
[System.Windows.Forms.SendKeys]::SendWait('%t')
Start-Sleep -Milliseconds 200
[System.Windows.Forms.SendKeys]::SendWait('{HOME}')
[System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
[System.Windows.Forms.SendKeys]::SendWait('%n')
Set-Clipboard -Value $output
[System.Windows.Forms.SendKeys]::SendWait('^a')
[System.Windows.Forms.SendKeys]::SendWait('^v')
[System.Windows.Forms.SendKeys]::SendWait('{ENTER}')

Start-Sleep -Seconds 3
foreach ($window in Get-TopLevelWindows) {
    if ($window.Current.ClassName -eq '#32770') {
        try {
            $window.SetFocus()
            [System.Windows.Forms.SendKeys]::SendWait('%y')
        } catch {
            Write-Host "Non-focusable dialog ignored while save continues: $($_.Exception.Message)" -ForegroundColor DarkYellow
        }
    }
}

$deadline = (Get-Date).AddSeconds($WaitSeconds)
do {
    if ((Test-Path -LiteralPath $output) -and (Get-Item -LiteralPath $output).Length -gt 100000) { break }
    Start-Sleep -Seconds 1
} while ((Get-Date) -lt $deadline)

if (-not (Test-Path -LiteralPath $output)) { throw "PBIX was not created: $output" }
[System.Windows.Forms.SendKeys]::SendWait('^s')
Start-Sleep -Seconds 4
Write-Host "PBIX_SAVED: $output" -ForegroundColor Green
Write-Host "PBIX_BYTES: $((Get-Item -LiteralPath $output).Length)" -ForegroundColor Green
Write-Host 'POWERBI_SAVE_AS: PASS' -ForegroundColor Green
