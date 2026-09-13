Add-Type -AssemblyName System.Drawing

$out = 'D:\flutter_projects\CarmenKarla\web_storefront\public'
$ink = [System.Drawing.Color]::FromArgb(255, 20, 20, 20)
$gold = [System.Drawing.Color]::FromArgb(255, 221, 180, 137)

function New-BrandIcon {
    param([int]$Size, [string]$Path, [switch]$Square)

    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)

    $s = $Size / 512.0
    $brush = New-Object System.Drawing.SolidBrush $ink

    if ($Square) {
        $g.FillRectangle($brush, 0, 0, $Size, $Size)
    } else {
        $r = 104 * $s
        $shape = New-Object System.Drawing.Drawing2D.GraphicsPath
        $d = $r * 2
        $shape.AddArc(0, 0, $d, $d, 180, 90)
        $shape.AddArc($Size - $d, 0, $d, $d, 270, 90)
        $shape.AddArc($Size - $d, $Size - $d, $d, $d, 0, 90)
        $shape.AddArc(0, $Size - $d, $d, $d, 90, 90)
        $shape.CloseFigure()
        $g.FillPath($brush, $shape)
        $shape.Dispose()
    }

    $pen = New-Object System.Drawing.Pen $gold, (20 * $s)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

    # C: 250 degree arc whose gap faces right, so it reads as a letter not a ring.
    $radius = 78.0 * $s
    $cx = 204.0 * $s
    $cy = 256.0 * $s
    $g.DrawArc($pen, ($cx - $radius), ($cy - $radius), ($radius * 2), ($radius * 2), -55, -250)

    # K: stem plus two arms.
    $stemX = 318.0 * $s
    $top = 170.0 * $s
    $bottom = 342.0 * $s
    $armX = 386.0 * $s
    $g.DrawLine($pen, $stemX, $top, $stemX, $bottom)
    $g.DrawLine($pen, $stemX, $cy, $armX, $top)
    $g.DrawLine($pen, $stemX, $cy, $armX, $bottom)

    $pen.Dispose()
    $brush.Dispose()
    $g.Dispose()
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "wrote $Path"
}

New-BrandIcon -Size 512 -Path (Join-Path $out 'icon-512.png') -Square
New-BrandIcon -Size 512 -Path (Join-Path $out 'icon.png') -Square
New-BrandIcon -Size 192 -Path (Join-Path $out 'icon-192.png') -Square
New-BrandIcon -Size 180 -Path (Join-Path $out 'apple-touch-icon.png')
