param(
    [ValidateSet("A", "B")][string]$Version = "A",
    [string]$ProjectRoot = "C:\BISM2202",
    [int]$Width = 640,
    [int]$JpegQuality = 52,
    [switch]$Push
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$sourceDir = Join-Path $ProjectRoot "PROJECT\BISM2202_OUTPUT\Version_${Version}\screenshots"
$outDir = Join-Path $ProjectRoot "PROJECT\BISM2202_OUTPUT\Version_${Version}\ai_review"
if (-not (Test-Path -LiteralPath $sourceDir)) { throw "Screenshot directory not found: $sourceDir" }
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

function Save-Jpeg([System.Drawing.Image]$Image, [string]$Path, [long]$Quality) {
    $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' } | Select-Object -First 1
    $encoder = [System.Drawing.Imaging.Encoder]::Quality
    $params = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter($encoder, $Quality)
    try { $Image.Save($Path, $codec, $params) } finally { $params.Dispose() }
}

$manifest = @()
foreach ($n in 1..20) {
    $page = "Q{0:D2}" -f $n
    $src = Join-Path $sourceDir "$page.png"
    if (-not (Test-Path -LiteralPath $src)) { throw "Missing source screenshot: $src" }

    $img = [System.Drawing.Image]::FromFile($src)
    try {
        $height = [int][Math]::Round($img.Height * ($Width / [double]$img.Width))
        $thumb = New-Object System.Drawing.Bitmap($Width, $height)
        try {
            $g = [System.Drawing.Graphics]::FromImage($thumb)
            try {
                $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $g.DrawImage($img, 0, 0, $Width, $height)
            } finally { $g.Dispose() }

            $jpg = Join-Path $outDir "$page.jpg"
            Save-Jpeg $thumb $jpg $JpegQuality
            $bytes = [System.IO.File]::ReadAllBytes($jpg)
            $b64 = [Convert]::ToBase64String($bytes)
            $b64Path = Join-Path $outDir "$page.jpg.b64.txt"
            [System.IO.File]::WriteAllText($b64Path, $b64, [System.Text.UTF8Encoding]::new($false))
            Remove-Item -LiteralPath $jpg -Force

            $manifest += [pscustomobject]@{
                page = $page
                source = $src
                width = $Width
                height = $height
                jpeg_quality = $JpegQuality
                bytes = $bytes.Length
                base64_file = "PROJECT/BISM2202_OUTPUT/Version_${Version}/ai_review/$page.jpg.b64.txt"
            }
            Write-Host "Prepared $page AI review thumbnail ($($bytes.Length) bytes)" -ForegroundColor Green
        } finally { $thumb.Dispose() }
    } finally { $img.Dispose() }
}

$manifestPath = Join-Path $outDir "manifest.json"
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
Write-Host "AI_REVIEW_THUMBNAILS: PASS" -ForegroundColor Green

if ($Push) {
    Set-Location $ProjectRoot
    git add -- "PROJECT/BISM2202_OUTPUT/Version_${Version}/ai_review"
    $changes = git diff --cached --name-only
    if ($changes) {
        $stamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
        git commit -m "AI review thumbnails Version $Version $stamp"
        if ($LASTEXITCODE -ne 0) { throw "git commit failed" }
        git push
        if ($LASTEXITCODE -ne 0) { throw "git push failed" }
    }
    Write-Host "VERSION_${Version}_AI_REVIEW_PUBLISHED: PASS" -ForegroundColor Green
}
