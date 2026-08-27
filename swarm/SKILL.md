---
name: swarm
description: "Trigger phrases: 'swarm up (project)', 'launch the swarm at/on (project)', 'run a cline swarm on (project)'. Launches the generic cline CLI swarm (~/Projects/swarm) at any project: resolves local/clone, probes engine, launches tmux workers + integrator, optionally queues user-stated tasks first."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [macos]
metadata:
  hermes:
    tags: [swarm, cline, delegation, multi-agent, automation]
    related_skills: [cline, coding-agents]
---

# swarm — launch a Cline swarm at any project

CLI already installed at `~/.local/bin/swarm` (harness: `~/Projects/swarm/`). Full docs: `~/Projects/swarm/README.md`.

## When the user says "swarm up <project>" / "launch swarm on X"

### 1. Resolve the project (in this order, stop at first hit)
1. `~/Projects/<project>` exists → use it.
2. Fuzzy-match `ls -d ~/Projects/*/ | grep -i <project>` — one clear match → use it; ambiguous → ask once.
3. Not local → `gh repo list mrsmallflame-ai --limit 50 | grep -i <project>`; found → `gh repo clone mrsmallflame-ai/<name> ~/Projects/<name>`; not found → tell the user, do NOT invent a repo.

**Project-specific launcher wins:** some projects (e.g. money-swarm) ship their own harness (`./swarm.sh up N`) with custom roles (CEO/watcher) and state boards — use THEIR launcher when it exists instead of the generic CLI. Ops details: see `references/money-swarm-ops.md` (fcc-server proxy dependency, tmux PATH, revenue-mode steering).

### 2. Queue stated tasks BEFORE launching (if the user named work)
If their message includes actual work ("...and add dark mode"), write one spec file per task to `<repo>/.swarm/tasks/pending/NNN-slug.md`: Goal / Files-to-touch hints / Acceptance. Keep each self-contained (workers read ONLY the spec). If no tasks stated, existing pending board is the workload — say what's queued.

### 3. Launch
```bash
swarm up ~/Projects/<name>            # defaults: 5 workers, 6 passes each
# more muscle: swarm up <path> 9 12
```
This auto-probes the engine (one tiny cline run) and REFUSES to launch if mass-abort mode is detected ("ENGINE UNHEALTHY") — then just report that; do not retry-spam or hand-roll worker loops.

### 4. Verify within ~90s, then report
```bash
swarm status ~/Projects/<name>
```
Confirm: stack detected, pending count, ≥1 active claim, tmux sessions listed. Report one line: repo, stack, board counts, session prefix (`sw-<slug>-w*`).

## Rules
- ALWAYS launch via `swarm up` (tmux-hosted). NEVER Hermes background terminals — they get SIGTERM-killed at ~600s and orphan the fleet.
- NEVER edit `~/Projects/swarm/roles/*.sh` while a fleet runs.
- Custom verify gate needed? Create `<repo>/.swarm/profile.sh` with `SW_VERIFY_CMD='...'` before `up`.
- Shutdown is `swarm stop <repo>` — never pkill.
- Concurrent swarms on different repos are safe (all guards are repo-scoped).

## Status checks later ("how's the swarm")
`swarm status <repo>` + `git -C <repo> log --oneline -5` for integrator merges.

## Known fleets with their OWN harnesses (not this CLI)
- **money-swarm** (`~/Projects/money-swarm`, `./swarm.sh up N|status|down`) — Ben-Awad-style "make money" business swarm on fcc-codex/ox-alpha with CEO/watcher/worker file-board roles. Full operating runbook (relaunch checks incl. fcc-server proxy prerequisite, steering protocol, offline-worker constraint, $0-audit-loop post-mortem): `references/money-swarm-runbook.md`.
