param(
    [string]$ProjectRoot = "C:\BISM2202",
    [switch]$NoOpen,
    [switch]$ForceClosePowerBI
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$SeedPbip = Join-Path $ProjectRoot "PROJECT\Seed\BISM2202_Seed.pbip"
$TmdlPath = Join-Path $ProjectRoot "PROJECT\Seed\BISM2202_Seed.SemanticModel\definition\tables\PizzaOrders.tmdl"
$PowerBIExe = "C:\Program Files\Microsoft Power BI Desktop\bin\PBIDesktop.exe"

function Assert-Path {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Label)
    if (-not (Test-Path $Path)) {
        throw "$Label not found: $Path"
    }
}

function Ensure-PowerBIClosed {
    $running = Get-Process PBIDesktop -ErrorAction SilentlyContinue
    if (-not $running) {
        return
    }

    if (-not $ForceClosePowerBI) {
        throw "Power BI Desktop is currently open. Save the Seed project, close ALL Power BI Desktop windows, then rerun this script, or rerun with -ForceClosePowerBI after saving. Direct TMDL editing must be done while Desktop is closed so Desktop cannot overwrite the file."
    }

    Write-Host "Closing all Power BI Desktop processes before TMDL editing..." -ForegroundColor Yellow
    $running | Stop-Process -Force
    Start-Sleep -Seconds 3

    if (Get-Process PBIDesktop -ErrorAction SilentlyContinue) {
        throw "Power BI Desktop could not be closed automatically. Close it manually and rerun."
    }
}

function Ensure-TmdlObject {
    param(
        [Parameter(Mandatory)][string]$Kind,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Block
    )

    $escaped = [regex]::Escape($Name)
    $pattern = if ($Kind -eq "measure") {
        "(?m)^\s*measure\s+(?:'$escaped'|$escaped)\s*="
    } elseif ($Kind -eq "column") {
        "(?m)^\s*column\s+(?:'$escaped'|$escaped)\s*="
    } else {
        throw "Unsupported TMDL object kind: $Kind"
    }

    if ([regex]::IsMatch($script:TmdlText, $pattern)) {
        Write-Host "$Kind exists: $Name" -ForegroundColor DarkGray
        return
    }

    $partitionPattern = "(?m)^\tpartition\s+PizzaOrders\s*=\s*m\s*$"
    $match = [regex]::Match($script:TmdlText, $partitionPattern)
    if (-not $match.Success) {
        throw "Could not locate 'partition PizzaOrders = m' insertion point in $TmdlPath"
    }

    Write-Host "Adding $Kind to TMDL: $Name" -ForegroundColor Green
    $insert = $Block.TrimEnd() + "`r`n`r`n"
    $script:TmdlText = $script:TmdlText.Insert($match.Index, $insert)
}

Assert-Path -Path $SeedPbip -Label "Seed PBIP"
Assert-Path -Path $TmdlPath -Label "PizzaOrders TMDL"
Ensure-PowerBIClosed

$backupDir = Join-Path $ProjectRoot "automation\backups"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupPath = Join-Path $backupDir "PizzaOrders_$timestamp.tmdl.bak"
Copy-Item -LiteralPath $TmdlPath -Destination $backupPath -Force
Write-Host "Backup: $backupPath" -ForegroundColor DarkGray

$script:TmdlText = [System.IO.File]::ReadAllText($TmdlPath)

Write-Host "Adding BISM2202 measures directly to TMDL..." -ForegroundColor Cyan
Ensure-TmdlObject -Kind "measure" -Name "Order Count" -Block @"
`tmeasure 'Order Count' = DISTINCTCOUNT(PizzaOrders[Order ID])
`t`tformatString: #,0
`t`tdisplayFolder: BISM2202 Measures
"@

Ensure-TmdlObject -Kind "measure" -Name "Avg Delivery Duration" -Block @"
`tmeasure 'Avg Delivery Duration' = AVERAGE(PizzaOrders[Delivery Duration (min)])
`t`tformatString: 0.00
`t`tdisplayFolder: BISM2202 Measures
"@

