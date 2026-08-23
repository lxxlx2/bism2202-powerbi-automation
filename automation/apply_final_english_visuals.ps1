param(
    [ValidateSet("A", "B", "Both")][string]$Version = "A",
    [string]$ProjectRoot = "C:\BISM2202",
    [switch]$ForceClosePowerBI,
    [switch]$OpenAfter
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PowerBIExe = "C:\Program Files\Microsoft Power BI Desktop\bin\PBIDesktop.exe"

function Ensure-PbiCommand {
    if (Get-Command pbi -ErrorAction SilentlyContinue) { return }
    $scripts = py -3.12 -c "import sysconfig; print(sysconfig.get_path('scripts'))"
    if ($LASTEXITCODE -eq 0 -and $scripts) { $env:Path = "$env:Path;$scripts" }
    if (-not (Get-Command pbi -ErrorAction SilentlyContinue)) {
        throw "pbi command not found. Install pbi-cli-tool first."
    }
}

function Invoke-Pbi([string[]]$Arguments) {
    Write-Host ("pbi " + ($Arguments -join " ")) -ForegroundColor DarkGray
    & pbi @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "pbi command failed: pbi $($Arguments -join ' ')"
    }
}

function Close-PowerBIIfNeeded {
    $running = Get-Process PBIDesktop -ErrorAction SilentlyContinue
    if (-not $running) { return }
    if (-not $ForceClosePowerBI) {
        throw "Power BI Desktop is open. Save and close it, or rerun with -ForceClosePowerBI."
    }
    $running | Stop-Process -Force
    Start-Sleep -Seconds 3
}

function Literal-Bool([bool]$Value) {
    return [pscustomobject]@{ expr = [pscustomobject]@{ Literal = [pscustomobject]@{ Value = $(if ($Value) { "true" } else { "false" }) } } }
}

function Set-Property($Object, [string]$Name, $Value) {
    if ($null -eq $Object.PSObject.Properties[$Name]) {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    } else {
        $Object.$Name = $Value
    }
}

function Hide-Subtitle([string]$Report, [string]$Page, [string]$Visual) {
    $path = Join-Path $Report "definition\pages\$Page\visuals\$Visual\visual.json"
    if (-not (Test-Path -LiteralPath $path)) { return }
    $data = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ($null -eq $data.visual.PSObject.Properties['visualContainerObjects']) {
        Set-Property $data.visual 'visualContainerObjects' ([pscustomobject]@{})
    }
    $subtitle = [pscustomobject]@{ properties = [pscustomobject]@{ show = (Literal-Bool $false) } }
    Set-Property $data.visual.visualContainerObjects 'subTitle' @($subtitle)
    $data | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path -Encoding UTF8
}

function Remove-Visual([string]$Report, [string]$Page, [string]$Visual) {
    $folder = Join-Path $Report "definition\pages\$Page\visuals\$Visual"
    if (Test-Path -LiteralPath $folder) {
        Invoke-Pbi @('visual','-p',$Report,'--no-sync','delete',$Visual,'--page',$Page)
    }
}

function Add-Visual(
    [string]$Report, [string]$Page, [string]$Type, [string]$Name,
    [string]$Title, [string[]]$Bindings,
    [int]$X = 35, [int]$Y = 45, [int]$Width = 1210, [int]$Height = 620
) {
    Invoke-Pbi @('visual','-p',$Report,'--no-sync','add','--page',$Page,'--type',$Type,'--name',$Name,'--x',"$X",'--y',"$Y",'--width',"$Width",'--height',"$Height")
    $args = @('visual','-p',$Report,'--no-sync','bind',$Name,'--page',$Page) + $Bindings
    Invoke-Pbi $args
    Invoke-Pbi @('visual','-p',$Report,'--no-sync','set-container',$Name,'--page',$Page,'--title',$Title)
    Hide-Subtitle $Report $Page $Name
}

