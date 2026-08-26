param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Prepare", "CaptureA", "CaptureB", "Finalize")]
    [string]$Stage,

    [string]$ProjectRoot = "C:\BISM2202"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$RuntimeDir = Join-Path $RepoRoot "runtime\teacher_feedback_v2"
$MarkerPath = Join-Path $RuntimeDir "prepared.json"
$PowerBIExe = "C:\Program Files\Microsoft Power BI Desktop\bin\PBIDesktop.exe"

function Write-Step([string]$Text) {
    Write-Host "`n===== $Text =====" -ForegroundColor Cyan
}

function Assert-ExitCode([string]$Name) {
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE"
    }
}

function Get-VersionPaths([ValidateSet("A", "B")][string]$Version) {
    $sourceRoot = Join-Path $RepoRoot "PROJECT\Version_${Version}_PowerBI"
    $report = Join-Path $sourceRoot "BISM2202_Seed.Report"
    $model = Join-Path $sourceRoot "BISM2202_Seed.SemanticModel"
    $pbip = Join-Path $sourceRoot "BISM2202_Seed.pbip"
    $tmdl = Join-Path $model "definition\tables\PizzaOrders.tmdl"
    $q09Visual = Join-Path $report "definition\pages\q09\visuals\q09_chart\visual.json"
    $output = Join-Path $RepoRoot "PROJECT\BISM2202_OUTPUT\Version_${Version}"
    $pbix = Join-Path $output "BISM2202_Assignment_${Version}.pbix"
    $reportDocx = Join-Path $output "BISM2202_Report_${Version}.docx"
    $screenshots = Join-Path $output "screenshots"

    return [pscustomobject]@{
        Version = $Version
        SourceRoot = $sourceRoot
        Report = $report
        Model = $model
        PBIP = $pbip
        Tmdl = $tmdl
        Q09Visual = $q09Visual
        Output = $output
        PBIX = $pbix
        ReportDocx = $reportDocx
        Screenshots = $screenshots
    }
}

function Assert-PowerBIClosed {
    $running = Get-Process PBIDesktop -ErrorAction SilentlyContinue
    if ($running) {
        throw "Power BI Desktop is open. Save your work and close every Power BI window before running Prepare."
    }
}

function Assert-PowerBIOpen {
    $running = Get-Process PBIDesktop -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 }
    if (-not $running) {
        throw "Power BI Desktop is not open. Open the intended A/B PBIP first, wait until it is fully rendered, then rerun this capture stage."
    }
}

function Backup-File([string]$Path, [string]$Version, [string]$BackupRoot) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Required source file missing: $Path"
    }
    $targetDir = Join-Path $BackupRoot "Version_$Version"
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    Copy-Item -LiteralPath $Path -Destination (Join-Path $targetDir ([IO.Path]::GetFileName($Path))) -Force
}

function Ensure-Q09EnglishMonthColumns([string]$TmdlPath, [string]$Version) {
    $text = [IO.File]::ReadAllText($TmdlPath)

    $hasLabel = $text.Contains("column 'Order Month English'")
    $hasSort = $text.Contains("column 'Order Month Sort'")

    if ($hasLabel -xor $hasSort) {
        throw "Version $Version has a partial previous Q09 month-label patch. Restore the backup or inspect PizzaOrders.tmdl before continuing."
    }

    if (-not $hasLabel) {
        $marker = "`tcolumn __OrderOne = 1"
        if (-not $text.Contains($marker)) {
            throw "Could not locate insertion marker in Version $Version PizzaOrders.tmdl"
        }

        if ($Version -eq "A") {
            $labelGuid = "b1fa8055-2262-4421-a247-a13a1b4f2a91"
            $sortGuid = "8df4b7f7-9dc7-4160-8f2c-7a9ecbb90b51"
        } else {
            $labelGuid = "95368a73-ff4d-42fb-a1ab-1bea19ae6c2d"
            $sortGuid = "2afc4a10-a058-4f72-a1a6-fd69f441b2d9"
        }

        $block = @"
`tcolumn 'Order Month English' = FORMAT(PizzaOrders[Order Month Start], "MMM yyyy", "en-US")
`t`tdataType: string
`t`tlineageTag: $labelGuid
`t`tsummarizeBy: none
`t`tsortByColumn: 'Order Month Sort'
`t`tchangedProperty = SortByColumn

`tcolumn 'Order Month Sort' = YEAR(PizzaOrders[Order Month Start]) * 100 + MONTH(PizzaOrders[Order Month Start])
`t`tdataType: int64
`t`tisHidden
`t`tformatString: 0
`t`tlineageTag: $sortGuid
`t`tsummarizeBy: none

"@

        $text = $text.Replace($marker, $block + $marker)
        [IO.File]::WriteAllText($TmdlPath, $text, [Text.UTF8Encoding]::new($false))
        Write-Host "Version ${Version}: added English month label + chronological sort columns." -ForegroundColor Green
    } else {
        if (-not $text.Contains('FORMAT(PizzaOrders[Order Month Start], "MMM yyyy", "en-US")')) {
            throw "Version $Version already contains Order Month English, but its expression is not the expected explicit en-US format."
        }
        if (-not $text.Contains("sortByColumn: 'Order Month Sort'")) {
            throw "Version $Version Order Month English is missing chronological sortByColumn metadata."
        }
        Write-Host "Version ${Version}: English month columns already present and valid." -ForegroundColor DarkGreen
    }
}

