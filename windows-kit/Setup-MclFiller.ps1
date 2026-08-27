# Setup-MclFiller.ps1 — run ONCE in PowerShell on your Windows PC.
#
# Gives you native MCL filling on THIS PC (residential IP = never blocked):
#   find-mcl "kung fu soccer"            -> list matching sessions
#   fill 014 113989 8                    -> full-house a session (ci si workers)
#   fillstatus                           -> summary of past/current fills
#
# Reqs: internet + admin-free Python install (script handles it via winget).

$ErrorActionPreference = "Stop"

# --- 1) Python (use 'py' launcher if present, else winget install) ---
$py = $null
foreach ($cand in @("py", "python3", "python")) {
    if (Get-Command $cand -ErrorAction SilentlyContinue) { $py = $cand; break }
}
if (-not $py) {
    Write-Host "[..] Installing Python via winget..."
    winget install --id Python.Python.3.12 -e --accept-source-agreements --accept-package-agreements
    $py = "python"
}

# --- 2) Clone the filler repo ---
$dir = "$env:USERPROFILE\mcl-filler"
if (-not (Test-Path $dir)) {
    git clone https://github.com/mrsmallflame-ai/mcl-filler.git $dir
    if (-not (Test-Path $dir)) { throw "clone failed — is git installed? (winget install Git.Git)" }
} else {
    Write-Host "[skip] $dir exists"
    Push-Location $dir; git pull -q; Pop-Location
}

# --- 3) venv + deps ---
Push-Location $dir
if (-not (Test-Path ".venv")) { & $py -m venv .venv }
& ".venv\Scripts\python.exe" -m pip install --quiet -r requirements.txt
Pop-Location

# --- 4) Profile helpers ---
$profileDir = Split-Path $PROFILE -Parent
New-Item -ItemType Directory -Force $profileDir | Out-Null

$helpers = @'

function find-mcl {
    # find-mcl "kung fu soccer" [-cinema "movie town"] [-date aug28]
    param(
        [Parameter(Mandatory=$true)][string]$Movie,
        [string]$Cinema = "",
        [string]$Date = ""
    )
    $args2 = @("$env:USERPROFILE\mcl-filler\mcl_find.py", "--movie", $Movie)
    if ($Cinema) { $args2 += @("--cinema", $Cinema) }
    if ($Date)   { $args2 += @("--date", $Date) }
    & "$env:USERPROFILE\mcl-filler\.venv\Scripts\python.exe" @args2
}

function fill {
    # fill <ci> <si> [workers]  e.g.  fill 014 113989 8
    param([string]$Ci = "", [string]$Si = "", [int]$Workers = 8)
    if (-not $Si) { Write-Host "usage: fill <ci> <si> [workers]"; return }
    & "$env:USERPROFILE\mcl-filler\.venv\Scripts\python.exe" `
        "$env:USERPROFILE\mcl-filler\blaze2.py" $Ci $Si $Workers
}

function fillstatus {
    & "$env:USERPROFILE\mcl-filler\.venv\Scripts\python.exe" `
        "$env:USERPROFILE\mcl-filler\mcl_status.py"
}
'@

if (-not (Test-Path $PROFILE)) {
    Set-Content -Path $PROFILE -Value $helpers
    Write-Host "[ok] profile created"
} elseif ((Get-Content $PROFILE -Raw) -notmatch "function fill ") {
    Add-Content -Path $PROFILE -Value "`n$helpers"
    Write-Host "[ok] helpers appended"
} else {
    Write-Host "[skip] helpers already present"
}

Write-Host ""
Write-Host "DONE. Restart PowerShell once, then:"
Write-Host '  find-mcl "kung fu soccer"'
Write-Host "  fill 014 113989 8"
Write-Host "  fillstatus"
