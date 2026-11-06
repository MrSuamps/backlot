# Clone the node packs the studio's graphs use into a ComfyUI install (Windows counterpart of install-nodes.sh).
#   setup\install-nodes.ps1 C:\path\to\ComfyUI
# Uses ComfyUI's own Python: venv\ (git or Stability Matrix installs) or ..\python_embeded\ (portable build).
# Packages ComfyUI already has (torch, numpy, opencv) are pinned so a node's requirements cannot replace them.
param([Parameter(Mandatory = $true)][string]$ComfyUI)
$ErrorActionPreference = 'Stop'
$Nodes = Join-Path $ComfyUI 'custom_nodes'
if (-not (Test-Path $Nodes)) { throw "$Nodes does not exist; is $ComfyUI a ComfyUI checkout?" }

$Py = @(
    (Join-Path $ComfyUI 'venv\Scripts\python.exe'),
    (Join-Path $ComfyUI '..\venv\Scripts\python.exe'),
    (Join-Path $ComfyUI '..\python_embeded\python.exe')
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Py) { $Py = 'python'; Write-Warning "No ComfyUI venv found; installing node requirements with '$Py' from PATH." }
Write-Host "python $Py"

$Constraints = Join-Path $env:TEMP 'backlot-node-constraints.txt'
& $Py -m pip freeze | Where-Object { $_ -match '^(torch|torchvision|torchaudio|numpy|opencv-[a-z-]+|pillow)(==| @ )' } |
    Set-Content -Encoding ascii $Constraints

function Install-Pack([string]$Url, [string]$Dir, [string]$Commit) {
    $path = Join-Path $Nodes $Dir
    if (Test-Path $path) { Write-Host "have   $Dir" }
    else {
        Write-Host "clone  $Dir"
        if ($Commit) { git clone -q $Url $path; git -C $path checkout -q $Commit } else { git clone -q --depth 1 $Url $path }
        if ($LASTEXITCODE -ne 0) { throw "git clone failed for $Url" }
    }
    $req = Join-Path $path 'requirements.txt'
    if (Test-Path $req) {
        & $Py -m pip install -q -c $Constraints -r $req
        if ($LASTEXITCODE -ne 0) { Write-Warning "requirements for $Dir failed; check manually" }
    }
}

Install-Pack 'https://github.com/city96/ComfyUI-GGUF' 'ComfyUI-GGUF'
Install-Pack 'https://github.com/kijai/ComfyUI-KJNodes' 'ComfyUI-KJNodes'
# Multishot from Arfolomew's fork: one-line fix so audio guides and reference audio can share a graph.
Install-Pack 'https://github.com/Arfolomew/ComfyUI-H3-Multishot' 'ComfyUI-H3-Multishot'
Install-Pack 'https://github.com/NikoDemon80/ComfyUI-H3-Motion-Context' 'ComfyUI-H3-Motion-Context'
# Its requirements-no-cupy.txt is all Backlot needs: RIFE runs without cupy.
Install-Pack 'https://github.com/Fannovel16/ComfyUI-Frame-Interpolation' 'comfyui-frame-interpolation'
$fi = Join-Path $Nodes 'comfyui-frame-interpolation\requirements-no-cupy.txt'
if (Test-Path $fi) { & $Py -m pip install -q -c $Constraints -r $fi }
Install-Pack 'https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler' 'ComfyUI-SeedVR2_VideoUpscaler'
Install-Pack 'https://github.com/lbouaraba/comfyui-krea2edit' 'comfyui-krea2edit'
# Character Swap: akatz's H3 Relay (SAM-masked swap + windowed continuation), pinned to the tested commit.
Install-Pack 'https://github.com/akatz-ai/h3-relay' 'h3-relay' '8c313cc6bd23298be3b475d95a3af4cde6e7f10b'

# Audio tab: one small node that saves 32-bit float WAV (the stock SaveAudio clips YuE2's overs).
Copy-Item (Join-Path $PSScriptRoot 'save_audio_float_wav.py') (Join-Path $Nodes 'save_audio_float_wav.py')
Write-Host 'copied save_audio_float_wav.py'
Write-Host 'done. Restart ComfyUI.'