Ensure-TmdlObject -Kind "measure" -Name "Avg Toppings Count" -Block @"
`tmeasure 'Avg Toppings Count' = AVERAGE(PizzaOrders[Toppings Count])
`t`tformatString: 0.00
`t`tdisplayFolder: BISM2202 Measures
"@

Ensure-TmdlObject -Kind "measure" -Name "Avg Delay" -Block @"
`tmeasure 'Avg Delay' = AVERAGE(PizzaOrders[Delay (min)])
`t`tformatString: 0.00
`t`tdisplayFolder: BISM2202 Measures
"@

Ensure-TmdlObject -Kind "measure" -Name "Avg Topping Density" -Block @"
`tmeasure 'Avg Topping Density' = AVERAGE(PizzaOrders[Topping Density])
`t`tformatString: 0.000
`t`tdisplayFolder: BISM2202 Measures
"@

Ensure-TmdlObject -Kind "measure" -Name "Order Share Within Payment" -Block @"
`tmeasure 'Order Share Within Payment' = DIVIDE([Order Count], CALCULATE([Order Count], REMOVEFILTERS(PizzaOrders[Traffic Level])))
`t`tformatString: 0.00%
`t`tdisplayFolder: BISM2202 Measures
"@

Ensure-TmdlObject -Kind "measure" -Name "Delivery Duration Color" -Block @"
`tmeasure 'Delivery Duration Color' = VAR CurrentValue = [Avg Delivery Duration] VAR MinValue = MINX(ALL(PizzaOrders[Restaurant Name]), CALCULATE([Avg Delivery Duration])) VAR MaxValue = MAXX(ALL(PizzaOrders[Restaurant Name]), CALCULATE([Avg Delivery Duration])) RETURN SWITCH(TRUE(), CurrentValue = MinValue, "#C6EFCE", CurrentValue = MaxValue, "#FFC7CE", "#FFF2CC")
`t`tdisplayFolder: BISM2202 Helpers
"@

Ensure-TmdlObject -Kind "measure" -Name "Delay Color" -Block @"
`tmeasure 'Delay Color' = VAR CurrentValue = [Avg Delay] VAR MinValue = MINX(ALL(PizzaOrders[Restaurant Name]), CALCULATE([Avg Delay])) VAR MaxValue = MAXX(ALL(PizzaOrders[Restaurant Name]), CALCULATE([Avg Delay])) RETURN SWITCH(TRUE(), CurrentValue = MinValue, "#C6EFCE", CurrentValue = MaxValue, "#FFC7CE", "#FFF2CC")
`t`tdisplayFolder: BISM2202 Helpers
"@

Write-Host "Adding display and helper calculated columns directly to TMDL..." -ForegroundColor Cyan
Ensure-TmdlObject -Kind "column" -Name "Weekend Label" -Block @"
`tcolumn 'Weekend Label' = IF(PizzaOrders[Is Weekend] = TRUE(), "Weekend", "Weekday")
`t`tdataType: string
`t`tsummarizeBy: none
"@

Ensure-TmdlObject -Kind "column" -Name "Peak Hour Label" -Block @"
`tcolumn 'Peak Hour Label' = IF(PizzaOrders[Is Peak Hour] = TRUE(), "Peak Hour", "Non-Peak Hour")
`t`tdataType: string
`t`tsummarizeBy: none
"@

