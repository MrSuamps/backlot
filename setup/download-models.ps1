# Download the model files into a ComfyUI install (Windows counterpart of download-models.sh).
#   setup\download-models.ps1 C:\path\to\ComfyUI          required set (video + Krea stills)
#   setup\download-models.ps1 C:\path\to\ComfyUI -All     plus every optional mode
#   setup\download-models.ps1 -ModelsDir D:\Models        a shared models folder instead of ComfyUI\models
# The file list is read from download-models.sh so the two scripts cannot drift apart.
# Uses curl.exe (ships with Windows 10+): resumable, retries, no huggingface_hub needed.
# Set $env:HF_TOKEN for gated repos. Re-running skips files that exist and resumes partial ones.
param([string]$ComfyUI, [string]$ModelsDir, [switch]$All)
$ErrorActionPreference = 'Stop'
if (-not $ModelsDir) {
    if (-not $ComfyUI) { throw 'usage: download-models.ps1 <ComfyUI dir> [-All]   or   -ModelsDir <models dir>' }
    $ModelsDir = Join-Path $ComfyUI 'models'
}
if (-not (Test-Path $ModelsDir)) { throw "$ModelsDir does not exist; is $ComfyUI a ComfyUI checkout?" }

# Lines look like:  get <repo> <path-in-repo> <models-subfolder>. Everything after the --all test is optional.
$entries = @()
$optional = $false
foreach ($line in Get-Content (Join-Path $PSScriptRoot 'download-models.sh')) {
    if ($line -match '"\$ALL" = "--all"') { $optional = $true; continue }
    if ($line -match '^\s*get\s+(\S+)\s+(\S+)\s+(\S+)\s*$') {
        $entries += [pscustomobject]@{ Repo = $Matches[1]; Path = $Matches[2]; Sub = $Matches[3]; Optional = $optional }
    }
}
if (-not $entries) { throw 'Found no "get" lines in download-models.sh.' }

$auth = @()
if ($env:HF_TOKEN) { $auth = @('-H', "Authorization: Bearer $($env:HF_TOKEN)") }
foreach ($e in $entries) {
    if ($e.Optional -and -not $All) { continue }
    $name = Split-Path $e.Path -Leaf
    $dir = Join-Path $ModelsDir $e.Sub
    $dest = Join-Path $dir $name
    if ((Test-Path $dest) -and (Get-Item $dest).Length -gt 0) { Write-Host "have   $($e.Sub)\$name"; continue }
    New-Item -ItemType Directory -Force $dir | Out-Null
    Write-Host "fetch  $($e.Sub)\$name  <- $($e.Repo)/$($e.Path)"
    & curl.exe -L --fail -C - --retry 10 --retry-all-errors --retry-delay 5 @auth -o "$dest.part" "https://huggingface.co/$($e.Repo)/resolve/main/$($e.Path)"
    if ($LASTEXITCODE -ne 0) { throw "download failed ($LASTEXITCODE): $($e.Repo)/$($e.Path). Re-run to resume." }
    Move-Item "$dest.part" $dest
}
Write-Host 'done.'
