# Windows PC → VPS Kit

One-time setup that gives your Windows PC permanent one-word commands into the
workhorse VPS. Assumes the Windows SSH key (`hermes@mrsma-windows`) is already
authorized on the VPS — it is.

## Install (once)

Open **PowerShell** and run:

```powershell
irm https://raw.githubusercontent.com/mrsmallflame-ai/omp-gstack-skills/main/windows-kit/Add-VpsAlias.ps1 | iex
```

(If that URL 404s because we haven't pushed yet: copy `Add-VpsAlias.ps1` to the
PC any way you like and run `. \Add-VpsAlias.ps1`.)

Restart PowerShell when it says so.

## What you get

| Command | Does |
|---|---|
| `vh` | interactive shell on the VPS |
| `vhermes` | chat with Hermes agent on the VPS |
| `vfill <ci> <si> [workers]` | launch mcl full-house filler (e.g. `vfill 014 113989 8`) |
| `vstatus` | uptime / memory / running tmux sessions |

## Notes

- Commands work from any PowerShell window, no cd'ing needed.
- If the Mac relay isn't up, `vfill` will fail its health check with a clear
  message — start `mac-relay.sh` on the Mac first, or wire the residential
  proxy into `~/.bashrc` on the VPS for relay-free filling.
- To undo: delete the `Host vps` block from `%USERPROFILE%\.ssh\config` and the
  helper functions from your PowerShell profile.
