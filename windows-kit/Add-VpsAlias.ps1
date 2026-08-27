# Add-VpsAlias.ps1 — run ONCE in PowerShell on your Windows PC.
# Sets up: ssh alias 'vps', plus 'hermes' and 'fill' wrapper functions
# in your PowerShell profile.

$ErrorActionPreference = "Stop"
$VpsHost = "ubuntu@43.134.182.181"

# --- 1) ssh config alias ---
$sshDir = "$env:USERPROFILE\.ssh"
New-Item -ItemType Directory -Force $sshDir | Out-Null
$configPath = "$sshDir\config"

$block = @"
Host vps
    HostName 43.134.182.181
    User ubuntu
    ServerAliveInterval 30
"@

$existing = if (Test-Path $configPath) { Get-Content $configPath -Raw } else { "" }
if ($existing -notmatch "Host vps") {
    Add-Content -Path $configPath -Value "`n$block"
    Write-Host "[ok] ssh alias added -> 'vps'" 
} else {
    Write-Host "[skip] 'vps' alias already in ssh config"
}

# --- 2) PowerShell profile helpers ---
$profileDir = Split-Path $PROFILE -Parent
New-Item -ItemType Directory -Force $profileDir | Out-Null

$helpers = @'

function vh {
    # open interactive shell into the VPS
    ssh vps
}
function vhermes {
    # chat with Hermes running on the VPS from any window
    ssh -t vps "~/.hermes/hermes-agent/venv/bin/python -m hermes_cli.main chat"
}
function vfill {
    # usage: vfill <ci> <si> [workers]   e.g.  vfill 014 113989 8
    param([string]$Ci = "", [string]$Si = "", [int]$Workers = 8)
    if (-not $Si) { Write-Host "usage: vfill <ci> <si> [workers]"; return }
    ssh vps "cd ~/mcl-filler && bash vps-fill.sh $Ci $Si $Workers"
}
function vstatus {
    ssh vps "uptime; free -h | head -2; tmux ls 2>&1"
}
'@

if (-not (Test-Path $PROFILE)) {
    Set-Content -Path $PROFILE -Value $helpers
    Write-Host "[ok] profile created: $PROFILE"
} elseif ((Get-Content $PROFILE -Raw) -notmatch "function vfill") {
    Add-Content -Path $PROFILE -Value "`n$helpers"
    Write-Host "[ok] helpers appended to existing profile"
} else {
    Write-Host "[skip] helpers already present in profile"
}

Write-Host ""
Write-Host "DONE. Restart PowerShell once, then try:"
Write-Host "  ssh vps          (or just: vh)"
Write-Host "  vhermes          (chat with your agent)"
Write-Host "  vfill 014 113989 8   (mcl full house)"
Write-Host "  vstatus          (quick health check)"
