$ErrorActionPreference = 'Continue'
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$root = 'D:\flutter_projects\CarmenKarla'
$log = Join-Path $root 'release_build.log'

Set-Location (Join-Path $root 'shop_kotlin')
& .\gradlew.bat :app:assembleRelease *>&1 | Out-File -FilePath $log -Encoding utf8
$joined = (Get-Content $log -Raw -Encoding utf8) -replace "`r?`n", ' <NL> '
if ($joined -notmatch 'BUILD SUCCESSFUL') {
    Write-Output 'RELEASE BUILD FAILED'
    [regex]::Matches($joined, '(e: file:|FAILURE:|What went wrong:).{0,220}') | Select-Object -First 10 |
        ForEach-Object { ($_.Value -replace ' <NL> ', ' ') }
    Remove-Item $log -Force -ErrorAction SilentlyContinue
    exit 1
}
Remove-Item $log -Force -ErrorAction SilentlyContinue

$apk = Join-Path $root 'shop_kotlin\app\build\outputs\apk\release\app-release.apk'
if (-not (Test-Path $apk)) {
    Write-Output "release apk not found at $apk"
    Get-ChildItem (Join-Path $root 'shop_kotlin\app\build\outputs\apk') -Recurse -Filter *.apk |
        Select-Object -ExpandProperty FullName
    exit 1
}
$dest = Join-Path $root 'web_storefront\public\avea-fashion.apk'
Copy-Item $apk $dest -Force
$mb = [math]::Round((Get-Item $dest).Length / 1MB, 1)
Write-Output "RELEASE OK - published $mb MB to public/avea-fashion.apk"
