$ErrorActionPreference = 'Continue'
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
Set-Location 'D:\flutter_projects\CarmenKarla\shop_kotlin'
$log = 'D:\flutter_projects\CarmenKarla\lint.log'
& .\gradlew.bat :app:lintVitalRelease *>&1 | Out-File -FilePath $log -Encoding utf8
$joined = (Get-Content $log -Raw -Encoding utf8) -replace "`r?`n", ' <NL> '
[regex]::Matches($joined, '(Error:|error:).{0,260}') | Select-Object -First 12 |
    ForEach-Object { ($_.Value -replace ' <NL> ', ' ') }
Write-Output '--- report files ---'
Get-ChildItem 'D:\flutter_projects\CarmenKarla\shop_kotlin\app\build\reports' -Recurse -File -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty FullName
