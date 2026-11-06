# Put a Backlot shortcut on your desktop and in the Start menu (Windows counterpart of install-launcher.sh).
#
#   setup\install-launcher.ps1            # install
#   setup\install-launcher.ps1 -Remove    # take it back out
#
# Environment start.ps1 reads (PORT, PROXY_PORT, COMFYUI_URL) is not baked in; set those as user
# environment variables if you need non-default ports.
param([switch]$Remove)
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$Links = @(
    (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Backlot.lnk'),
    (Join-Path ([Environment]::GetFolderPath('Programs')) 'Backlot.lnk')
)
if ($Remove) {
    $Links | Where-Object { Test-Path $_ } | ForEach-Object { Remove-Item $_; Write-Host "removed $_" }
    exit 0
}

# Shortcuts need an .ico; build one from the PNG set with the app's own Pillow.
$Ico = Join-Path $Root 'app\icon\backlot.ico'
$Py = Join-Path $Root '.venv\Scripts\python.exe'
if (-not (Test-Path $Ico)) {
    if (-not (Test-Path $Py)) { throw 'Run .\start.ps1 once first (it creates .venv), then re-run this.' }
    & $Py -c "import sys; from PIL import Image; Image.open(sys.argv[1]).save(sys.argv[2], sizes=[(s, s) for s in (16, 32, 48, 64, 128, 256)])" `
        (Join-Path $Root 'app\icon\png\backlot-256.png') $Ico
}

$shell = New-Object -ComObject WScript.Shell
foreach ($lnk in $Links) {
    $s = $shell.CreateShortcut($lnk)
    $s.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $s.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $Root 'setup\launch.ps1')`""
    $s.WorkingDirectory = $Root
    $s.IconLocation = $Ico
    $s.Description = 'Local video and image studio on your own ComfyUI'
    $s.Save()
    Write-Host "shortcut $lnk"
}
