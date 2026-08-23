param(
    [string]$ProjectRoot = "C:\BISM2202",
    [switch]$NoReload
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$SeedPbip = Join-Path $ProjectRoot "PROJECT\Seed\BISM2202_Seed.pbip"
$ReportPath = Join-Path $ProjectRoot "PROJECT\Seed\BISM2202_Seed.Report"
$PowerBIExe = "C:\Program Files\Microsoft Power BI Desktop\bin\PBIDesktop.exe"

function Ensure-PbiCommand {
    if (Get-Command pbi -ErrorAction SilentlyContinue) {
        return
    }

    $scripts = py -3.12 -c "import sysconfig; print(sysconfig.get_path('scripts'))"
    if ($LASTEXITCODE -eq 0 -and $scripts) {
        $env:Path = "$env:Path;$scripts"
    }

    if (-not (Get-Command pbi -ErrorAction SilentlyContinue)) {
        throw "pbi command was not found. Run: py -3.12 -m pip install --upgrade pbi-cli-tool"
    }
}

function Start-SeedProject {
    if (-not (Test-Path $SeedPbip)) {
        throw "Seed PBIP not found: $SeedPbip"
    }

    $running = Get-Process PBIDesktop -ErrorAction SilentlyContinue
    if (-not $running) {
        if (-not (Test-Path $PowerBIExe)) {
            throw "Power BI Desktop not found: $PowerBIExe"
        }
        Write-Host "Opening BISM2202 Seed in Power BI Desktop..." -ForegroundColor Cyan
        Start-Process -FilePath $PowerBIExe -ArgumentList ('"' + $SeedPbip + '"')
        Start-Sleep -Seconds 18
    }
}

function Connect-SeedModel {
    Write-Host "Connecting pbi-cli to Power BI Desktop..." -ForegroundColor Cyan
    & pbi connect
    if ($LASTEXITCODE -ne 0) {
        throw "pbi connect failed. Keep only the BISM2202 Seed project open in Power BI Desktop and rerun this script."
    }
}

function Test-MeasureExists {
    param([Parameter(Mandatory)][string]$Name)
    & pbi measure get $Name --table "PizzaOrders" *> $null
    return ($LASTEXITCODE -eq 0)
}

function Ensure-Measure {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Expression,
        [string]$FormatString
    )

    if (Test-MeasureExists -Name $Name) {
        Write-Host "Measure exists: $Name" -ForegroundColor DarkGray
        return
    }

    Write-Host "Creating measure: $Name" -ForegroundColor Green
    $args = @("measure", "create", $Name, "--table", "PizzaOrders", "--expression", $Expression)
    if ($FormatString) {
        $args += @("--format-string", $FormatString)
    }
    & pbi @args
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create measure: $Name"
    }
}

function Test-ColumnExists {
    param([Parameter(Mandatory)][string]$Name)
    & pbi column get $Name --table "PizzaOrders" *> $null
    return ($LASTEXITCODE -eq 0)
}

function Ensure-CalculatedColumn {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$DataType,
        [Parameter(Mandatory)][string]$Expression,
        [switch]$Hidden
    )

    if (Test-ColumnExists -Name $Name) {
        Write-Host "Column exists: $Name" -ForegroundColor DarkGray
        return
    }

    Write-Host "Creating calculated column: $Name" -ForegroundColor Green
    $args = @(
        "column", "create", $Name,
        "--table", "PizzaOrders",
        "--data-type", $DataType,
        "--expression", $Expression
    )
    if ($Hidden) {
        $args += "--hidden"
    }
    & pbi @args
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create calculated column: $Name"
    }
}

Ensure-PbiCommand
Start-SeedProject
Connect-SeedModel

Write-Host "Creating validated BISM2202 measures..." -ForegroundColor Cyan
Ensure-Measure -Name "Order Count" -Expression 'DISTINCTCOUNT(PizzaOrders[Order ID])' -FormatString '#,0'
Ensure-Measure -Name "Avg Delivery Duration" -Expression 'AVERAGE(PizzaOrders[Delivery Duration (min)])' -FormatString '0.00'
Ensure-Measure -Name "Avg Toppings Count" -Expression 'AVERAGE(PizzaOrders[Toppings Count])' -FormatString '0.00'
Ensure-Measure -Name "Avg Delay" -Expression 'AVERAGE(PizzaOrders[Delay (min)])' -FormatString '0.00'
Ensure-Measure -Name "Avg Topping Density" -Expression 'AVERAGE(PizzaOrders[Topping Density])' -FormatString '0.000'

