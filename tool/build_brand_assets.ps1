Add-Type -AssemblyName System.Drawing

$design = 'D:\flutter_projects\CarmenKarla\design'
$shopRes = 'D:\flutter_projects\CarmenKarla\shop_kotlin\app\src\main\res'
$adminRes = 'D:\flutter_projects\CarmenKarla\admin_kotlin\app\src\main\res'
$webPublic = 'D:\flutter_projects\CarmenKarla\web_storefront\public'

# The artwork is black on white; every output keeps that exact palette.
$white = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
$source = Join-Path $design 'photo_2026-08-20_01-26-40.jpg'

function New-Dir($p) { if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null } }

function Get-Buffer([System.Drawing.Bitmap]$Bitmap) {
    $rect = New-Object System.Drawing.Rectangle 0, 0, $Bitmap.Width, $Bitmap.Height
    $data = $Bitmap.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $bytes = $Bitmap.Width * $Bitmap.Height * 4
    $buffer = New-Object byte[] $bytes
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $buffer, 0, $bytes)
    $Bitmap.UnlockBits($data)
    return , $buffer
}

# Turns the flat white sheet transparent while keeping anti-aliased edges.
function Remove-Backdrop {
    param([System.Drawing.Bitmap]$Source, [int]$KeyR, [int]$KeyG, [int]$KeyB, [int]$Near = 30, [int]$Far = 78)

    $w = $Source.Width
    $h = $Source.Height
    $buffer = Get-Buffer $Source
    $bytes = $w * $h * 4
    $span = [double]($Far - $Near)

    for ($i = 0; $i -lt $bytes; $i += 4) {
        $dr = $buffer[$i + 2] - $KeyR
        $dg = $buffer[$i + 1] - $KeyG
        $db = $buffer[$i] - $KeyB
        $dist = [math]::Sqrt($dr * $dr + $dg * $dg + $db * $db)
        if ($dist -le $Near) {
            $buffer[$i + 3] = 0
        } elseif ($dist -ge $Far) {
            $buffer[$i + 3] = 255
        } else {
            $buffer[$i + 3] = [byte][math]::Round(255 * (($dist - $Near) / $span))
        }
    }

    $result = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $dst = $result.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    [System.Runtime.InteropServices.Marshal]::Copy($buffer, 0, $dst.Scan0, $bytes)
    $result.UnlockBits($dst)
    return $result
}

function Get-OpaqueBounds([System.Drawing.Bitmap]$Bitmap, [int]$MinAlpha = 30) {
    $w = $Bitmap.Width
    $buffer = Get-Buffer $Bitmap
    $minX = $w; $minY = $Bitmap.Height; $maxX = -1; $maxY = -1
    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        $row = $y * $w * 4
        for ($x = 0; $x -lt $w; $x++) {
            if ($buffer[$row + $x * 4 + 3] -ge $MinAlpha) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    if ($maxX -lt 0) { return $null }
    return New-Object System.Drawing.Rectangle $minX, $minY, ($maxX - $minX + 1), ($maxY - $minY + 1)
}

function Save-Fitted {
    param(
        [System.Drawing.Bitmap]$Art,
        [string]$Destination,
        [int]$Width,
        [int]$Height,
        [double]$Fill = 1.0,
        [System.Drawing.Color]$Background = [System.Drawing.Color]::Transparent
    )

    $canvas = New-Object System.Drawing.Bitmap $Width, $Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($canvas)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.Clear($Background)

    $scale = [math]::Min(($Width * $Fill) / $Art.Width, ($Height * $Fill) / $Art.Height)
    $dw = [int][math]::Round($Art.Width * $scale)
    $dh = [int][math]::Round($Art.Height * $scale)
    $g.DrawImage($Art, [int](($Width - $dw) / 2), [int](($Height - $dh) / 2), $dw, $dh)
    $g.Dispose()
    $canvas.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
    $canvas.Dispose()
    Write-Output "  $Destination  ($Width x $Height)"
}

New-Dir (Join-Path $shopRes 'drawable-nodpi')
New-Dir (Join-Path $adminRes 'drawable-nodpi')

Write-Output "source: $source"
$raw = [System.Drawing.Bitmap]::FromFile($source)
$keyed = Remove-Backdrop -Source $raw -KeyR 255 -KeyG 255 -KeyB 255
$raw.Dispose()
$bounds = Get-OpaqueBounds $keyed 30
Write-Output "  art $($bounds.Width)x$($bounds.Height)"
$art = $keyed.Clone($bounds, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$keyed.Dispose()
$ratio = $art.Height / $art.Width

Write-Output 'welcome mark + header wordmark'
Save-Fitted -Art $art -Destination (Join-Path $shopRes 'drawable-nodpi\brand_mark.png') -Width 1200 -Height ([int](1200 * $ratio))
Save-Fitted -Art $art -Destination (Join-Path $shopRes 'drawable-nodpi\brand_wordmark.png') -Width 1200 -Height ([int](1200 * $ratio))
Save-Fitted -Art $art -Destination (Join-Path $webPublic 'logo-wide.png') -Width 1200 -Height ([int](1200 * $ratio))

Write-Output 'app icons'
Save-Fitted -Art $art -Destination (Join-Path $shopRes 'drawable-nodpi\ic_launcher_logo.png') -Width 432 -Height 432 -Fill 0.62
Save-Fitted -Art $art -Destination (Join-Path $adminRes 'drawable-nodpi\ic_launcher_logo.png') -Width 432 -Height 432 -Fill 0.62

Write-Output 'site icons'
Save-Fitted -Art $art -Destination (Join-Path $webPublic 'icon-512.png') -Width 512 -Height 512 -Fill 0.80 -Background $white
Save-Fitted -Art $art -Destination (Join-Path $webPublic 'icon.png') -Width 512 -Height 512 -Fill 0.80 -Background $white
Save-Fitted -Art $art -Destination (Join-Path $webPublic 'icon-192.png') -Width 192 -Height 192 -Fill 0.80 -Background $white
Save-Fitted -Art $art -Destination (Join-Path $webPublic 'apple-touch-icon.png') -Width 180 -Height 180 -Fill 0.80 -Background $white
$art.Dispose()

Write-Output 'done'
