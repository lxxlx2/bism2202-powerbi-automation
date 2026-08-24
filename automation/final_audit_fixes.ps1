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
    & pbi @Arguments | Out-Host
    $code = $LASTEXITCODE
    if ($code -ne 0) { throw "pbi command failed with exit code ${code}: pbi $($Arguments -join ' ')" }
}

function Close-PowerBIIfNeeded {
    $running = Get-Process PBIDesktop -ErrorAction SilentlyContinue
    if (-not $running) { return }
    if (-not $ForceClosePowerBI) {
        throw "Power BI Desktop is open. Save and close it, or rerun with -ForceClosePowerBI."
    }
    Write-Host "Closing Power BI Desktop before audited offline fixes..." -ForegroundColor Yellow
    $running | Stop-Process -Force
    Start-Sleep -Seconds 3
}

function Literal-Bool([bool]$Value) {
    return [pscustomobject]@{ expr = [pscustomobject]@{ Literal = [pscustomobject]@{ Value = $(if ($Value) { "true" } else { "false" }) } } }
}

function Literal-Text([string]$Value) {
    return [pscustomobject]@{ expr = [pscustomobject]@{ Literal = [pscustomobject]@{ Value = "'$Value'" } } }
}

function Set-Property($Object, [string]$Name, $Value) {
    if ($null -eq $Object.PSObject.Properties[$Name]) {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    } else {
        $Object.$Name = $Value
    }
}

function Read-Json([string]$Path) {
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-Json([string]$Path, $Data) {
    $Data | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Ensure-TmdlObject {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][ValidateSet('measure','column')][string]$Kind,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Block
    )
    $text = [System.IO.File]::ReadAllText($Path)
    $escaped = [regex]::Escape($Name)
    $pattern = if ($Kind -eq 'measure') {
        "(?m)^\s*measure\s+(?:'$escaped'|$escaped)\s*="
    } else {
        "(?m)^\s*column\s+(?:'$escaped'|$escaped)\s*="
    }
    if ([regex]::IsMatch($text, $pattern)) {
        Write-Host "$Kind exists: $Name" -ForegroundColor DarkGray
        return
    }
    $partitionPattern = "(?m)^\tpartition\s+PizzaOrders\s*=\s*m\s*$"
    $match = [regex]::Match($text, $partitionPattern)
    if (-not $match.Success) { throw "Could not find PizzaOrders partition in $Path" }
    $insert = $Block.TrimEnd() + "`r`n`r`n"
    $text = $text.Insert($match.Index, $insert)
    [System.IO.File]::WriteAllText($Path, $text, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Added ${Kind}: $Name" -ForegroundColor Green
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
}

function Set-ChartFormatting {
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$ShowLabels,
        [string]$DefaultColor,
        [switch]$HideSubtitle
    )
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $data = Read-Json $Path

    if ($HideSubtitle) {
        if ($null -eq $data.visual.PSObject.Properties['visualContainerObjects']) {
            Set-Property $data.visual 'visualContainerObjects' ([pscustomobject]@{})
        }
        $subtitle = [pscustomobject]@{ properties = [pscustomobject]@{ show = (Literal-Bool $false) } }
        Set-Property $data.visual.visualContainerObjects 'subTitle' @($subtitle)
    }

    if ($ShowLabels -or $DefaultColor) {
        if ($null -eq $data.visual.PSObject.Properties['objects']) {
            Set-Property $data.visual 'objects' ([pscustomobject]@{})
        }
    }

    if ($ShowLabels) {
        $labelProps = [pscustomobject]@{
            show = (Literal-Bool $true)
            labelDisplayUnits = [pscustomobject]@{ expr = [pscustomobject]@{ Literal = [pscustomobject]@{ Value = '0D' } } }
            labelPrecision = [pscustomobject]@{ expr = [pscustomobject]@{ Literal = [pscustomobject]@{ Value = '2D' } } }
        }
        Set-Property $data.visual.objects 'labels' @([pscustomobject]@{ properties = $labelProps })
    }

    if ($DefaultColor) {
        $dataPoint = [pscustomobject]@{
            properties = [pscustomobject]@{
                defaultColor = [pscustomobject]@{ solid = [pscustomobject]@{ color = $DefaultColor } }
            }
        }
        Set-Property $data.visual.objects 'dataPoint' @($dataPoint)
    }

    Write-Json $Path $data
}

