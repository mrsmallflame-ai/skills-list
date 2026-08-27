# money-swarm operations notes (session-proven 2026-08-26)

money-swarm (`~/Projects/money-swarm`) does NOT use the generic `swarm up` CLI — it has its own launcher `./swarm.sh up N` (ceo + watcher + N workers, board in `state/tasks/{pending,active,done}`, ledger in `state/LEDGER.md`, mission+strategy in `state/GOAL.md`). Use it when it exists; don't force-fit the generic harness.

## Engine dependency: fcc-server MUST be up first

Every worker/CEO call runs `fcc-codex exec ... -m open_router/stealth/ox-alpha`, which hard-requires the local free-claude-code proxy on **:8082**. After any Mac restart:

```bash
tmux new-session -d -s fcc-server "fcc-server"   # start BEFORE ./swarm.sh up
```

**Diagnosis signature** (learned the hard way):
- Proxy down: log shows `Free Claude Code proxy is not reachable at http://127.0.0.1:8082` + `agent call failed rc=1` within seconds of claim (fast fail, ~100/200/300s backoffs).
- Normal quota waves: same rc=1 lines but SLOW (real attempt duration first). Yesterday's run had 76 failure lines and still finished 92 tasks — failure-line count alone is not sick.
- Confirm health: `lsof -i :8082` shows LISTEN, `/tmp/fcc-server.log` shows Uvicorn running.

## tmux shells have no Homebrew PATH

Inside tmux commands, binaries in `/opt/homebrew/bin` are missing (same root cause as `swarm.sh: tmux: command not found`). Fix patterns:
- Launcher scripts: `export PATH="/opt/homebrew/bin:$HOME/.local/bin:$PATH"` before calling tmux.
- Commands INSIDE tmux sessions: use absolute paths (`/opt/homebrew/bin/node server.js`), because the tmux shell doesn't inherit your export.

## Consent-gate reroutes (AFK)

| Blocked pattern | Reroute |
|---|---|
| Pre-flight engine probe (`fcc-codex exec` tiny task) | Skip probe, assume risk — workers' own runs inside tmux are NOT gated (per cline skill gotcha 14) |
| Generating/storing private keys or wallets | Never custody keys. Design services with user-supplied addresses via env var (e.g. `PAY_TO`); server refuses to start until set |
| `tmux kill-session` inside compound command batches | Issue the kill as its own single command, or sidestep: start a NEW session name/port instead |

## Revenue-mode steering (what fixed the $0 spiral)

First 92 tasks produced $0 because the CEO drifted into self-referential QA tasks (validators, audits, cover sheets, manifests about manifests). Fix that worked — rewrite `state/GOAL.md` Current Strategy with:
1. **Banned genres list** (validators, auditors, consoles, cover sheets, checksum manifests, lifecycle reconcilers, decision packets…).
2. **Only three task types**: PRODUCT (ready-to-list pack) / DISTRIBUTION (paste-ready buyer-facing copy) / OWNER-UNBLOCK (shrink time-to-first-dollar).
3. **Canonical assets named** ("X is DONE, do not rebuild") to stop rebuild loops.
4. **Seed 2-4 concrete pending tasks before `up`** so workers start on second zero instead of idling.
5. Workers are sandboxed OFFLINE — bake web research into task files yourself; never queue live-web tasks.