Ensure-TmdlObject -Kind "column" -Name "Order Month Sorted" -Block @"
`tcolumn 'Order Month Sorted' = FORMAT(PizzaOrders[Order Time], "MM - MMMM")
`t`tdataType: string
`t`tsummarizeBy: none
"@

Ensure-TmdlObject -Kind "column" -Name "__OrderOne" -Block @"
`tcolumn __OrderOne = 1
`t`tdataType: int64
`t	formatString: 0
`t	summarizeBy: sum
`t	isHidden
"@

Ensure-TmdlObject -Kind "column" -Name "__LocationAvgDeliveryContribution" -Block @"
`tcolumn __LocationAvgDeliveryContribution = DIVIDE(CALCULATE(AVERAGE(PizzaOrders[Delivery Duration (min)]), ALLEXCEPT(PizzaOrders, PizzaOrders[Location])), CALCULATE(DISTINCTCOUNT(PizzaOrders[Order ID]), ALLEXCEPT(PizzaOrders, PizzaOrders[Location])))
`t`tdataType: double
`t	summarizeBy: sum
`t	isHidden
"@

Ensure-TmdlObject -Kind "column" -Name "__RestaurantAvgDelayContribution" -Block @"
`tcolumn __RestaurantAvgDelayContribution = DIVIDE(CALCULATE(AVERAGE(PizzaOrders[Delay (min)]), ALLEXCEPT(PizzaOrders, PizzaOrders[Restaurant Name])), CALCULATE(DISTINCTCOUNT(PizzaOrders[Order ID]), ALLEXCEPT(PizzaOrders, PizzaOrders[Restaurant Name])))
`t`tdataType: double
`t	summarizeBy: sum
`t	isHidden
"@

Ensure-TmdlObject -Kind "column" -Name "__PizzaTypeAvgDeliveryContribution" -Block @"
`tcolumn __PizzaTypeAvgDeliveryContribution = DIVIDE(CALCULATE(AVERAGE(PizzaOrders[Delivery Duration (min)]), ALLEXCEPT(PizzaOrders, PizzaOrders[Pizza Type])), CALCULATE(DISTINCTCOUNT(PizzaOrders[Order ID]), ALLEXCEPT(PizzaOrders, PizzaOrders[Pizza Type])))
`t`tdataType: double
`t	summarizeBy: sum
`t	isHidden
"@

[System.IO.File]::WriteAllText($TmdlPath, $script:TmdlText, [System.Text.UTF8Encoding]::new($false))

$verify = [System.IO.File]::ReadAllText($TmdlPath)
$required = @(
    "Order Count",
    "Avg Delivery Duration",
    "Avg Toppings Count",
    "Avg Delay",
    "Avg Topping Density",
    "Order Share Within Payment",
    "Delivery Duration Color",
    "Delay Color",
    "Weekend Label",
    "Peak Hour Label",
    "Order Month Sorted",
    "__OrderOne",
    "__LocationAvgDeliveryContribution",
    "__RestaurantAvgDelayContribution",
    "__PizzaTypeAvgDeliveryContribution"
)

$missing = @()
foreach ($name in $required) {
    if ($verify -notmatch [regex]::Escape($name)) {
        $missing += $name
    }
}
if ($missing.Count -gt 0) {
    throw "TMDL verification failed. Missing: $($missing -join ', ')"
}

Write-Host "TMDL bootstrap written successfully." -ForegroundColor Green
Write-Host "ARM64 note: pbi-cli semantic-model commands require pythonnet/clr-loader native interop and the installed wheel is loading an amd64 ClrLoader.dll. This script intentionally avoids pbi connect and edits the PBIP TMDL source directly." -ForegroundColor Yellow

if (-not $NoOpen) {
    Assert-Path -Path $PowerBIExe -Label "Power BI Desktop executable"
    Write-Host "Opening the Seed PBIP so Power BI Desktop loads the updated TMDL..." -ForegroundColor Cyan
    Start-Process -FilePath $PowerBIExe -ArgumentList ('"' + $SeedPbip + '"')
}

Write-Host "MODEL_BOOTSTRAP_TMDL: PASS" -ForegroundColor Green
Write-Host "If Power BI opens without a model/TMDL error, the semantic-model bootstrap is complete." -ForegroundColor Green
