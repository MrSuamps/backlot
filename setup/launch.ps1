# Desktop-shortcut entry point (Windows counterpart of launch.sh). Runs start.ps1 and, since a shortcut
# has no console to print to, surfaces a failure (usually "ComfyUI is not running") as a message box.
# start.ps1 runs in this process: as a child with redirected output, the servers it spawns would inherit
# the pipe and this script would wait on it forever.
$Root = Split-Path $PSScriptRoot -Parent
$Log = Join-Path $Root 'launch.log'
$Port = if ($env:PORT) { $env:PORT } else { '8801' }
try { & (Join-Path $Root 'start.ps1') *> $Log } catch { $_ | Out-String | Add-Content $Log }
try { Invoke-WebRequest -Uri "http://127.0.0.1:$Port/api/status" -UseBasicParsing -TimeoutSec 2 | Out-Null; exit 0 } catch { }
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.MessageBox]::Show("Backlot could not start. Is ComfyUI running?`n`nDetails: $Log", 'Backlot', 'OK', 'Warning') | Out-Null
exit 1