function Polish-Version([ValidateSet('A','B')][string]$Label) {
    $dir = Join-Path $ProjectRoot "PROJECT\Version_${Label}_PowerBI"
    $report = Join-Path $dir 'BISM2202_Seed.Report'
    $pbip = Join-Path $dir 'BISM2202_Seed.pbip'
    if (-not (Test-Path -LiteralPath $report)) { throw "Version $Label report not found: $report" }

    Write-Host "Applying English-safe final visuals to Version $Label..." -ForegroundColor Cyan

    foreach ($pair in @(
        @('q03','q03_chart'),
        @('q05','q05_chart'),
        @('q08','q08_chart'),
        @('q15','q15_chart')
    )) {
        Remove-Visual $report $pair[0] $pair[1]
    }

    if ($Label -eq 'A') {
        # Treemaps retain the part-to-whole meaning and avoid locale-generated donut centre totals.
        Add-Visual $report 'q03' 'treemap' 'q03_chart' 'Share of Orders by Pizza Size' @('--category','PizzaOrders[Pizza Size]','--value','PizzaOrders[Order Count]')
        Add-Visual $report 'q05' 'treemap' 'q05_chart' 'Share of Orders by Traffic Level' @('--category','PizzaOrders[Traffic Level]','--value','PizzaOrders[Order Count]')
        Add-Visual $report 'q08' 'clustered_column' 'q08_chart' 'Orders During Peak vs Non-Peak Hours' @('--category','PizzaOrders[Peak Hour Label]','--value','PizzaOrders[Order Count]')
        Add-Visual $report 'q15' 'clustered_bar' 'q15_chart' 'Order Proportion by Pizza Complexity' @('--category','PizzaOrders[Pizza Complexity]','--value','PizzaOrders[Order Count]')
    } else {
        # Version B deliberately uses alternative layouts so it is visually distinct from A.
        Add-Visual $report 'q03' 'clustered_column' 'q03_chart' 'Orders and Share Pattern by Pizza Size' @('--category','PizzaOrders[Pizza Size]','--value','PizzaOrders[Order Count]')
        Add-Visual $report 'q05' 'clustered_bar' 'q05_chart' 'Orders and Share Pattern by Traffic Level' @('--category','PizzaOrders[Traffic Level]','--value','PizzaOrders[Order Count]')
        Add-Visual $report 'q08' 'clustered_bar' 'q08_chart' 'Peak vs Non-Peak Order Volume' @('--category','PizzaOrders[Peak Hour Label]','--value','PizzaOrders[Order Count]')
        Add-Visual $report 'q15' 'treemap' 'q15_chart' 'Order Proportion by Pizza Complexity' @('--category','PizzaOrders[Pizza Complexity]','--value','PizzaOrders[Order Count]')
    }

    # Re-hide subtitles across all visuals so no locale-generated "by/按 ..." text leaks into final canvas captures.
    $visuals = Get-ChildItem -LiteralPath (Join-Path $report 'definition\pages') -Filter 'visual.json' -File -Recurse
    foreach ($vf in $visuals) {
        $data = Get-Content -LiteralPath $vf.FullName -Raw | ConvertFrom-Json
        if ($null -eq $data.PSObject.Properties['visual']) { continue }
        if ($null -eq $data.visual.PSObject.Properties['visualContainerObjects']) {
            Set-Property $data.visual 'visualContainerObjects' ([pscustomobject]@{})
        }
        $subtitle = [pscustomobject]@{ properties = [pscustomobject]@{ show = (Literal-Bool $false) } }
        Set-Property $data.visual.visualContainerObjects 'subTitle' @($subtitle)
        $data | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $vf.FullName -Encoding UTF8
    }

    Invoke-Pbi @('report','-p',$report,'validate')
    Write-Host "VERSION_${Label}_ENGLISH_VISUALS: PASS" -ForegroundColor Green
    return $pbip
}

Ensure-PbiCommand
Close-PowerBIIfNeeded
$labels = if ($Version -eq 'Both') { @('A','B') } else { @($Version) }
$pbips = @()
foreach ($label in $labels) { $pbips += Polish-Version $label }

Write-Host 'FINAL_ENGLISH_VISUAL_POLISH: PASS' -ForegroundColor Green
if ($OpenAfter -and $pbips.Count -gt 0) {
    Start-Process -FilePath $PowerBIExe -ArgumentList ('"' + $pbips[0] + '"')
}
