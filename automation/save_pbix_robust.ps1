param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('A','B')]
    [string]$Version,

    [string]$ProjectRoot = 'C:\BISM2202',
    [int]$WaitSeconds = 90
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

if (-not ([System.Management.Automation.PSTypeName]'BismRobustPBIX').Type) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class BismRobustPBIX {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);
}
'@
}

function Get-PowerBIProcess {
    $p = Get-Process PBIDesktop -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 } |
        Sort-Object StartTime -Descending |
        Select-Object -First 1
    if (-not $p) { throw 'Power BI Desktop main window was not found.' }
    return $p
}

function Focus-Process($Process) {
    [BismRobustPBIX]::ShowWindow($Process.MainWindowHandle, 3) | Out-Null
    [BismRobustPBIX]::SetForegroundWindow($Process.MainWindowHandle) | Out-Null
    Start-Sleep -Milliseconds 500
}

function Get-TopWindows {
    return [System.Windows.Automation.AutomationElement]::RootElement.FindAll(
        [System.Windows.Automation.TreeScope]::Children,
        [System.Windows.Automation.Condition]::TrueCondition
    )
}

function Get-DialogForProcessId([int]$ProcessId) {
    foreach ($w in Get-TopWindows) {
        try {
            if ($w.Current.ProcessId -eq $ProcessId -and $w.Current.IsOffscreen -eq $false) {
                $class = $w.Current.ClassName
                $name = $w.Current.Name
                if ($class -eq '#32770' -or $name -match 'Save As|另存为|Save a copy|保存') {
                    return $w
                }
            }
        } catch {}
    }
    return $null
}

function Find-DescendantsByType($Root, $ControlType) {
    $cond = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        $ControlType
    )
    return $Root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)
}

function Invoke-Element($Element) {
    if (-not $Element) { return $false }
    $pattern = $null
    if ($Element.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) {
        $pattern.Invoke(); return $true
    }
    $pattern = $null
    if ($Element.TryGetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern, [ref]$pattern)) {
        $pattern.Select(); return $true
    }
    $r = $Element.Current.BoundingRectangle
    if ($r.Width -gt 2 -and $r.Height -gt 2) {
        [BismRobustPBIX]::SetCursorPos([int]($r.X + $r.Width/2), [int]($r.Y + $r.Height/2)) | Out-Null
        [BismRobustPBIX]::mouse_event(0x0002,0,0,0,[UIntPtr]::Zero)
        [BismRobustPBIX]::mouse_event(0x0004,0,0,0,[UIntPtr]::Zero)
        return $true
    }
    return $false
}

function Dismiss-WrongOverwritePrompt([int]$ProcessId) {
    foreach ($w in Get-TopWindows) {
        try {
            if ($w.Current.ProcessId -ne $ProcessId) { continue }
            $text = $w.Current.Name
            $allText = @()
            $txts = Find-DescendantsByType $w ([System.Windows.Automation.ControlType]::Text)
            foreach ($t in $txts) { if ($t.Current.Name) { $allText += $t.Current.Name } }
            $joined = (($text,($allText -join ' ')) -join ' ')
            if ($joined -match '\.pbip|already exists|已存在|替换|replace') {
                $buttons = Find-DescendantsByType $w ([System.Windows.Automation.ControlType]::Button)
                foreach ($b in $buttons) {
                    $n = $b.Current.Name
                    if ($n -match '^(No|否|取消|Cancel)$') {
                        Write-Host "Dismissing wrong/overwrite PBIP prompt with: $n" -ForegroundColor Yellow
                        Invoke-Element $b | Out-Null
                        Start-Sleep -Seconds 1
                        return $true
                    }
                }
                [System.Windows.Forms.SendKeys]::SendWait('{ESC}')
                Start-Sleep -Seconds 1
                return $true
            }
        } catch {}
    }
    return $false
}

function Select-PbixFileType($Dialog) {
    $combos = Find-DescendantsByType $Dialog ([System.Windows.Automation.ControlType]::ComboBox)
    foreach ($combo in $combos) {
        $expand = $null
        if ($combo.TryGetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$expand)) {
            try { $expand.Expand() } catch { continue }
            Start-Sleep -Milliseconds 400

            $items = Find-DescendantsByType ([System.Windows.Automation.AutomationElement]::RootElement) ([System.Windows.Automation.ControlType]::ListItem)
            foreach ($item in $items) {
                $name = $item.Current.Name
                if ($name -and $name -match '(?i)\.pbix') {
                    Write-Host "Selecting Save as type: $name" -ForegroundColor Cyan
                    if (Invoke-Element $item) {
                        Start-Sleep -Milliseconds 500
                        return $true
                    }
                }
            }
            try { $expand.Collapse() } catch {}
        }
    }
    return $false
}

