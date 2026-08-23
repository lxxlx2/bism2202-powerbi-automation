param(
    [ValidateSet("A", "B", "Both")][string]$Version = "A",
    [string]$ProjectRoot = "C:\BISM2202",
    [switch]$ForceClosePowerBI,
    [switch]$OpenAfter
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$PowerBIExe = "C:\Program Files\Microsoft Power BI Desktop\bin\PBIDesktop.exe"

function Assert-Path {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Label)
    if (-not (Test-Path -LiteralPath $Path)) { throw "$Label not found: $Path" }
}

function Ensure-PbiCommand {
    if (Get-Command pbi -ErrorAction SilentlyContinue) { return }
    $scripts = py -3.12 -c "import sysconfig; print(sysconfig.get_path('scripts'))"
    if ($LASTEXITCODE -eq 0 -and $scripts) { $env:Path = "$env:Path;$scripts" }
    if (-not (Get-Command pbi -ErrorAction SilentlyContinue)) {
        throw "pbi command not found. Run: py -3.12 -m pip install --upgrade pbi-cli-tool"
    }
}

function Invoke-Pbi {
    param([Parameter(Mandatory)][string[]]$Arguments, [switch]$AllowFailure)
    Write-Host ("pbi " + ($Arguments -join " ")) -ForegroundColor DarkGray
    & pbi @Arguments
    $code = $LASTEXITCODE
    if ($code -ne 0 -and -not $AllowFailure) {
        throw "pbi command failed with exit code ${code}: pbi $($Arguments -join ' ')"
    }
    return $code
}

function Close-PowerBIIfNeeded {
    $running = Get-Process PBIDesktop -ErrorAction SilentlyContinue
    if (-not $running) { return }
    if (-not $ForceClosePowerBI) {
        throw "Power BI Desktop is open. Save the current project, close all Power BI windows, or rerun with -ForceClosePowerBI."
    }
    Write-Host "Closing Power BI Desktop before PBIR repair..." -ForegroundColor Yellow
    $running | Stop-Process -Force
    Start-Sleep -Seconds 3
}

function Set-Property {
    param([Parameter(Mandatory)]$Object, [Parameter(Mandatory)][string]$Name, $Value)
    if ($null -eq $Object.PSObject.Properties[$Name]) {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    } else {
        $Object.$Name = $Value
    }
}

function Literal-Bool([bool]$Value) {
    return [pscustomobject]@{ expr = [pscustomobject]@{ Literal = [pscustomobject]@{ Value = $(if ($Value) { "true" } else { "false" }) } } }
}

function Literal-Number([string]$Value) {
    return [pscustomobject]@{ expr = [pscustomobject]@{ Literal = [pscustomobject]@{ Value = $Value } } }
}

function Read-VisualJson {
    param([string]$Report, [string]$Page, [string]$Visual)
    $path = Join-Path $Report "definition\pages\$Page\visuals\$Visual\visual.json"
    Assert-Path -Path $path -Label "Visual JSON $Page/$Visual"
    return @{ Path = $path; Data = (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json) }
}

function Write-VisualJson {
    param([string]$Path, $Data)
    $Data | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $Path -Encoding utf8
}

function Hide-AutoSubtitle {
    param([string]$Report, [string]$Page, [string]$Visual)
    $pair = Read-VisualJson -Report $Report -Page $Page -Visual $Visual
    $data = $pair.Data
    if ($null -eq $data.visual.PSObject.Properties['visualContainerObjects']) {
        Set-Property -Object $data.visual -Name 'visualContainerObjects' -Value ([pscustomobject]@{})
    }
    $subtitle = [pscustomobject]@{
        properties = [pscustomobject]@{
            show = (Literal-Bool $false)
        }
    }
    Set-Property -Object $data.visual.visualContainerObjects -Name 'subTitle' -Value @($subtitle)
    Write-VisualJson -Path $pair.Path -Data $data
}

