---
name: build-swarms
description: Build and operate long-running multi-agent build swarms — task boards, worker loops, per-task worktrees, gated integrator merges, serialization through rate-limited proxies, sandbox constraints. Use when spawning autonomous build fleets, designing task-board systems for coding agents, or debugging swarm behavior (stuck tasks, leaked locks, churn loops, empty LLM replies).
---

# Build Swarms

Operating model proven across two production swarms (money-making business swarm; browser-clone build swarm running 130+ completed tasks). Architecture: CEO/planner writes numbered task files → workers claim via atomic locks → execute inside per-task git worktrees → integrator merges serially with typecheck+build gates → watcher guards RAM/heals deps → QA sweeps conformance checkers.

## The five bugs that WILL bite you (all found the hard way)

1. **Lock leaks kill tasks forever.** Every code path that creates a claim lock must release it — finish, requeue, AND recycle. A leaked lock makes its task silently unclaimable (claim = mkdir fails → skip). Symptom: workers idle while pending queue is full. Fix: sweep at claim time — remove any lock whose task has no live `active/` entry.
2. **nullglob + failed glob = silent sweep no-op.** Under `shopt -s nullglob`, a non-matching glob vanishes, so `ls "$dir"/*"$name"` becomes bare `ls "$dir"` which exits 0 → your "is it claimed?" check always passes → sweep never deletes. Use explicit per-entry loops with `[ -e ]`, never globs-in-conditionals.
3. **`mv` preserves mtime.** Stale-recycle based on file age will steal IN-FLIGHT work if files carry old creation mtimes. `touch` at claim time, and set STALE_MINUTES above your longest legit task duration (max-reasoning agent calls run 30–90 min). A keep-fresh touch loop over `active/*.md` is cheap insurance during long runs.
4. **Concurrent calls to rate-limited local proxies return EMPTY responses.** One agent call at a time, globally serialized (mkdir slot with staleness steal). Symptom: identical small token counts (~5k) per "completed" call, no output text, instant requeue churn. Solo probe succeeds while fleet fails = concurrency limit.
5. **Executor sandboxes derive writability from session cwd.** fcc-codex workspace-write root = cwd. Workers must be launched FROM the repo root, and the task board must live INSIDE the repo (gitignored `.swarm/`) so agents can write both code and board files. Wrong cwd = every write denied, agents bail with HUMAN ACTION REQUIRED lines.

## Integration pipeline

Per-task git worktree off main (`git worktree add -b sb/<slug> .swarm/wt/<slug> main`) → symlink shared node_modules (agents have no registry network) → work → typecheck+build in worktree → commit on branch → integrator merges serially into main with build gates.

Integrator rules:
- On gate failure: reset ONLY its own merge commit (compare HEAD subject) — blind `reset --hard HEAD~1` in a retry loop erases everyone else's commits.
- Before merging: checkout-discard tracked dirt (QA builds dirty tsbuildinfo-style artifacts) and move untracked artifact files aside; untracked-but-tracked-on-branch collisions abort merges confusingly.
- Strip executor-committed junk from branch tips before merge (node_modules symlinks get committed by auto-commit safety nets — exclude them in the safety net's `git reset`).
- File fix-tasks for failures; one per slug ever (retry-loop task spam floods the board).

Worker safety net: after the agent call, if Result section exists but no commit landed on the branch, auto-commit dirty worktree (excluding artifact globs); if no Result AND clean tree, requeue honestly.

## Prompt discipline for build workers

- **Inline condensed methodology** instead of pointing agents at 2,000-line skill docs — full-doc reads exhaust context and sessions end SILENTLY mid-task (no error, just no Result). Prefer grep-over-full-reads for >300-line files.
- **Mandatory honest Result**: "If you run out of room mid-task: STOP coding, commit partial work, append an honest Result saying exactly what remains. A silent end is the only unacceptable outcome."
- Forbid self-spawning (roles/*.sh, tmux, process managers) — agents disobey and fork-bomb your board.
- GUI apps cannot launch from agent sandboxes (macOS WindowServer registration fails, SIGABRT). Have workers mark LAUNCH-VERIFY: DEFERRED TO INTEGRATOR; launch via `open -n -a <Electron.app> --args <app>` from outside the sandbox instead.
- Backoff between failures (30→60→90→120s): rapid requeue-fail cycles flood rate-limited upstreams into worse failure modes.

## Delegation alternative

Hermes `delegate_task` caps at ~600s per call — enough for focused feature chunks, not whole epics. Pattern: precise spec + explicit DoD + "report files changed"; on timeout, dispatch CONTINUATION delegates told to read current state first (partial work persists on disk). Batch parallel independent tasks works well; serialize only what shares state. Per-worktree setup before dispatch: `git worktree add -b sb/<slug> .swarm/wt/<slug> main && ln -sfn ~/sb-deps/node_modules .swarm/wt/<slug>/node_modules`.

## Operating mode for this user

Proactive self-directed loops: run deterministic checkers + behavioral audits unprompted, fix what's feasible without asking, integrate behind gates, push, THEN report with a scorecard + honest remaining-gaps list. "Continue" means keep executing the current pipeline to its next milestone — never stop at analysis-only.

## References

- [references/build-swarm-taskboard.md](references/build-swarm-taskboard.md) — lib.sh patterns: claim/recycle/integrate implementations, fcc-codex quirks (-c flags break provider injection; reasoning effort lives in config.toml; proxy watchdog), node_modules protection scheme
- [references/electron-browser-clone-qa.md](references/electron-browser-clone-qa.md) — browser-clone QA checklist: IPC payload canonicalization, internal-route placeholder matching, dead-handler symptoms, PiP implementation notes