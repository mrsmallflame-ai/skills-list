---
name: money-swarm-ops
description: "Trigger: 'run up the swarm on making money', 'launch/steer/status the money-swarm', 'make money now'. Operating runbook for the Ben-Awad-style autonomous business swarm at ~/Projects/money-swarm: relaunch checklist (fcc-server proxy first), revenue-mode steering doctrine, owner-brief pattern, Gumroad + x402 channels."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [macos]
metadata:
  hermes:
    tags: [money-swarm, swarm, revenue, x402, fcc-codex]
    related_skills: [swarm, cline]
---

# money-swarm ops

Project: `~/Projects/money-swarm` — CEO (orchestrates, owns GOAL.md strategy, writes daily HTML report) + watcher (recycles stale tasks, restarts dead sessions, zero tokens) + N workers, all tmux sessions prefixed `mswarm-*`. Coordination is a plain-file board under `state/tasks/{pending,active,done}`; launcher is `./swarm.sh up <N>|status|down|logs|attach`. Engine: fcc-codex `-m open_router/stealth/ox-alpha`.

## Relaunch checklist (do in order)

1. **Engine prerequisite FIRST:** every agent call runs fcc-codex, which hard-requires the local proxy `fcc-server` on :8082. After a Mac restart every call dies rc=1 instantly (signature: log spam of `Free Claude Code proxy is not reachable at http://127.0.0.1:8082` + `agent call failed rc=1 (attempt N)` in `state/logs/swarm.log`). Fix: `tmux new-session -d -s fcc-server "/opt/homebrew/bin/fcc-server >>/tmp/fcc-server.log 2>&1"`, verify `lsof -i :8082`. In-flight lib.sh retry loops (~20 min patience) recover automatically once it's listening — no fleet restart needed.
2. Consent gate may block a manual engine probe when the user is AFK → treat as "skip probe, assume risk"; workers' own runs inside tmux are NOT gated.
3. **PATH:** export `PATH="/opt/homebrew/bin:$HOME/.local/bin:$PATH"` before calling `./swarm.sh` (bare shells lack homebrew → `tmux: command not found`). Inside any tmux session command use ABSOLUTE binary paths (e.g. `/opt/homebrew/bin/node`) — the tmux shell doesn't inherit your exports.
4. Sweep board: leftover `state/tasks/.locks/*.lock` dirs are harmless (claims are mkdir-based); empty pending+active means workers will idle-poll — seed pending task files BEFORE `up` for instant claims.
5. Launch `./swarm.sh up 5` (user approved heavy parallel token spend; stock default is 3). Verify within ~90 s: `./swarm.sh status`, `ls state/tasks/active/` shows `worker-wN__NNN-*` claims, count real agents with `ps aux | grep "[f]cc-codex exec" | grep -c workspace-write` — bare `pgrep -f` multiplies phantoms through pipeline members.
6. Shutdown is ONLY `./swarm.sh down`; never pkill.

## Steering doctrine (hard-won)

Observed failure mode (2026-08-23→25): 92 tasks done, $0 realized — the CEO spiraled into internal-QA make-work (validators, auditors, consoles, cover sheets, checksum manifests *about its own process*) while deferring all action to "owner gates". Workers idled out with an empty queue.

Fix = operator rewrite of the `## Current Strategy` section of `state/GOAL.md` (README sanctions human steering there):
- Explicitly BAN the process-artifact genres by name; allow only three task kinds: **PRODUCT** (complete ready-to-list pack), **DISTRIBUTION** (paste-ready buyer-facing copy), **OWNER-UNBLOCK** (shrink time-to-first-dollar into ONE file).
- Freeze finished assets ("Scope Guard is DONE, do not rebuild") — otherwise the CEO re-audits them forever.
- **Workers' codex sandbox has NO network access** — every online-research/bounty task returned DNS NO-GO. The operator does web research and bakes findings directly INTO task files.
- Task-spec shape that works: exact deliverable file tree, content-quality bars ("no lorem ipsum, no invented testimonials"), acceptance criteria, explicit OFFLINE note, mandatory truthful `## Result`.
- The CEO self-queues ~1–3 tasks per 15-min cycle; before queueing anything yourself, take the next free NNN across ALL lifecycle dirs (pending/active/done/accepted/superseded) — concurrent dispatch produced duplicate-number false-dones on 08-25.

## Owner-brief pattern

Scattered HUMAN ACTION items across dozens of Result sections = the actual bottleneck. Compress into ONE operator brief (`state/MONEY-NOW.md`): pre-decide everything decidable (prices, refund policy wording, coupon on/off), leave only credential-bound steps (account signup, payout connect, publish), cite exact source-file paths per step, include fee math and an honest-expectations section. Pair with `state/X402-GUIDE.md` for the agent-economy channel.

## Channels

- **Gumroad-first consumer channel:** listing fields ready in `state/work/listing-sync-pack/gumroad-fields.txt`; tier ZIPs extractable from `state/work/release-candidate-bundle-087/scope-guard-release-candidate.zip`.
- **x402 agent-economy channel (live 2026-08-26):** seller server at `~/Projects/money-swarm/x402/server.js` — see `references/x402-selling.md` for protocol specifics, facilitator constraints, and verification recipe.

## Pitfalls

- Never edit `roles/*.sh` or `lib.sh` while the fleet runs (bash reads incrementally — same corruption rule as the cline harness).
- Telegram notify (`.env`) is unconfigured → `tg_report` no-ops silently; daily reports still land in `state/reports/report-YYYY-MM-DD.html`.
- `./swarm.sh logs wN` fails — log filenames are `worker-wN.log` / `ceo.log` / `watcher.log` under `state/logs/`.
- Consent-gate AFK reroutes that fired here: no manual fcc-codex probes (skip them), never generate/store private keys for the user (x402 PAY_TO stays a user-supplied env var), prefer starting NEW tmux session names/ports over kill-session batches.