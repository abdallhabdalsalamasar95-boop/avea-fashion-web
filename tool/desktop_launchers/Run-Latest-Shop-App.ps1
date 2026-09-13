$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ProjectRoot = 'D:\flutter_projects\CarmenKarla'
$AppRoot = Join-Path $ProjectRoot 'shop_kotlin'
$ApkPath = Join-Path $AppRoot 'app\build\outputs\apk\debug\app-debug.apk'
$AppId = 'ly.carmenkarla.shop'
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$Adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'

function Write-Step([string]$Message) {
    Write-Host "[CarmenKarla-Shop] $Message" -ForegroundColor Cyan
}

function Test-CommandAvailable([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Command '$Name' was not found. Please install it and add it to PATH."
    }
}

function Update-Repository {
    Write-Step 'Checking for Git updates...'

    Test-CommandAvailable 'git'

    $status = git -C $ProjectRoot status --porcelain
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to read Git repository status.'
    }

    if ($status) {
        Write-Host '[CarmenKarla-Shop] Local changes detected; skipping git pull to protect your work.' -ForegroundColor Yellow
        return
    }

    git -C $ProjectRoot fetch --all --prune
    if ($LASTEXITCODE -ne 0) { throw 'git fetch failed.' }

    git -C $ProjectRoot pull --ff-only
    if ($LASTEXITCODE -ne 0) { throw 'git pull --ff-only failed.' }

    Write-Step 'Repository is now up to date.'
}

function Test-DeviceConnection {
    if (-not (Test-Path $Adb)) {
        throw "ADB was not found at: $Adb"
    }

    $devices = & $Adb devices | Select-String -Pattern '\sdevice$'
    if (-not $devices) {
        throw 'No connected device detected. Connect your phone and enable USB debugging, then retry.'
    }
}

function Install-LatestBuild {
    Write-Step 'Building latest Shop debug APK...'
    Set-Location $AppRoot

    & .\gradlew.bat :app:assembleDebug
    if ($LASTEXITCODE -ne 0) {
        throw 'Shop APK build failed.'
    }

    if (-not (Test-Path $ApkPath)) {
        throw "APK file not found: $ApkPath"
    }

    Write-Step 'Installing app on connected device...'
    & $Adb install -r $ApkPath
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to install Shop APK on device.'
    }

    Write-Step 'Launching app on device...'
    & $Adb shell am force-stop $AppId | Out-Null
    & $Adb shell monkey -p $AppId -c android.intent.category.LAUNCHER 1 | Out-Null

    Write-Step 'Shop app updated and launched successfully.'
}

try {
    Write-Step 'Launching latest Shop version...'
    Update-Repository
    Test-DeviceConnection
    Install-LatestBuild
}
catch {
    Write-Host "[CarmenKarla-Shop] Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
