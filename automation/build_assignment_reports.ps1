param(
    [ValidateSet("A", "B", "Both")][string]$Version = "A",
    [string]$ProjectRoot = "C:\BISM2202",
    [switch]$ForceClosePowerBI,
    [switch]$ForceRebuild,
    [switch]$OpenAfter
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$SeedDir = Join-Path $ProjectRoot "PROJECT\Seed"
$SeedPbip = Join-Path $SeedDir "BISM2202_Seed.pbip"
$Bootstrap = Join-Path $ProjectRoot "automation\model_bootstrap.ps1"
$PowerBIExe = "C:\Program Files\Microsoft Power BI Desktop\bin\PBIDesktop.exe"

function Assert-Path {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Label)
    if (-not (Test-Path $Path)) { throw "$Label not found: $Path" }
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
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$AllowFailure
    )
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
        throw "Power BI Desktop is open. Save it, close all Power BI windows, or rerun with -ForceClosePowerBI."
    }
    Write-Host "Closing Power BI Desktop before offline PBIR build..." -ForegroundColor Yellow
    $running | Stop-Process -Force
    Start-Sleep -Seconds 3
}

function Add-Visual {
    param(
        [Parameter(Mandatory)][string]$Report,
        [Parameter(Mandatory)][string]$Page,
        [Parameter(Mandatory)][string]$Type,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string[]]$Bindings,
        [int]$X = 35,
        [int]$Y = 45,
        [int]$Width = 1210,
        [int]$Height = 620
    )

    Invoke-Pbi -Arguments @(
        "visual", "-p", $Report, "--no-sync", "add",
        "--page", $Page, "--type", $Type, "--name", $Name,
        "--x", "$X", "--y", "$Y", "--width", "$Width", "--height", "$Height"
    ) | Out-Null

    $bind = @("visual", "-p", $Report, "--no-sync", "bind", $Name, "--page", $Page) + $Bindings
    Invoke-Pbi -Arguments $bind | Out-Null

    Invoke-Pbi -Arguments @(
        "visual", "-p", $Report, "--no-sync", "set-container", $Name,
        "--page", $Page, "--title", $Title
    ) | Out-Null
}

function Add-ComboVisual {
    param(
        [Parameter(Mandatory)][string]$Report,
        [Parameter(Mandatory)][string]$Page,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$ColumnMeasure,
        [Parameter(Mandatory)][string]$LineMeasure,
        [int]$X = 35,
        [int]$Y = 45,
        [int]$Width = 1210,
        [int]$Height = 620
    )

    Invoke-Pbi -Arguments @(
        "visual", "-p", $Report, "--no-sync", "add",
        "--page", $Page, "--type", "combo", "--name", $Name,
        "--x", "$X", "--y", "$Y", "--width", "$Width", "--height", "$Height"
    ) | Out-Null

    Invoke-Pbi -Arguments @(
        "visual", "-p", $Report, "--no-sync", "bulk-bind",
        "--page", $Page, "--type", "lineStackedColumnComboChart", "--name-pattern", $Name,
        "--category", $Category, "--column", $ColumnMeasure, "--line", $LineMeasure
    ) | Out-Null

    Invoke-Pbi -Arguments @(
        "visual", "-p", $Report, "--no-sync", "set-container", $Name,
        "--page", $Page, "--title", $Title
    ) | Out-Null
}

function Add-TopNFilter {
    param(
        [Parameter(Mandatory)][string]$Report,
        [Parameter(Mandatory)][string]$Page,
        [Parameter(Mandatory)][string]$Visual,
        [Parameter(Mandatory)][string]$Column,
        [Parameter(Mandatory)][int]$N,
        [Parameter(Mandatory)][string]$OrderByColumn,
        [ValidateSet("Top", "Bottom")][string]$Direction = "Top"
    )

    Invoke-Pbi -Arguments @(
        "filters", "-p", $Report, "--no-sync", "add-topn",
        "--page", $Page, "--visual", $Visual,
        "--table", "PizzaOrders", "--column", $Column,
        "--n", "$N", "--order-by-table", "PizzaOrders",
        "--order-by-column", $OrderByColumn, "--direction", $Direction
    ) | Out-Null
}