function Set-JsonPropertyValue($Object, [string]$PropertyName, $Value) {
    if ($null -eq $Object.PSObject.Properties[$PropertyName]) {
        $Object | Add-Member -NotePropertyName $PropertyName -NotePropertyValue $Value
    } else {
        $Object.$PropertyName = $Value
    }
}

function Patch-Q09Visual([string]$VisualPath, [string]$Version) {
    $data = Get-Content -LiteralPath $VisualPath -Raw | ConvertFrom-Json

    $category = $data.visual.query.queryState.Category.projections[0]
    $category.field.Column.Property = "Order Month English"
    $category.queryRef = "PizzaOrders.Order Month English"
    $category.nativeQueryRef = "Order Month English"
    Set-JsonPropertyValue $category "active" $true

    if ($null -eq $data.visual.query.PSObject.Properties['sortDefinition']) {
        throw "Version $Version Q09 visual unexpectedly has no sortDefinition. Refusing to patch blindly."
    }
    $sort = $data.visual.query.sortDefinition.sort[0]
    $sort.field.Column.Property = "Order Month English"
    $sort.direction = "Ascending"

    $title = if ($Version -eq "A") {
        "'Order Volume Trend by Month'"
    } else {
        "'Monthly Order Volume'"
    }
    $data.visual.visualContainerObjects.title[0].properties.text.expr.Literal.Value = $title

    if ($null -ne $data.visual.visualContainerObjects.PSObject.Properties['subTitle']) {
        $data.visual.visualContainerObjects.subTitle[0].properties.show.expr.Literal.Value = "false"
    }

    $json = $data | ConvertTo-Json -Depth 100
    [IO.File]::WriteAllText($VisualPath, $json, [Text.UTF8Encoding]::new($false))

    $verify = Get-Content -LiteralPath $VisualPath -Raw
    if ($verify -notmatch 'Order Month English') {
        throw "Version $Version Q09 patch verification failed."
    }
    if ($verify -match 'PizzaOrders\.Order Month Start') {
        throw "Version $Version Q09 still binds the visible axis to Order Month Start."
    }

    Write-Host "Version ${Version}: Q09 now uses discrete English month labels in chronological order." -ForegroundColor Green
}

function Assert-NoExplicitChineseVisualText([string]$ReportPath, [string]$Version) {
    $han = '[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]'
    $hits = @()
    Get-ChildItem -LiteralPath (Join-Path $ReportPath "definition\pages") -Filter "visual.json" -File -Recurse | ForEach-Object {
        $raw = Get-Content -LiteralPath $_.FullName -Raw
        if ($raw -match $han) {
            $hits += $_.FullName
        }
    }
    if ($hits.Count -gt 0) {
        Write-Host "Explicit Chinese text found in visible visual definitions for Version ${Version}:" -ForegroundColor Red
        $hits | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        throw "Visible visual JSON still contains explicit Chinese text."
    }
    Write-Host "Version ${Version}: no explicit Chinese characters in visual.json files." -ForegroundColor Green
}

