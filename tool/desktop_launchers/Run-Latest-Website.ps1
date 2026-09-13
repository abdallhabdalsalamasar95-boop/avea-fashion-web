$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ProjectRoot = 'D:\flutter_projects\CarmenKarla'
$WebRoot = Join-Path $ProjectRoot 'web_storefront'
$Port = 3000
$Url = "http://localhost:$Port"

function Write-Step([string]$Message) {
    Write-Host "[CarmenKarla] $Message" -ForegroundColor Cyan
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
        Write-Host '[CarmenKarla] Local changes detected; skipping git pull to protect your work.' -ForegroundColor Yellow
        return
    }

    git -C $ProjectRoot fetch --all --prune
    if ($LASTEXITCODE -ne 0) {
        throw 'git fetch failed.'
    }

    git -C $ProjectRoot pull --ff-only
    if ($LASTEXITCODE -ne 0) {
        throw 'git pull --ff-only failed. Check branch status or conflicts.'
    }

    Write-Step 'Repository is now up to date.'
}

function Update-NodeDependencies {
    Test-CommandAvailable 'npm'

    Write-Step 'Updating website dependencies...'
    Set-Location $WebRoot

    if (-not (Test-Path (Join-Path $WebRoot 'node_modules'))) {
        if (Test-Path (Join-Path $WebRoot 'package-lock.json')) {
            npm ci
        }
        else {
            npm install
        }
    }
    else {
        npm install --no-audit --no-fund
    }

    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to install or update website dependencies.'
    }
}

function Start-WebServerIfNeeded {
    $isUp = Test-NetConnection -ComputerName 'localhost' -Port $Port -InformationLevel Quiet
    if ($isUp) {
        Write-Step 'Local server is already running. Opening website...'
        Start-Process $Url
        return
    }

    Write-Step 'Starting local website server (Next.js)...'
    $command = "Set-Location '$WebRoot'; npm run dev"
    Start-Process powershell -ArgumentList @('-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $command) -WindowStyle Minimized | Out-Null

    $maxAttempts = 90
    for ($i = 0; $i -lt $maxAttempts; $i++) {
        if (Test-NetConnection -ComputerName 'localhost' -Port $Port -InformationLevel Quiet) {
            Write-Step 'Website is ready. Opening in browser...'
            Start-Process $Url
            return
        }
        Start-Sleep -Seconds 1
    }

    throw "Server did not start on port $Port within the expected time."
}

try {
    Write-Step 'Launching latest website version...'
    Update-Repository
    Update-NodeDependencies
    Start-WebServerIfNeeded
    Write-Step 'Done successfully.'
}
catch {
    Write-Host "[CarmenKarla] Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