function Set-DonutFullNumbers {
    param([string]$Report, [string]$Page, [string]$Visual)
    $pair = Read-VisualJson -Report $Report -Page $Page -Visual $Visual
    $data = $pair.Data
    if ($null -eq $data.visual.PSObject.Properties['objects']) {
        Set-Property -Object $data.visual -Name 'objects' -Value ([pscustomobject]@{})
    }
    $labels = [pscustomobject]@{
        properties = [pscustomobject]@{
            show = (Literal-Bool $true)
            labelDisplayUnits = (Literal-Number '1D')
            labelPrecision = (Literal-Number '0L')
        }
    }
    Set-Property -Object $data.visual.objects -Name 'labels' -Value @($labels)
    Write-VisualJson -Path $pair.Path -Data $data
}

function Hide-MatrixGrandTotal {
    param([string]$Report, [string]$Page, [string]$Visual)
    $pair = Read-VisualJson -Report $Report -Page $Page -Visual $Visual
    $data = $pair.Data
    if ($null -eq $data.visual.PSObject.Properties['objects']) {
        Set-Property -Object $data.visual -Name 'objects' -Value ([pscustomobject]@{})
    }
    $rowTotal = [pscustomobject]@{
        properties = [pscustomobject]@{
            show = (Literal-Bool $false)
        }
    }
    Set-Property -Object $data.visual.objects -Name 'rowTotal' -Value @($rowTotal)
    Write-VisualJson -Path $pair.Path -Data $data
}

function Patch-SlicerAsColumn {
    param([string]$Report, [string]$Page, [string]$Visual, [string]$Column)
    $pair = Read-VisualJson -Report $Report -Page $Page -Visual $Visual
    $data = $pair.Data
    $projection = [pscustomobject]@{
        field = [pscustomobject]@{
            Column = [pscustomobject]@{
                Expression = [pscustomobject]@{
                    SourceRef = [pscustomobject]@{ Entity = 'PizzaOrders' }
                }
                Property = $Column
            }
        }
        queryRef = "PizzaOrders.$Column"
        nativeQueryRef = $Column
        active = $true
    }
    $values = [pscustomobject]@{ projections = @($projection) }
    Set-Property -Object $data.visual.query.queryState -Name 'Values' -Value $values
    Write-VisualJson -Path $pair.Path -Data $data
}

function Set-MeasureSort {
    param([string]$Report, [string]$Page, [string]$Visual, [string]$Measure, [ValidateSet('Ascending','Descending')][string]$Direction)
    $pair = Read-VisualJson -Report $Report -Page $Page -Visual $Visual
    $data = $pair.Data
    $sort = [pscustomobject]@{
        sort = @(
            [pscustomobject]@{
                field = [pscustomobject]@{
                    Measure = [pscustomobject]@{
                        Expression = [pscustomobject]@{
                            SourceRef = [pscustomobject]@{ Entity = 'PizzaOrders' }
                        }
                        Property = $Measure
                    }
                }
                direction = $Direction
            }
        )
        isDefaultSort = $true
    }
    Set-Property -Object $data.visual.query -Name 'sortDefinition' -Value $sort
    Write-VisualJson -Path $pair.Path -Data $data
}

function Remove-VisualIfPresent {
    param([string]$Report, [string]$Page, [string]$Visual)
    $path = Join-Path $Report "definition\pages\$Page\visuals\$Visual"
    if (Test-Path -LiteralPath $path) {
        Invoke-Pbi -Arguments @('visual','-p',$Report,'--no-sync','delete',$Visual,'--page',$Page) | Out-Null
    }
}

function Add-StandardVisual {
    param(
        [string]$Report, [string]$Page, [string]$Type, [string]$Name, [string]$Title,
        [string[]]$Bindings, [int]$X, [int]$Y, [int]$Width, [int]$Height
    )
    Invoke-Pbi -Arguments @('visual','-p',$Report,'--no-sync','add','--page',$Page,'--type',$Type,'--name',$Name,'--x',"$X",'--y',"$Y",'--width',"$Width",'--height',"$Height") | Out-Null
    $bind = @('visual','-p',$Report,'--no-sync','bind',$Name,'--page',$Page) + $Bindings
    Invoke-Pbi -Arguments $bind | Out-Null
    Invoke-Pbi -Arguments @('visual','-p',$Report,'--no-sync','set-container',$Name,'--page',$Page,'--title',$Title) | Out-Null
    Hide-AutoSubtitle -Report $Report -Page $Page -Visual $Name
}