function Ensure-PbiCommand {
    if (Get-Command pbi -ErrorAction SilentlyContinue) { return $true }
    try {
        $scripts = (& py -3.12 -c "import sysconfig; print(sysconfig.get_path('scripts'))").Trim()
        if ($LASTEXITCODE -eq 0 -and $scripts) {
            $env:Path = "$env:Path;$scripts"
        }
    } catch {}
    return [bool](Get-Command pbi -ErrorAction SilentlyContinue)
}

function Validate-ReportSource([pscustomobject]$Paths) {
    if (Ensure-PbiCommand) {
        & pbi report -p $Paths.Report validate | Out-Host
        Assert-ExitCode "pbi report validate Version $($Paths.Version)"
        Write-Host "Version $($Paths.Version): PBIR validation PASS." -ForegroundColor Green
    } else {
        Write-Host "pbi CLI not found; static patch checks passed. Power BI Desktop will perform the authoritative model load when you open the PBIP." -ForegroundColor Yellow
    }
}

function Read-PreparedMarker {
    if (-not (Test-Path -LiteralPath $MarkerPath)) {
        throw "Prepare marker missing. Run: pwsh -ExecutionPolicy Bypass -File .\automation\teacher_feedback_workflow.ps1 -Stage Prepare"
    }
    return Get-Content -LiteralPath $MarkerPath -Raw | ConvertFrom-Json
}

function Verify-Capture([ValidateSet("A", "B")][string]$Version) {
    $paths = Get-VersionPaths $Version
    $marker = Read-PreparedMarker

    $shots = @(Get-ChildItem -LiteralPath $paths.Screenshots -Filter "Q??.png" -File -ErrorAction SilentlyContinue | Sort-Object Name)
    if ($shots.Count -ne 20) {
        throw "Version $Version screenshot count is $($shots.Count); expected 20."
    }
    foreach ($shot in $shots) {
        if ($shot.Length -lt 8000) {
            throw "Version $Version screenshot $($shot.Name) is suspiciously small ($($shot.Length) bytes)."
        }
    }
    $q09 = Join-Path $paths.Screenshots "Q09.png"
    if (-not (Test-Path -LiteralPath $q09)) { throw "Version $Version Q09 screenshot missing." }
    if ((Get-Item -LiteralPath $q09).LastWriteTime -lt [datetime]$marker.prepared_local_time) {
        throw "Version $Version Q09 screenshot predates the teacher-feedback patch. Capture is stale."
    }
    Write-Host "Version ${Version}: 20 fresh screenshots PASS." -ForegroundColor Green
}

function Capture-Version([ValidateSet("A", "B")][string]$Version) {
    Assert-PowerBIOpen
    $paths = Get-VersionPaths $Version
    Assert-NoExplicitChineseVisualText $paths.Report $Version

    & pwsh -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "automation\capture_pages_windows.ps1") -Version $Version -ProjectRoot $RepoRoot
    Assert-ExitCode "capture_pages_windows.ps1 Version $Version"
    Verify-Capture $Version

    Write-Host "`nCAPTURE_${Version}: PASS" -ForegroundColor Green
    Write-Host "Keep the Power BI source unchanged. You may now close this Power BI window and continue with the other version." -ForegroundColor Yellow
}

function Assert-FinalPBIX([ValidateSet("A", "B")][string]$Version) {
    $paths = Get-VersionPaths $Version
    if (-not (Test-Path -LiteralPath $paths.PBIX)) {
        throw "Final Version $Version PBIX missing: $($paths.PBIX)"
    }
    $item = Get-Item -LiteralPath $paths.PBIX
    if ($item.Length -lt 100000) {
        throw "Final Version $Version PBIX looks too small: $($item.Length) bytes"
    }
    $marker = Read-PreparedMarker
    if ($item.LastWriteTime -lt [datetime]$marker.prepared_local_time) {
        throw "Final Version $Version PBIX predates the teacher-feedback preparation. Save/replace the PBIX manually before Finalize."
    }
    Write-Host "Version $Version PBIX: $($item.Length) bytes, $($item.LastWriteTime) PASS" -ForegroundColor Green
}

function Count-DocxMedia([string]$Path) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        return @($zip.Entries | Where-Object { $_.FullName -like "word/media/*" -and -not $_.FullName.EndsWith("/") }).Count
    } finally {
        $zip.Dispose()
    }
}