Ensure-Measure -Name "Delivery Duration Color" -Expression 'VAR CurrentValue = [Avg Delivery Duration] VAR MinValue = MINX(ALL(PizzaOrders[Restaurant Name]), CALCULATE([Avg Delivery Duration])) VAR MaxValue = MAXX(ALL(PizzaOrders[Restaurant Name]), CALCULATE([Avg Delivery Duration])) RETURN SWITCH(TRUE(), CurrentValue = MinValue, "#C6EFCE", CurrentValue = MaxValue, "#FFC7CE", "#FFF2CC")'
Ensure-Measure -Name "Delay Color" -Expression 'VAR CurrentValue = [Avg Delay] VAR MinValue = MINX(ALL(PizzaOrders[Restaurant Name]), CALCULATE([Avg Delay])) VAR MaxValue = MAXX(ALL(PizzaOrders[Restaurant Name]), CALCULATE([Avg Delay])) RETURN SWITCH(TRUE(), CurrentValue = MinValue, "#C6EFCE", CurrentValue = MaxValue, "#FFC7CE", "#FFF2CC")'

Write-Host "Creating display and helper columns..." -ForegroundColor Cyan
Ensure-CalculatedColumn -Name "Weekend Label" -DataType "string" -Expression 'IF(PizzaOrders[Is Weekend] = TRUE(), "Weekend", "Weekday")'
Ensure-CalculatedColumn -Name "Peak Hour Label" -DataType "string" -Expression 'IF(PizzaOrders[Is Peak Hour] = TRUE(), "Peak Hour", "Non-Peak Hour")'
Ensure-CalculatedColumn -Name "Order Month Sorted" -DataType "string" -Expression 'FORMAT(PizzaOrders[Order Time], "MM - MMMM")'

Ensure-CalculatedColumn -Name "__OrderOne" -DataType "int64" -Expression '1' -Hidden
Ensure-CalculatedColumn -Name "__LocationAvgDeliveryContribution" -DataType "double" -Expression 'DIVIDE(CALCULATE(AVERAGE(PizzaOrders[Delivery Duration (min)]), ALLEXCEPT(PizzaOrders, PizzaOrders[Location])), CALCULATE(DISTINCTCOUNT(PizzaOrders[Order ID]), ALLEXCEPT(PizzaOrders, PizzaOrders[Location])))' -Hidden
Ensure-CalculatedColumn -Name "__RestaurantAvgDelayContribution" -DataType "double" -Expression 'DIVIDE(CALCULATE(AVERAGE(PizzaOrders[Delay (min)]), ALLEXCEPT(PizzaOrders, PizzaOrders[Restaurant Name])), CALCULATE(DISTINCTCOUNT(PizzaOrders[Order ID]), ALLEXCEPT(PizzaOrders, PizzaOrders[Restaurant Name])))' -Hidden
Ensure-CalculatedColumn -Name "__PizzaTypeAvgDeliveryContribution" -DataType "double" -Expression 'DIVIDE(CALCULATE(AVERAGE(PizzaOrders[Delivery Duration (min)]), ALLEXCEPT(PizzaOrders, PizzaOrders[Pizza Type])), CALCULATE(DISTINCTCOUNT(PizzaOrders[Order ID]), ALLEXCEPT(PizzaOrders, PizzaOrders[Pizza Type])))' -Hidden

Write-Host "Verifying measures..." -ForegroundColor Cyan
& pbi measure list --table "PizzaOrders"
if ($LASTEXITCODE -ne 0) {
    throw "Measure verification failed."
}

if (-not $NoReload) {
    Write-Host "Saving and reloading the Seed project so PBIP/TMDL source is synchronized..." -ForegroundColor Cyan
    & pbi report -p $ReportPath reload
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Automatic reload did not complete. Use Power BI Desktop Save once, then continue."
    }
}

Write-Host "MODEL_BOOTSTRAP: PASS" -ForegroundColor Green