function Add-Q16Formatting {
    param([string]$Report, [string]$Page, [string]$Visual)

    $code1 = Invoke-Pbi -Arguments @(
        "format", "--report-path", $Report, "background-measure", $Visual,
        "--page", $Page, "--measure-table", "PizzaOrders",
        "--measure-property", "Delivery Duration Color",
        "--field", "PizzaOrders.Avg Delivery Duration"
    ) -AllowFailure

    $code2 = Invoke-Pbi -Arguments @(
        "format", "--report-path", $Report, "background-measure", $Visual,
        "--page", $Page, "--measure-table", "PizzaOrders",
        "--measure-property", "Delay Color",
        "--field", "PizzaOrders.Avg Delay"
    ) -AllowFailure

    if ($code1 -ne 0 -or $code2 -ne 0) {
        Write-Warning "Conditional-format command was not accepted by this pbi-cli build. The matrix itself was created; formatting can be patched after the first Desktop render."
    }
}

function Build-Version {
    param([ValidateSet("A", "B")][string]$Label)

    $target = Join-Path $ProjectRoot "PROJECT\Version_${Label}_PowerBI"
    if (Test-Path $target) {
        if (-not $ForceRebuild) {
            throw "$target already exists. Rerun with -ForceRebuild to replace it."
        }
        Remove-Item -LiteralPath $target -Recurse -Force
    }

    Write-Host "Copying Seed to Version $Label..." -ForegroundColor Cyan
    Copy-Item -LiteralPath $SeedDir -Destination $target -Recurse

    $report = Join-Path $target "BISM2202_Seed.Report"
    $pbip = Join-Path $target "BISM2202_Seed.pbip"
    Assert-Path -Path $report -Label "Version $Label report"
    Assert-Path -Path $pbip -Label "Version $Label PBIP"

    $pagesJson = Join-Path $report "definition\pages\pages.json"
    $pageMeta = Get-Content -LiteralPath $pagesJson -Raw | ConvertFrom-Json
    foreach ($oldPage in @($pageMeta.pageOrder)) {
        Invoke-Pbi -Arguments @("report", "-p", $report, "--no-sync", "delete-page", "$oldPage") | Out-Null
    }

    $background = if ($Label -eq "A") { "#F7F9FC" } else { "#FFFDF6" }

    for ($i = 1; $i -le 20; $i++) {
        $pageId = "q{0:D2}" -f $i
        $display = "Q{0:D2}" -f $i
        Invoke-Pbi -Arguments @(
            "report", "-p", $report, "--no-sync", "add-page",
            "--display-name", $display, "--name", $pageId, "--width", "1280", "--height", "720"
        ) | Out-Null
        Invoke-Pbi -Arguments @(
            "report", "-p", $report, "--no-sync", "set-background", $pageId,
            "--color", $background, "--transparency", "0"
        ) | Out-Null
    }

    Add-Visual -Report $report -Page "q01" -Type "clustered_bar" -Name "q01_chart" -Title "Top 20 Locations by Order Count" -Bindings @("--category", "PizzaOrders[Location]", "--value", "PizzaOrders[Order Count]")
    Add-TopNFilter -Report $report -Page "q01" -Visual "q01_chart" -Column "Location" -N 20 -OrderByColumn "__OrderOne" -Direction Top

    Add-Visual -Report $report -Page "q02" -Type "clustered_column" -Name "q02_chart" -Title "Average Delivery Duration by Pizza Size" -Bindings @("--category", "PizzaOrders[Pizza Size]", "--value", "PizzaOrders[Avg Delivery Duration]")

    Add-Visual -Report $report -Page "q03" -Type "donut" -Name "q03_chart" -Title "Share of Orders by Pizza Size" -Bindings @("--category", "PizzaOrders[Pizza Size]", "--value", "PizzaOrders[Order Count]")

    Add-Visual -Report $report -Page "q04" -Type "clustered_bar" -Name "q04_chart" -Title "Orders by Payment Method" -Bindings @("--category", "PizzaOrders[Payment Method]", "--value", "PizzaOrders[Order Count]")

    Add-Visual -Report $report -Page "q05" -Type "donut" -Name "q05_chart" -Title "Share of Orders by Traffic Level" -Bindings @("--category", "PizzaOrders[Traffic Level]", "--value", "PizzaOrders[Order Count]")

    Add-Visual -Report $report -Page "q06" -Type "clustered_column" -Name "q06_chart" -Title "Average Toppings Count: Weekend vs Weekday" -Bindings @("--category", "PizzaOrders[Weekend Label]", "--value", "PizzaOrders[Avg Toppings Count]")

    Add-Visual -Report $report -Page "q07" -Type "clustered_bar" -Name "q07_chart" -Title "Locations with Highest Average Delivery Duration" -Bindings @("--category", "PizzaOrders[Location]", "--value", "PizzaOrders[Avg Delivery Duration]")
    Add-TopNFilter -Report $report -Page "q07" -Visual "q07_chart" -Column "Location" -N 10 -OrderByColumn "__LocationAvgDeliveryContribution" -Direction Top

    Add-Visual -Report $report -Page "q08" -Type "donut" -Name "q08_chart" -Title "Orders During Peak vs Non-Peak Hours" -Bindings @("--category", "PizzaOrders[Peak Hour Label]", "--value", "PizzaOrders[Order Count]")

    Add-Visual -Report $report -Page "q09" -Type "line" -Name "q09_chart" -Title "Order Volume Trend Across Order Month" -Bindings @("--category", "PizzaOrders[Order Month Sorted]", "--value", "PizzaOrders[Order Count]")

    Add-Visual -Report $report -Page "q10" -Type "clustered_column" -Name "q10_chart" -Title "Average Toppings Count by Pizza Size" -Bindings @("--category", "PizzaOrders[Pizza Size]", "--value", "PizzaOrders[Avg Toppings Count]")

    Add-Visual -Report $report -Page "q11" -Type "clustered_bar" -Name "q11_chart" -Title "Bottom 2 Restaurants by Average Delay" -Bindings @("--category", "PizzaOrders[Restaurant Name]", "--value", "PizzaOrders[Avg Delay]")
    Add-TopNFilter -Report $report -Page "q11" -Visual "q11_chart" -Column "Restaurant Name" -N 2 -OrderByColumn "__RestaurantAvgDelayContribution" -Direction Bottom

    Add-Visual -Report $report -Page "q12" -Type "clustered_bar" -Name "q12_chart" -Title "Top 5 Pizza Types by Average Delivery Duration" -Bindings @("--category", "PizzaOrders[Pizza Type]", "--value", "PizzaOrders[Avg Delivery Duration]")
    Add-TopNFilter -Report $report -Page "q12" -Visual "q12_chart" -Column "Pizza Type" -N 5 -OrderByColumn "__PizzaTypeAvgDeliveryContribution" -Direction Top

    Add-Visual -Report $report -Page "q13" -Type "clustered_column" -Name "q13_chart" -Title "Order Volume by Order Hour" -Bindings @("--category", "PizzaOrders[Order Hour]", "--value", "PizzaOrders[Order Count]")

    Add-Visual -Report $report -Page "q14" -Type "clustered_column" -Name "q14_chart" -Title "Average Delay by Traffic Level" -Bindings @("--category", "PizzaOrders[Traffic Level]", "--value", "PizzaOrders[Avg Delay]")

    Add-Visual -Report $report -Page "q15" -Type "donut" -Name "q15_chart" -Title "Order Proportion by Pizza Complexity" -Bindings @("--category", "PizzaOrders[Pizza Complexity]", "--value", "PizzaOrders[Order Count]")

    Add-Visual -Report $report -Page "q16" -Type "matrix" -Name "q16_matrix" -Title "Restaurant Performance: Average Delivery Duration and Delay" -Bindings @("--row", "PizzaOrders[Restaurant Name]", "--value", "PizzaOrders[Avg Delivery Duration]", "--value", "PizzaOrders[Avg Delay]") -X 120 -Y 70 -Width 1040 -Height 560
    Add-Q16Formatting -Report $report -Page "q16" -Visual "q16_matrix"

    Add-ComboVisual -Report $report -Page "q17" -Name "q17_combo" -Title "Order Volume and Average Delay by Order Hour" -Category "PizzaOrders[Order Hour]" -ColumnMeasure "PizzaOrders[Order Count]" -LineMeasure "PizzaOrders[Avg Delay]"

    Add-ComboVisual -Report $report -Page "q18" -Name "q18_combo" -Title "Order Volume and Average Topping Density by Pizza Type" -Category "PizzaOrders[Pizza Type]" -ColumnMeasure "PizzaOrders[Order Count]" -LineMeasure "PizzaOrders[Avg Topping Density]"

    Add-Visual -Report $report -Page "q19" -Type "stacked_bar" -Name "q19_stack" -Title "Traffic-Level Percentage Breakdown within Payment Method" -Bindings @("--category", "PizzaOrders[Payment Method]", "--value", "PizzaOrders[Order Share Within Payment]", "--legend", "PizzaOrders[Traffic Level]") -X 35 -Y 190 -Width 1210 -Height 480
    Add-Visual -Report $report -Page "q19" -Type "slicer" -Name "q19_time_slicer" -Title "Filter by Order Time" -Bindings @("--field", "PizzaOrders[Order Time]") -X 930 -Y 25 -Width 315 -Height 145

    Add-Visual -Report $report -Page "q20" -Type "matrix" -Name "q20_restaurant" -Title "Restaurant Performance" -Bindings @("--row", "PizzaOrders[Restaurant Name]", "--value", "PizzaOrders[Avg Delivery Duration]", "--value", "PizzaOrders[Avg Delay]") -X 25 -Y 35 -Width 590 -Height 300
    Add-Q16Formatting -Report $report -Page "q20" -Visual "q20_restaurant"
    Add-Visual -Report $report -Page "q20" -Type "clustered_column" -Name "q20_traffic" -Title "Average Delay by Traffic Level" -Bindings @("--category", "PizzaOrders[Traffic Level]", "--value", "PizzaOrders[Avg Delay]") -X 640 -Y 35 -Width 610 -Height 300
    Add-ComboVisual -Report $report -Page "q20" -Name "q20_hourly" -Title "Order Volume and Delay by Hour" -Category "PizzaOrders[Order Hour]" -ColumnMeasure "PizzaOrders[Order Count]" -LineMeasure "PizzaOrders[Avg Delay]" -X 25 -Y 360 -Width 1225 -Height 325

    Write-Host "Validating Version $Label PBIR..." -ForegroundColor Cyan
    Invoke-Pbi -Arguments @("report", "-p", $report, "validate") | Out-Null
    Invoke-Pbi -Arguments @("report", "-p", $report, "info") | Out-Null

    $manifest = [ordered]@{
        version = $Label
        built = (Get-Date).ToString("s")
        pbip = $pbip
        report = $report
        expected_pages = 20
        q19_metric = "Order Share Within Payment; denominator removes only Traffic Level so Order Time slicer remains effective"
        q16_conditional_formatting = "Field-value colors via Delivery Duration Color and Delay Color measures when supported by installed pbi-cli format command"
    }
    $manifestPath = Join-Path $target "BUILD_MANIFEST.json"
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding utf8

    Write-Host "VERSION_${Label}_PBIR_BUILD: PASS" -ForegroundColor Green
    return $pbip
}