function Ensure-MatrixEnglishTotals([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "Matrix JSON missing: $Path" }
    $data = Read-Json $Path
    if ($null -eq $data.visual.PSObject.Properties['objects']) {
        Set-Property $data.visual 'objects' ([pscustomobject]@{})
    }
    $on = @([pscustomobject]@{ properties = [pscustomobject]@{ show = (Literal-Bool $true) } })
    $labels = @([pscustomobject]@{ properties = [pscustomobject]@{
        rowSubtotalsLabel = [pscustomobject]@{ expr = [pscustomobject]@{ Literal = [pscustomobject]@{ Value = "'Total'" } } }
        columnSubtotalsLabel = [pscustomobject]@{ expr = [pscustomobject]@{ Literal = [pscustomobject]@{ Value = "'Total'" } } }
    } })
    Set-Property $data.visual.objects 'rowTotal' $on
    Set-Property $data.visual.objects 'columnTotal' $on
    Set-Property $data.visual.objects 'subTotals' $labels
    Write-Json $Path $data
}

function Add-SortByMeasure([string]$Path, [string]$Measure, [ValidateSet('Ascending','Descending')][string]$Direction = 'Descending') {
    $data = Read-Json $Path
    $sort = [pscustomobject]@{
        sort = @([pscustomobject]@{
            field = [pscustomobject]@{
                Measure = [pscustomobject]@{
                    Expression = [pscustomobject]@{ SourceRef = [pscustomobject]@{ Entity = 'PizzaOrders' } }
                    Property = $Measure
                }
            }
            direction = $Direction
        })
        isDefaultSort = $true
    }
    Set-Property $data.visual.query 'sortDefinition' $sort
    Write-Json $Path $data
}

function Add-SortByColumn([string]$Path, [string]$Column, [ValidateSet('Ascending','Descending')][string]$Direction = 'Ascending') {
    $data = Read-Json $Path
    $sort = [pscustomobject]@{
        sort = @([pscustomobject]@{
            field = [pscustomobject]@{
                Column = [pscustomobject]@{
                    Expression = [pscustomobject]@{ SourceRef = [pscustomobject]@{ Entity = 'PizzaOrders' } }
                    Property = $Column
                }
            }
            direction = $Direction
        })
        isDefaultSort = $true
    }
    Set-Property $data.visual.query 'sortDefinition' $sort
    Write-Json $Path $data
}

function Polish-AllSubtitles([string]$Report) {
    $visuals = Get-ChildItem -LiteralPath (Join-Path $Report 'definition\pages') -Filter 'visual.json' -File -Recurse
    foreach ($vf in $visuals) {
        Set-ChartFormatting -Path $vf.FullName -HideSubtitle
    }
}

