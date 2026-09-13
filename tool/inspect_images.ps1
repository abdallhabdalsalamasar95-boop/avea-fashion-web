Add-Type -AssemblyName System.Drawing
$out = @()
foreach ($p in @(
    'D:\flutter_projects\CarmenKarla\design\photo.jpg',
    'D:\flutter_projects\CarmenKarla\design\photo_2026-08-20_01-01-38.jpg'
)) {
    $b = [System.Drawing.Bitmap]::FromFile($p)
    $corner = $b.GetPixel(2, 2)
    $mid = $b.GetPixel([int]($b.Width / 2), 4)
    $out += "{0} | {1}x{2} | corner=({3},{4},{5}) | topmid=({6},{7},{8})" -f `
        [System.IO.Path]::GetFileName($p), $b.Width, $b.Height,
        $corner.R, $corner.G, $corner.B, $mid.R, $mid.G, $mid.B
    $b.Dispose()
}
Set-Content 'D:\flutter_projects\CarmenKarla\tool\image_info.txt' -Value $out -Encoding utf8
Write-Output 'ok'