Assert-Path -Path $SeedDir -Label "Seed directory"
Assert-Path -Path $SeedPbip -Label "Seed PBIP"
Assert-Path -Path $Bootstrap -Label "Model bootstrap script"
Ensure-PbiCommand
Close-PowerBIIfNeeded

Write-Host "Ensuring the Seed contains all measures required by Q01-Q20..." -ForegroundColor Cyan
& pwsh -ExecutionPolicy Bypass -File $Bootstrap -ProjectRoot $ProjectRoot -NoOpen -ForceClosePowerBI
if ($LASTEXITCODE -ne 0) { throw "model_bootstrap.ps1 failed" }

$labels = if ($Version -eq "Both") { @("A", "B") } else { @($Version) }
$builtPbips = @()
foreach ($label in $labels) {
    $builtPbips += Build-Version -Label $label
}

Write-Host "ASSIGNMENT_PBIR_BUILD: PASS" -ForegroundColor Green
Write-Host "Built projects:" -ForegroundColor Green
$builtPbips | ForEach-Object { Write-Host "  $_" }

if ($OpenAfter -and $builtPbips.Count -gt 0) {
    Assert-Path -Path $PowerBIExe -Label "Power BI Desktop"
    Write-Host "Opening first built project for real Desktop rendering..." -ForegroundColor Cyan
    Start-Process -FilePath $PowerBIExe -ArgumentList ('"' + $builtPbips[0] + '"')
}