function Set-Filename($Dialog, [string]$FullPath) {
    $edits = Find-DescendantsByType $Dialog ([System.Windows.Automation.ControlType]::Edit)
    $best = $null

    foreach ($e in $edits) {
        try {
            $id = $e.Current.AutomationId
            $name = $e.Current.Name
            $vp = $null
            if (-not $e.TryGetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern, [ref]$vp)) { continue }
            $val = $vp.Current.Value
            if ($id -eq '1001' -or $name -match 'File name|文件名|檔案名稱' -or $val -match '(?i)\.pbi(?:p|x)$|BISM2202_Seed') {
                $best = $e
                if ($id -eq '1001') { break }
            }
        } catch {}
    }

    if (-not $best -and $edits.Count -gt 0) {
        $best = $edits[$edits.Count - 1]
    }
    if (-not $best) { throw 'Could not locate editable file-name field in Save As dialog.' }

    $value = $null
    if (-not $best.TryGetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern, [ref]$value)) {
        throw 'File-name field does not support ValuePattern.'
    }

    $value.SetValue($FullPath)
    Write-Host "Save path set to: $FullPath" -ForegroundColor Cyan
}

function Invoke-Save($Dialog) {
    $buttons = Find-DescendantsByType $Dialog ([System.Windows.Automation.ControlType]::Button)
    foreach ($b in $buttons) {
        try {
            $id = $b.Current.AutomationId
            $name = $b.Current.Name
            if ($id -eq '1' -or $name -match '^(Save|保存|存储|儲存)$') {
                Write-Host "Invoking save button: $name" -ForegroundColor Cyan
                if (Invoke-Element $b) { return $true }
            }
        } catch {}
    }
    [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
    return $true
}

$process = Get-PowerBIProcess
Focus-Process $process

$output = Join-Path $ProjectRoot "PROJECT\BISM2202_OUTPUT\Version_${Version}\BISM2202_Assignment_${Version}.pbix"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $output) | Out-Null

if (Test-Path -LiteralPath $output) {
    $backupDir = Join-Path $env:TEMP 'BISM2202_PBIX_BACKUPS'
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    $backup = Join-Path $backupDir ("BISM2202_Assignment_${Version}.pbix.pre-save-" + (Get-Date -Format yyyyMMdd-HHmmss) + '.bak')
    Move-Item -LiteralPath $output -Destination $backup -Force
    Write-Host "Existing generated PBIX moved outside repo: $backup" -ForegroundColor DarkYellow
}

Dismiss-WrongOverwritePrompt $process.Id | Out-Null

$dialog = Get-DialogForProcessId $process.Id
if (-not $dialog) {
    Focus-Process $process
    [System.Windows.Forms.SendKeys]::SendWait('^+s')
    Start-Sleep -Seconds 3
    $dialog = Get-DialogForProcessId $process.Id
}

if (-not $dialog) {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($process.MainWindowHandle)
    $rect = $root.Current.BoundingRectangle
    [BismRobustPBIX]::SetCursorPos([int]($rect.X + 22),[int]($rect.Y + 52)) | Out-Null
    [BismRobustPBIX]::mouse_event(0x0002,0,0,0,[UIntPtr]::Zero)
    [BismRobustPBIX]::mouse_event(0x0004,0,0,0,[UIntPtr]::Zero)
    Start-Sleep -Seconds 2
    [BismRobustPBIX]::SetCursorPos([int]($rect.X + 75),[int]($rect.Y + 231)) | Out-Null
    [BismRobustPBIX]::mouse_event(0x0002,0,0,0,[UIntPtr]::Zero)
    [BismRobustPBIX]::mouse_event(0x0004,0,0,0,[UIntPtr]::Zero)
    Start-Sleep -Seconds 3
    [BismRobustPBIX]::SetCursorPos([int]($rect.X + 255),[int]($rect.Y + 360)) | Out-Null
    [BismRobustPBIX]::mouse_event(0x0002,0,0,0,[UIntPtr]::Zero)
    [BismRobustPBIX]::mouse_event(0x0004,0,0,0,[UIntPtr]::Zero)
    Start-Sleep -Seconds 3
    $dialog = Get-DialogForProcessId $process.Id
}

if (-not $dialog) { throw 'Save As dialog could not be found after both shortcut and File-menu fallback.' }

try { $dialog.SetFocus() } catch {}
Start-Sleep -Milliseconds 300

if (-not (Select-PbixFileType $dialog)) {
    throw 'Could not select a .pbix file type from the Save As dialog. No file was overwritten.'
}

Set-Filename $dialog $output
Invoke-Save $dialog | Out-Null

$deadline = (Get-Date).AddSeconds($WaitSeconds)
do {
    Dismiss-WrongOverwritePrompt $process.Id | Out-Null
    if ((Test-Path -LiteralPath $output) -and (Get-Item -LiteralPath $output).Length -gt 100000) { break }
    Start-Sleep -Seconds 1
} while ((Get-Date) -lt $deadline)

if (-not (Test-Path -LiteralPath $output)) {
    throw "PBIX was not created: $output"
}
$bytes = (Get-Item -LiteralPath $output).Length
if ($bytes -le 100000) {
    throw "PBIX exists but is suspiciously small: $bytes bytes"
}

Write-Host "ROBUST_PBIX_SAVE: PASS" -ForegroundColor Green
Write-Host "VERSION: $Version" -ForegroundColor Green
Write-Host "PBIX: $output" -ForegroundColor Green
Write-Host "PBIX_BYTES: $bytes" -ForegroundColor Green
