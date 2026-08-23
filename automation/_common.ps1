Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-BismRoot {
    if ($env:BISM2202_ROOT) { return [IO.Path]::GetFullPath($env:BISM2202_ROOT) }
    return [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
}

function Get-BismPython {
    $launcher = Get-Command py.exe -ErrorAction SilentlyContinue
    if ($launcher) { return @($launcher.Source, "-3.12") }
    $python = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($python) { return @($python.Source) }
    throw "Python 3.12 is not available. Run setup_windows.ps1 first."
}

function Invoke-BismPython {
    param([Parameter(Mandatory=$true)][string[]]$Arguments)
    $command = Get-BismPython
    $prefix = @()
    if ($command.Count -gt 1) { $prefix = @($command[1..($command.Count - 1)]) }
    & $command[0] @prefix @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Python failed with exit code $LASTEXITCODE." }
}

function Start-BismTranscript([string]$Name) {
    $logDir = Join-Path (Get-BismRoot) "automation\logs"
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $log = Join-Path $logDir "${Name}_${stamp}.log"
    Start-Transcript -LiteralPath $log -Append | Out-Null
    return $log
}

function Find-PowerBIExecutable {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Microsoft\Power BI Desktop\bin\PBIDesktop.exe"),
        (Join-Path $env:ProgramFiles "Microsoft Power BI Desktop\bin\PBIDesktop.exe")
    )
    if (${env:ProgramFiles(x86)}) {
        $candidates += (Join-Path ${env:ProgramFiles(x86)} "Microsoft Power BI Desktop\bin\PBIDesktop.exe")
    }
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $candidate }
    }
    $command = Get-Command PBIDesktop.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    return $null
}
