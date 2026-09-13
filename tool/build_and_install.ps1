$ErrorActionPreference = 'Continue'
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$root = 'D:\flutter_projects\CarmenKarla'

foreach ($app in @(@{ dir = 'shop_kotlin'; name = 'shop' }, @{ dir = 'admin_kotlin'; name = 'admin' })) {
    Set-Location (Join-Path $root $app.dir)
    $log = Join-Path $root ("build_" + $app.name + ".log")
    & .\gradlew.bat :app:assembleDebug *>&1 | Out-File -FilePath $log -Encoding utf8
    $joined = (Get-Content $log -Raw -Encoding utf8) -replace "`r?`n", ' <NL> '
    if ($joined -match 'BUILD SUCCESSFUL') {
        Write-Output "$($app.name): BUILD SUCCESSFUL"
    } else {
        Write-Output "$($app.name): BUILD FAILED"
        [regex]::Matches($joined, 'e: file:.{0,180}') | Select-Object -First 12 |
            ForEach-Object { ($_.Value -replace ' <NL> ', ' ') -replace '.*/java/ly/carmenkarla/', '' }
    }
    Remove-Item $log -Force -ErrorAction SilentlyContinue
}

$devices = & $adb devices | Select-String -Pattern '\sdevice$'
if (-not $devices) {
    Write-Output 'NO DEVICE - connect the phone and rerun'
    exit 0
}
& $adb install -r (Join-Path $root 'shop_kotlin\app\build\outputs\apk\debug\app-debug.apk')
& $adb install -r (Join-Path $root 'admin_kotlin\app\build\outputs\apk\debug\app-debug.apk')
& $adb shell am force-stop ly.carmenkarla.shop
& $adb shell monkey -p ly.carmenkarla.shop -c android.intent.category.LAUNCHER 1 | Out-Null
Write-Output 'installed and launched'