function Repair-Version {
    param([ValidateSet('A','B')][string]$Label)

    $target = Join-Path $ProjectRoot "PROJECT\Version_${Label}_PowerBI"
    $report = Join-Path $target 'BISM2202_Seed.Report'
    $pbip = Join-Path $target 'BISM2202_Seed.pbip'
    Assert-Path -Path $report -Label "Version $Label report"
    Assert-Path -Path $pbip -Label "Version $Label PBIP"

    Write-Host "Repairing Version $Label..." -ForegroundColor Cyan

    # Q17: use two reliable native visuals side-by-side instead of the broken combo template.
    Remove-VisualIfPresent -Report $report -Page 'q17' -Visual 'q17_combo'
    Remove-VisualIfPresent -Report $report -Page 'q17' -Visual 'q17_volume'
    Remove-VisualIfPresent -Report $report -Page 'q17' -Visual 'q17_delay'
    Add-StandardVisual -Report $report -Page 'q17' -Type 'clustered_column' -Name 'q17_volume' -Title 'Order Volume by Order Hour' -Bindings @('--category','PizzaOrders[Order Hour]','--value','PizzaOrders[Order Count]') -X 25 -Y 55 -Width 600 -Height 600
    Add-StandardVisual -Report $report -Page 'q17' -Type 'line' -Name 'q17_delay' -Title 'Average Delay by Order Hour' -Bindings @('--category','PizzaOrders[Order Hour]','--value','PizzaOrders[Avg Delay]') -X 650 -Y 55 -Width 600 -Height 600

    # Q18: two native visuals show both required metrics clearly and reliably.
    Remove-VisualIfPresent -Report $report -Page 'q18' -Visual 'q18_combo'
    Remove-VisualIfPresent -Report $report -Page 'q18' -Visual 'q18_volume'
    Remove-VisualIfPresent -Report $report -Page 'q18' -Visual 'q18_density'
    Add-StandardVisual -Report $report -Page 'q18' -Type 'clustered_column' -Name 'q18_volume' -Title 'Order Volume by Pizza Type' -Bindings @('--category','PizzaOrders[Pizza Type]','--value','PizzaOrders[Order Count]') -X 25 -Y 55 -Width 600 -Height 600
    Add-StandardVisual -Report $report -Page 'q18' -Type 'line' -Name 'q18_density' -Title 'Average Topping Density by Pizza Type' -Bindings @('--category','PizzaOrders[Pizza Type]','--value','PizzaOrders[Avg Topping Density]') -X 650 -Y 55 -Width 600 -Height 600

    # Q19: replace unsupported stackedBarChart custom-visual interpretation with native barChart.
    Remove-VisualIfPresent -Report $report -Page 'q19' -Visual 'q19_stack'
    Remove-VisualIfPresent -Report $report -Page 'q19' -Visual 'q19_time_slicer'
    Add-StandardVisual -Report $report -Page 'q19' -Type 'bar' -Name 'q19_stack' -Title 'Traffic-Level Percentage Breakdown within Payment Method' -Bindings @('--category','PizzaOrders[Payment Method]','--value','PizzaOrders[Order Share Within Payment]','--legend','PizzaOrders[Traffic Level]') -X 25 -Y 175 -Width 1225 -Height 500
    Invoke-Pbi -Arguments @('visual','-p',$report,'--no-sync','add','--page','q19','--type','slicer','--name','q19_time_slicer','--x','915','--y','25','--width','335','--height','125') | Out-Null
    Invoke-Pbi -Arguments @('visual','-p',$report,'--no-sync','set-container','q19_time_slicer','--page','q19','--title','Filter by Order Time') | Out-Null
    Patch-SlicerAsColumn -Report $report -Page 'q19' -Visual 'q19_time_slicer' -Column 'Order Time'
    Hide-AutoSubtitle -Report $report -Page 'q19' -Visual 'q19_time_slicer'

    # Q20: keep three different native visual types: matrix, column, line.
    Remove-VisualIfPresent -Report $report -Page 'q20' -Visual 'q20_hourly'
    Remove-VisualIfPresent -Report $report -Page 'q20' -Visual 'q20_hourly_line'
    Add-StandardVisual -Report $report -Page 'q20' -Type 'line' -Name 'q20_hourly_line' -Title 'Order Volume by Order Hour' -Bindings @('--category','PizzaOrders[Order Hour]','--value','PizzaOrders[Order Count]') -X 25 -Y 360 -Width 1225 -Height 325

    # Remove locale-generated subtitles from every visual on all 20 pages.
    $visualFiles = Get-ChildItem -LiteralPath (Join-Path $report 'definition\pages') -Filter 'visual.json' -File -Recurse
    foreach ($vf in $visualFiles) {
        $data = Get-Content -LiteralPath $vf.FullName -Raw | ConvertFrom-Json
        if ($null -eq $data.PSObject.Properties['visual']) { continue }
        if ($null -eq $data.visual.PSObject.Properties['visualContainerObjects']) {
            Set-Property -Object $data.visual -Name 'visualContainerObjects' -Value ([pscustomobject]@{})
        }
        $subtitle = [pscustomobject]@{ properties = [pscustomobject]@{ show = (Literal-Bool $false) } }
        Set-Property -Object $data.visual.visualContainerObjects -Name 'subTitle' -Value @($subtitle)
        Write-VisualJson -Path $vf.FullName -Data $data
    }

    # Donut charts: full numeric units, no locale abbreviation such as Chinese 'thousand'.
    foreach ($item in @(@('q03','q03_chart'), @('q05','q05_chart'), @('q08','q08_chart'), @('q15','q15_chart'))) {
        Set-DonutFullNumbers -Report $report -Page $item[0] -Visual $item[1]
    }

    # Remove matrix grand total row so Chinese locale cannot inject a localized 'Total' label into final screenshots.
    Hide-MatrixGrandTotal -Report $report -Page 'q16' -Visual 'q16_matrix'
    Hide-MatrixGrandTotal -Report $report -Page 'q20' -Visual 'q20_restaurant'

    # Explicit final sorting for ranked visuals.
    Set-MeasureSort -Report $report -Page 'q01' -Visual 'q01_chart' -Measure 'Order Count' -Direction 'Descending'
    Set-MeasureSort -Report $report -Page 'q07' -Visual 'q07_chart' -Measure 'Avg Delivery Duration' -Direction 'Descending'
    Set-MeasureSort -Report $report -Page 'q11' -Visual 'q11_chart' -Measure 'Avg Delay' -Direction 'Ascending'
    Set-MeasureSort -Report $report -Page 'q12' -Visual 'q12_chart' -Measure 'Avg Delivery Duration' -Direction 'Descending'

    Write-Host "Validating repaired Version $Label PBIR..." -ForegroundColor Cyan
    Invoke-Pbi -Arguments @('report','-p',$report,'validate') | Out-Null
    Write-Host "VERSION_${Label}_FINAL_VISUAL_REPAIR: PASS" -ForegroundColor Green
    return $pbip
}

Ensure-PbiCommand
Close-PowerBIIfNeeded
$labels = if ($Version -eq 'Both') { @('A','B') } else { @($Version) }
$pbips = @()
foreach ($label in $labels) { $pbips += Repair-Version -Label $label }

Write-Host 'FINAL_VISUAL_REPAIR: PASS' -ForegroundColor Green
if ($OpenAfter -and $pbips.Count -gt 0) {
    Assert-Path -Path $PowerBIExe -Label 'Power BI Desktop'
    Start-Process -FilePath $PowerBIExe -ArgumentList ('"' + $pbips[0] + '"')
}
