# money-swarm operating runbook (~/Projects/money-swarm)

Ben Awad-style "make as much money as possible" business swarm. Runs its OWN harness — NOT the generic `swarm` CLI. Engine: `fcc-codex exec --sandbox workspace-write -m open_router/stealth/ox-alpha` via `lib.sh agent()` (retry patience ~20 min for quota waves). Roles: ceo (orchestrates, owns GOAL.md strategy, daily HTML report), watcher (zero-token keepalive: recycles stale actives, restarts dead sessions), w1..wN workers (claim via mkdir locks).

## Relaunch checklist (in order)

1. **fcc-server proxy MUST be up first** — every fcc-codex call hard-requires localhost:8082. Signature when down: instant rc=1 + `Free Claude Code proxy is not reachable at http://127.0.0.1:8082`. Fix: `tmux new-session -d -s fcc-server "fcc-server >> /tmp/fcc-server.log 2>&1"` then confirm LISTEN via `lsof -i :8082`. See cline skill gotcha 17.
2. Export PATH before launching (`export PATH="/opt/homebrew/bin:$HOME/.local/bin:$PATH"`) — `swarm.sh` calls tmux directly; lib.sh self-heals PATH only inside roles.
3. Sweep stale claim locks: `state/tasks/.locks/*.lock` dirs (mkdir-lock claims leave them behind on crash).
4. Board reconcile across ALL lifecycle folders: pending/ active/ done/ accepted/ superseded/. Same NNN can coexist in two folders after concurrent dispatch — keep the authoritative one.
5. Launch: `cd ~/Projects/money-swarm && ./swarm.sh up 5`. Verify in ~90s: `./swarm.sh status`, claims appearing in state/tasks/active/, `ps aux | grep "[f]cc-codex exec" | grep -c workspace-write` (pgrep -fl multiplies phantoms).
6. Workers' agent runs are NOT consent-gated (they're inside tmux) even when the user is AFK and Hermes-side probes get gated — skip probes, assume risk, verify via logs instead.

## Worker constraint: OFFLINE

The codex sandbox blocks network. Every online task (bounty-site reachability, marketplace research) failed as DNS NO-GO in the 08-25 run. Never queue web-access tasks. Operator (Hermes) has real browser/web access: do discovery yourself and bake findings into fully self-contained task specs.

## Steering protocol (human/operator lever)

- Edit `state/GOAL.md` "## Current Strategy" while fleet is DOWN (or drop specs into state/tasks/pending/) — README designates this as the once-per-day steering prompt.
- Task files: `NNN-short-slug.md`, NNN = next free number checked across pending/active/done/accepted/superseded. Self-contained: exact deliverable tree, acceptance criteria, truthful `## Result` requirement. Workers read ONLY the spec.
- Seed 4+ tasks BEFORE `up` so workers claim on second zero instead of idling until the CEO's first cycle.

## Post-mortem: the $0 run (92 tasks, 2026-08-23→25)

Three compounding failures, all fixed 2026-08-26 via GOAL.md rewrite:

1. **Offline workers assigned online work** → dozens of honest-but-useless DNS NO-GO cycles.
2. **Strategy drift into internal-QA genre**: validators, auditors, consoles, cover sheets, checksum manifests, decision packets, routing kits — artifacts ABOUT the process, not sellable products. Each passed its own acceptance gate while revenue stayed $0.
3. **HUMAN ACTION items scattered across ~100 Result sections** → owner could not find the ≤30-min launch path for the finished product.

Fixes now encoded in GOAL.md strategy: BANNED-GENRES list; only three task classes allowed (PRODUCT = ready-to-list pack, DISTRIBUTION = paste-ready buyer-facing copy, OWNER-UNBLOCK = shrinks time-to-first-dollar, output ONLY to state/OWNER-ACTIONS.md); Scope Guard release ZIP is frozen canonical asset (do not rebuild/re-audit).

## State map

`state/GOAL.md` (mission + strategy) · `LEDGER.md` (honest revenue AND spend) · `lessons.md` (append-only) · `tasks/{pending,active,done,accepted,superseded}/` · `work/<slug>/` (artifacts; scope-guard-kit/ + release-candidate-bundle-087/ = finished $29/$59/$149 product) · `reports/report-YYYY-MM-DD.html` · `logs/<role>.log`.

Monitor: `./swarm.sh status` · `./swarm.sh logs <role> -f` · stop: `./swarm.sh down` (never pkill; watcher resurrects sessions anyway).
