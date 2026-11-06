# Stop the app and the local Comfy API proxy. Leaves ComfyUI itself running (Windows counterpart of stop.sh).
$Port = if ($env:PORT) { $env:PORT } else { '8801' }
$ProxyPort = if ($env:PROXY_PORT) { $env:PROXY_PORT } else { '8199' }
foreach ($p in @(@($Port, 'app'), @($ProxyPort, 'proxy'))) {
    $owners = Get-NetTCPConnection -LocalPort $p[0] -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique
    foreach ($id in $owners) {
        Stop-Process -Id $id -Force -ErrorAction SilentlyContinue
        Write-Host "stopped $($p[1]) on :$($p[0]) (pid $id)"
    }
}