function Finalize-All {
    if (Get-Process PBIDesktop -ErrorAction SilentlyContinue) {
        throw "Close Power BI Desktop before Finalize. The source and PBIX files must already be manually saved."
    }

    Write-Step "VERIFY MANUAL SAVES"
    foreach ($v in @("A", "B")) {
        $paths = Get-VersionPaths $v
        Assert-NoExplicitChineseVisualText $paths.Report $v
        Assert-FinalPBIX $v
        Verify-Capture $v
    }

    Write-Step "REBUILD BOTH WORD REPORTS FROM FRESH SCREENSHOTS"
    & py -3.12 (Join-Path $RepoRoot "automation\finalize_reports.py") --version Both | Out-Host
    Assert-ExitCode "finalize_reports.py"

    foreach ($v in @("A", "B")) {
        $paths = Get-VersionPaths $v
        if (-not (Test-Path -LiteralPath $paths.ReportDocx)) {
            throw "Version $v report missing after rebuild."
        }
        $media = Count-DocxMedia $paths.ReportDocx
        if ($media -ne 20) {
            throw "Version $v report contains $media embedded images; expected exactly 20."
        }
        Write-Host "Version $v report: 20 embedded images PASS." -ForegroundColor Green
    }

    Write-Step "COMMIT CORRECTED SOURCE + PBIX + SCREENSHOTS + REPORTS"
    Push-Location $RepoRoot
    try {
        $sourceCommit = (& git rev-parse HEAD).Trim()

        & git add -- `
            PROJECT/Version_A_PowerBI `
            PROJECT/Version_B_PowerBI `
            PROJECT/BISM2202_OUTPUT/Version_A `
            PROJECT/BISM2202_OUTPUT/Version_B `
            Student_A `
            Student_B
        Assert-ExitCode "git add corrected deliverables"

        $staged = & git diff --cached --name-only
        if ($staged) {
            & git commit -m "fix: apply teacher feedback and English-safe Power BI visuals"
            Assert-ExitCode "git commit corrected deliverables"
        } else {
            Write-Host "No new content changes were staged. Continuing with current HEAD." -ForegroundColor Yellow
        }
        $contentCommit = (& git rev-parse HEAD).Trim()

        Write-Step "BUILD AND RE-EXTRACT FINAL ZIP PACKAGES"
        & py -3.12 (Join-Path $RepoRoot "automation\package_final.py") --source-commit $sourceCommit --final-commit $contentCommit | Out-Host
        Assert-ExitCode "package_final.py"

        $manifestPath = Join-Path $RepoRoot "FINAL_PACKAGES\FINAL_PACKAGE_MANIFEST.json"
        if (-not (Test-Path -LiteralPath $manifestPath)) { throw "Final package manifest missing." }
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        if ($manifest.status -ne "PASS") {
            throw "Final package manifest status is $($manifest.status)"
        }
        foreach ($v in @("A", "B")) {
            if ($manifest.versions.$v.screenshot_count -ne 20) { throw "Manifest Version $v screenshot count is not 20." }
            if ($manifest.versions.$v.docx_embedded_images -ne 20) { throw "Manifest Version $v DOCX image count is not 20." }
            if ($manifest.versions.$v.reextraction_status -ne "PASS") { throw "Manifest Version $v re-extraction failed." }
        }

        & git add -- FINAL_PACKAGES FINAL_DELIVERABLES
        Assert-ExitCode "git add final packages"
        $packageStaged = & git diff --cached --name-only
        if ($packageStaged) {
            & git commit -m "package: rebuild BISM2202 A and B after teacher feedback"
            Assert-ExitCode "git commit final packages"
        }

        Write-Step "PUSH TO GITHUB"
        & git fetch origin
        Assert-ExitCode "git fetch origin"
        $originMain = (& git rev-parse origin/main).Trim()
        $mergeBase = (& git merge-base HEAD origin/main).Trim()
        if ($mergeBase -ne $originMain) {
            throw "origin/main moved independently. Refusing an automatic rebase/reset. Send this output for review."
        }
        & git push origin HEAD:main
        Assert-ExitCode "git push origin main"
        & git fetch origin
        Assert-ExitCode "git fetch after push"
        $local = (& git rev-parse HEAD).Trim()
        $remote = (& git rev-parse origin/main).Trim()
        if ($local -ne $remote) { throw "Local HEAD and origin/main do not match after push." }

        Write-Host "`n========================================================" -ForegroundColor Green
        Write-Host "TEACHER_FEEDBACK_FINAL_DELIVERY: PASS" -ForegroundColor Green
        Write-Host "VERSION_A_SOURCE: PASS" -ForegroundColor Green
        Write-Host "VERSION_B_SOURCE: PASS" -ForegroundColor Green
        Write-Host "VERSION_A_PBIX: PASS" -ForegroundColor Green
        Write-Host "VERSION_B_PBIX: PASS" -ForegroundColor Green
        Write-Host "VERSION_A_SCREENSHOTS: 20 PASS" -ForegroundColor Green
        Write-Host "VERSION_B_SCREENSHOTS: 20 PASS" -ForegroundColor Green
        Write-Host "VERSION_A_REPORT_IMAGES: 20 PASS" -ForegroundColor Green
        Write-Host "VERSION_B_REPORT_IMAGES: 20 PASS" -ForegroundColor Green
        Write-Host "FINAL_PACKAGE_A: C:\BISM2202\FINAL_PACKAGES\BISM2202_Student_A_FINAL.zip" -ForegroundColor Green
        Write-Host "FINAL_PACKAGE_B: C:\BISM2202\FINAL_PACKAGES\BISM2202_Student_B_FINAL.zip" -ForegroundColor Green
        Write-Host "GITHUB_HEAD: $local" -ForegroundColor Green
        Write-Host "GIT_PUSH: PASS" -ForegroundColor Green
        Write-Host "========================================================" -ForegroundColor Green
        Write-Host "`nRemaining unrelated local changes, if any:" -ForegroundColor Yellow
        & git status --short
    } finally {
        Pop-Location
    }
}