function Fix-Version([ValidateSet('A','B')][string]$Label) {
    $dir = Join-Path $ProjectRoot "PROJECT\Version_${Label}_PowerBI"
    $report = Join-Path $dir 'BISM2202_Seed.Report'
    $pbip = Join-Path $dir 'BISM2202_Seed.pbip'
    $tmdl = Join-Path $dir 'BISM2202_Seed.SemanticModel\definition\tables\PizzaOrders.tmdl'
    foreach ($path in @($report,$pbip,$tmdl)) {
        if (-not (Test-Path -LiteralPath $path)) { throw "Version $Label required path missing: $path" }
    }

    Write-Host "Applying final audit fixes to Version $Label..." -ForegroundColor Cyan

    Ensure-TmdlObject -Path $tmdl -Kind measure -Name 'Order Share Overall' -Block @"
`tmeasure 'Order Share Overall' = DIVIDE([Order Count], CALCULATE([Order Count], REMOVEFILTERS(PizzaOrders)))
`t`tformatString: 0.00%
`t`tdisplayFolder: BISM2202 Measures
"@

    Ensure-TmdlObject -Path $tmdl -Kind column -Name 'Order Month-Year' -Block @"
`tcolumn 'Order Month-Year' = FORMAT(PizzaOrders[Order Time], "yyyy-MM")
`t`tdataType: string
`t`tsummarizeBy: none
"@

    foreach ($pair in @(@('q03','q03_chart'),@('q05','q05_chart'),@('q09','q09_chart'),@('q15','q15_chart'))) {
        Remove-Visual $report $pair[0] $pair[1]
    }

    if ($Label -eq 'A') {
        Add-Visual $report 'q03' 'clustered_column' 'q03_chart' 'Share of Orders by Pizza Size' @('--category','PizzaOrders[Pizza Size]','--value','PizzaOrders[Order Share Overall]')
        Add-Visual $report 'q05' 'clustered_bar' 'q05_chart' 'Share of Orders by Traffic Level' @('--category','PizzaOrders[Traffic Level]','--value','PizzaOrders[Order Share Overall]')
        Add-Visual $report 'q09' 'line' 'q09_chart' 'Order Volume Trend by Month-Year' @('--category','PizzaOrders[Order Month-Year]','--value','PizzaOrders[Order Count]')
        Add-Visual $report 'q15' 'clustered_bar' 'q15_chart' 'Order Proportion by Pizza Complexity' @('--category','PizzaOrders[Pizza Complexity]','--value','PizzaOrders[Order Share Overall]')
    } else {
        Add-Visual $report 'q03' 'clustered_bar' 'q03_chart' 'Share of Orders by Pizza Size' @('--category','PizzaOrders[Pizza Size]','--value','PizzaOrders[Order Share Overall]')
        Add-Visual $report 'q05' 'clustered_column' 'q05_chart' 'Share of Orders by Traffic Level' @('--category','PizzaOrders[Traffic Level]','--value','PizzaOrders[Order Share Overall]')
        Add-Visual $report 'q09' 'clustered_column' 'q09_chart' 'Order Volume by Month-Year' @('--category','PizzaOrders[Order Month-Year]','--value','PizzaOrders[Order Count]')
        Add-Visual $report 'q15' 'clustered_column' 'q15_chart' 'Order Proportion by Pizza Complexity' @('--category','PizzaOrders[Pizza Complexity]','--value','PizzaOrders[Order Share Overall]')
    }

    foreach ($item in @(
        @('q03','q03_chart','Order Share Overall'),
        @('q05','q05_chart','Order Share Overall')
    )) {
        $p = Join-Path $report "definition\pages\$($item[0])\visuals\$($item[1])\visual.json"
        Set-ChartFormatting -Path $p -ShowLabels -HideSubtitle
        Add-SortByMeasure -Path $p -Measure $item[2] -Direction Descending
    }

    $q15Path = Join-Path $report 'definition\pages\q15\visuals\q15_chart\visual.json'
    Set-ChartFormatting -Path $q15Path -ShowLabels -HideSubtitle

    $q09Path = Join-Path $report 'definition\pages\q09\visuals\q09_chart\visual.json'
    Set-ChartFormatting -Path $q09Path -HideSubtitle
    Add-SortByColumn -Path $q09Path -Column 'Order Month-Year' -Direction Ascending

    foreach ($hourVisual in @(
        @('q13','q13_chart'),
        @('q17','q17_volume'),
        @('q17','q17_delay'),
        @('q20','q20_hourly_line')
    )) {
        Add-SortByColumn -Path (Join-Path $report "definition\pages\$($hourVisual[0])\visuals\$($hourVisual[1])\visual.json") -Column 'Order Hour' -Direction Ascending
    }

    Ensure-MatrixEnglishTotals (Join-Path $report 'definition\pages\q16\visuals\q16_matrix\visual.json')
    Ensure-MatrixEnglishTotals (Join-Path $report 'definition\pages\q19\visuals\q19_stack\visual.json')
    Ensure-MatrixEnglishTotals (Join-Path $report 'definition\pages\q20\visuals\q20_restaurant\visual.json')

    # Q20 uses three different visual types. Keep matrix conditional colors and make
    # the other two views visibly distinct so the dashboard clearly satisfies the
    # assignment's conditional-formatting / different-colors requirement.
    # Per-category High/Low/Medium colors are stored directly in the PBIR
    # dataPoint selectors. Do not replace them with one default series color.
    Set-ChartFormatting -Path (Join-Path $report 'definition\pages\q20\visuals\q20_traffic\visual.json') -HideSubtitle
    Set-ChartFormatting -Path (Join-Path $report 'definition\pages\q20\visuals\q20_hourly_line\visual.json') -HideSubtitle

    Polish-AllSubtitles $report
    Invoke-Pbi @('report','-p',$report,'validate')

    Write-Host "VERSION_${Label}_FINAL_AUDIT_FIXES: PASS" -ForegroundColor Green
    return $pbip
}

Ensure-PbiCommand
Close-PowerBIIfNeeded
$labels = if ($Version -eq 'Both') { @('A','B') } else { @($Version) }
$pbips = @()
foreach ($label in $labels) { $pbips += @(Fix-Version $label) }

Write-Host 'FINAL_AUDIT_FIXES: PASS' -ForegroundColor Green
if ($OpenAfter -and $pbips.Count -gt 0) {
    $openPath = [string]$pbips[0]
    if (-not (Test-Path -LiteralPath $openPath)) { throw "PBIP to open does not exist: $openPath" }
    Write-Host "Opening audited report: $openPath" -ForegroundColor Cyan
    Start-Process -FilePath $PowerBIExe -ArgumentList @($openPath)
}
