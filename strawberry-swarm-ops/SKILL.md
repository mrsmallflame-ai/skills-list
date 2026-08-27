---
name: strawberry-swarm-ops
description: "Operating runbook for the Strawberry Browser swarm: cline-swarm harness (workers/integrator/land-sweep), live-app QA via CDP driving, node_modules prune hazard + repair, dual-session coexistence rules."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [macos]
metadata:
  hermes:
    tags: [strawberry-clone, swarm, cline, qa, cdp]
    related_skills: [cline, coding-agents]
---

# Strawberry Swarm Ops

Runbook for building/fixing **~/Projects/strawberry-clone** with the 9-worker cline swarm and for QA-ing the real app.

## Harness map

| Piece | Path | Notes |
|---|---|---|
| Workers | `~/Projects/cline-swarm/roles/worker.sh <1-9>` | claim → per-task git worktree → prompt built via **heredoc file** (never inline giant quoted strings — a v1 quote bug crashed loops) → self-debug gate |
| Integrator | `cline-swarm/roles/integrator.sh` | copy of sb-swarm's with FIXED dedupe: `grep -qE "^${slug}( |\$)"` (old `-qx "$slug"` never matched `"slug OK"` lines → endless re-verify churn) |
| Landing sweep | `cline-swarm/scripts/land-sweep.sh` | one-shot sequential merge of today's branches; race-tolerant (verifies HEAD stability mid-build; retries around foreign integrators); resumable via `.swarm/landed.txt` |
| Status | `cline-swarm/scripts/status.sh` | counts, live workers, heartbeats, board tail |
| Queue | `<repo>/.swarm/tasks/{pending,active,done}` | mkdir locks in `.locks/`; stale recycler 240 min |
| Comms | `.swarm/comms/board.jsonl` + `LESSONS.md` | workers grep before coding, post lessons/done/blocked |

## Launch pattern (tmux ONLY)

Hermes SIGTERMs supervised background jobs at **600 s** — any worker/integrator longer than that must run detached:

```bash
for i in 1 2 3 4 5 6 7 8 9; do tmux new-session -d -s cs-w$i "PASSES=12 ~/Projects/cline-swarm/roles/worker.sh $i"; done
tmux new-session -d -s cs-integrator "CYCLES=0 ~/Projects/cline-swarm/roles/integrator.sh"
```

worker.sh protections built in: `trap '' TERM` (+ inherited by clines), per-role singleton lock (`solo-$ROLE`), STOP file (`touch $RUN/STOP`), PID guard. Gate = typecheck+build exit 0 AND `## Result` present, else DEBUG rounds feed error tails back into cline before requeue.

## Live-app QA (CDP driving)

```bash
open -n "$PWD/node_modules/electron/dist/Electron.app" --args "$PWD" --remote-debugging-port=9222
cd /tmp/qa-driver && node drive.js scenario.json   # puppeteer-core attach over CDP
```

- Driver semantics: resolve pages by URL match EVERY step (`chrome` = app://chrome/, rest newtab) — handles go stale when the app swaps views; never reuse across steps.
- Electron blocks `Target.createTarget` — create tabs by clicking the app's own "+ New tab" or CDP keyboard combos.
- Puppeteer's selector/click internals throw `startsWith` errors on `app://` pages — focus inputs via `page.evaluate(() => el.focus())` + `keyboard.type()` instead of `page.click()`.
- Renderer console errors + crashes log to **/tmp/sb-renderer.log** (hook in src/main/window.ts). Filter the CSP `unsafe-eval` noise lines.
- PRIVACY: user does schoolwork on this Mac during runs. NEVER full-screen `screencapture` (grabbed their school PDF once) — headless CDP checks only; if pixels are unavoidable, activate the app and crop to window.

## Hazards (each cost hours — do not rediscover)

1. **npm-install-through-symlink prunes shared node_modules.** Worktree node_modules symlinks to main's tree; `npm install` inside a worktree prunes it against THAT branch's lockfile (killed typescript+electron wholesale once). Repair: plain `npm install` in main repo (~35 s, cache-backed). Structural guard task = bugfix-005.
2. **Merged branches can duplicate JSON keys** in package.json (two branches add same dep). npm silently keeps last; causes lockfile drift (`npm ci` refuses). Check `grep -c '"dep"' package.json` after dep-touching merges; gate script task = bugfix-004.
3. **Two integrators racing reset each other's merges**: each runs build verification while the other mutates the tree → every merge "fails" and self-reverts (reflog shows merge→reset loops). Run EXACTLY ONE integrator; if foreign ones appear, prefer land-sweep (interference-detecting) over killing.
4. **Svelte `each_key_duplicate`** throws at runtime and freezes list UI (tab sidebar). Any `{#each}` keyed on non-unique field (title, name) will hit this once duplicates exist.
5. **Parallel dashboard session** may relaunch workers/integrators/patch scripts concurrently. Re-read files before patching; locks make double-claims safe but not double-writes of harness code.

## Bug flow

Find via CDP probe or renderer log → file `<repo>/.swarm/tasks/pending/bugfix-NNN-slug.md` (Repro evidence + Objective + Acceptance) → tmux workers fix through gate → integrator/sweep lands → rebuild + relaunch app for user test. bugfix-* sorts before qol-* so fixes jump the queue.