switch ($Stage) {
    "Prepare" {
        Assert-PowerBIClosed
        New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null
        $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupRoot = Join-Path $RuntimeDir "backup_$stamp"
        New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

        Write-Step "BACKUP + PATCH BOTH PBIP SOURCES"
        foreach ($v in @("A", "B")) {
            $paths = Get-VersionPaths $v
            Backup-File $paths.Tmdl $v $backupRoot
            Backup-File $paths.Q09Visual $v $backupRoot
            Ensure-Q09EnglishMonthColumns $paths.Tmdl $v
            Patch-Q09Visual $paths.Q09Visual $v
            Assert-NoExplicitChineseVisualText $paths.Report $v
            Validate-ReportSource $paths
        }

        $marker = [ordered]@{
            prepared_local_time = (Get-Date).ToString("o")
            backup_root = $backupRoot
            git_head_before_manual_save = (& git -C $RepoRoot rev-parse HEAD).Trim()
            q09_axis = "Order Month English"
            q09_format = "MMM yyyy / en-US"
        }
        $marker | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $MarkerPath -Encoding UTF8

        Write-Host "`nTEACHER_FEEDBACK_PREPARE: PASS" -ForegroundColor Green
        Write-Host "The source files are patched. Power BI saving is intentionally NOT automated." -ForegroundColor Yellow
        Write-Host "`nNext, manually do A:" -ForegroundColor Cyan
        Write-Host "  Start-Process `"C:\BISM2202\PROJECT\Version_A_PowerBI\BISM2202_Seed.pbip`"" -ForegroundColor White
        Write-Host "  Confirm Q09 shows English month labels such as Jan 2024 / Feb 2024 / Mar 2024 in chronological order." -ForegroundColor White
        Write-Host "  Save the PBIP in Power BI, then Save As/replace:" -ForegroundColor White
        Write-Host "  C:\BISM2202\PROJECT\BISM2202_OUTPUT\Version_A\BISM2202_Assignment_A.pbix" -ForegroundColor Green
        Write-Host "  KEEP POWER BI OPEN and run CaptureA in another PowerShell window." -ForegroundColor White
        Write-Host "`nThen repeat the same manual save flow for Version B and run CaptureB." -ForegroundColor Cyan
    }
    "CaptureA" { Capture-Version "A" }
    "CaptureB" { Capture-Version "B" }
    "Finalize" { Finalize-All }
}
