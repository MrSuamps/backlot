# Start Backlot against a ComfyUI that is already running (Windows counterpart of start.sh).
#
#   .\start.ps1                                       ComfyUI on http://127.0.0.1:8188 (the default)
#   $env:COMFYUI_URL = 'http://127.0.0.1:8189'; .\start.ps1
#
# What this does:
#   1. starts comfy-api-proxy on :8199 in front of your ComfyUI (the Comfy Developer
#      Platform API, served locally), unless something already answers there;
#   2. starts the app on :8801 and opens it.
# Both run hidden in the background and log to proxy.log / app.log; .\stop.ps1 ends them.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$ComfyUrl = if ($env:COMFYUI_URL) { $env:COMFYUI_URL.TrimEnd('/') } else { 'http://127.0.0.1:8188' }
$ProxyPort = if ($env:PROXY_PORT) { $env:PROXY_PORT } else { '8199' }
$Port = if ($env:PORT) { $env:PORT } else { '8801' }
$Venv = Join-Path $PSScriptRoot '.venv'
$Py = Join-Path $Venv 'Scripts\python.exe'

function Test-Url([string]$Url, [int]$TimeoutSec = 2) {
    try { Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSec | Out-Null; return $true } catch { return $false }
}

function Wait-Url([string]$Url) {
    for ($i = 0; $i -lt 40; $i++) {
        if (Test-Url $Url 1) { return $true }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

if (-not (Test-Path $Py)) {
    Write-Host 'No .venv yet, creating one and installing requirements...'
    $sysPy = Get-Command py -ErrorAction SilentlyContinue
    if ($sysPy) { & py -3 -m venv $Venv } else { & python -m venv $Venv }
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $Py)) { throw 'Could not create .venv. Install Python 3.10+ and make sure "py" or "python" is on PATH.' }
    & $Py -m pip install -q -r requirements.txt
    if ($LASTEXITCODE -ne 0) { throw 'pip install -r requirements.txt failed.' }
}

if (-not (Test-Url "$ComfyUrl/system_stats")) {
    Write-Error "ComfyUI is not answering at $ComfyUrl. Start ComfyUI first, or set `$env:COMFYUI_URL."
    exit 1
}

if (-not (Test-Url "http://127.0.0.1:$ProxyPort/api/v2/health" 1)) {
    New-Item -ItemType Directory -Force '.proxy-state' | Out-Null
    $proxy = Join-Path $Venv 'Scripts\comfy-api-proxy.exe'
    Start-Process -FilePath $proxy -WindowStyle Hidden `
        -ArgumentList @('run', '--comfyui', $ComfyUrl, '--port', $ProxyPort, '--state-dir', '.proxy-state') `
        -RedirectStandardOutput 'proxy.log' -RedirectStandardError 'proxy.err.log'
    if (-not (Wait-Url "http://127.0.0.1:$ProxyPort/api/v2/health")) { throw "comfy-api-proxy did not come up on :$ProxyPort; see proxy.err.log" }
}

# Inherited by the app process. PYTHONUTF8 keeps text files and logs UTF-8 instead of the ANSI code page.
$env:BACKLOT_COMFY_URL = "http://127.0.0.1:$ProxyPort"
$env:BACKLOT_COMFYUI_URL = $ComfyUrl
$env:PORT = $Port
$env:PYTHONUTF8 = '1'
$env:PYTHONUNBUFFERED = '1'
if (-not (Test-Url "http://127.0.0.1:$Port/api/status" 1)) {
    Start-Process -FilePath $Py -WindowStyle Hidden -ArgumentList @('app\server.py') `
        -RedirectStandardOutput 'app.log' -RedirectStandardError 'app.err.log'
    if (-not (Wait-Url "http://127.0.0.1:$Port/api/status")) { throw "Backlot did not come up on :$Port; see app.err.log" }
}

Write-Host "Backlot -> http://localhost:$Port   (Comfy API: $($env:BACKLOT_COMFY_URL) -> $ComfyUrl)"
if (-not $env:BACKLOT_NO_OPEN) { Start-Process "http://localhost:$Port" }
