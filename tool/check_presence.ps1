$ErrorActionPreference = 'Continue'
$base = 'https://carmenkarla-backend.onrender.com'
$envLine = Get-Content 'D:\flutter_projects\CarmenKarla\local_server_py\.env' |
    Where-Object { $_ -match '^\s*API_TOKEN\s*=' } | Select-Object -First 1
$token = ($envLine -split '=', 2)[1].Trim().Trim('"').Trim("'")
$headers = @{ Authorization = "Bearer $token" }

for ($i = 0; $i -lt 25; $i++) {
    try {
        $p = Invoke-RestMethod -Uri "$base/admin/presence" -Headers $headers -TimeoutSec 60
        if ($null -ne $p.PSObject.Properties['enabled']) { break }
    } catch { }
    Start-Sleep -Seconds 15
}
Write-Output ("enabled={0} showNames={1} online={2} app={3} web={4} signedIn={5}" -f `
    $p.enabled, $p.showNames, $p.online, $p.onlineApp, $p.onlineWeb, $p.signedIn)
Write-Output "visitors: $($p.visitors.Count)"
$p.visitors | ForEach-Object {
    "  platform={0} signedIn={1} here={2}s ago={3}s screen='{4}'" -f $_.platform, $_.signedIn, $_.secondsHere, $_.secondsAgo, $_.screen
}
