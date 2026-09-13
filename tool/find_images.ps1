$paths = @(
    'C:\Users\libya\Downloads',
    'C:\Users\libya\Desktop',
    'C:\Users\libya\Pictures',
    'C:\Users\libya\OneDrive\Pictures',
    'D:\flutter_projects\CarmenKarla\design',
    'D:\flutter_projects\CarmenKarla\assets'
) | Where-Object { Test-Path $_ }

$rows = Get-ChildItem $paths -Include *.png, *.jpg, *.jpeg, *.webp -Recurse -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 25 |
    ForEach-Object { "{0} | {1} | {2}KB" -f $_.FullName, $_.LastWriteTime.ToString('MM-dd HH:mm'), [math]::Round($_.Length / 1KB) }

$out = 'D:\flutter_projects\CarmenKarla\tool\recent_images.txt'
Set-Content -Path $out -Value $rows -Encoding utf8
Write-Output "wrote $($rows.Count) rows"
