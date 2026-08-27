# Build-Swarm Taskboard & Executor Patterns

Condensed from a two-swarm production day (business swarm + 130-task browser-clone build swarm). All pitfalls below were hit, diagnosed, and fixed in working code.

## Board layout (inside the executor repo)

```
<repo>/.swarm/            # gitignored — must be inside repo if sandbox writability = cwd
  tasks/pending|active|done/.locks
  work/<slug>/            # per-task evidence logs
  wt/<slug>/              # per-task git worktrees (branch sb/<slug>)
  qa/, logs/, run/
```

- `run/agent-slot` — global serialization dir for LLM calls.
- `run/integrated.txt` — integrator ledger of merged slugs.

## lib.sh core patterns

### Serialization slot (rate-limited proxies return EMPTY under concurrency)

```bash
agent() {
  local slot="$RUN/agent-slot"
  while ! mkdir "$slot" 2>/dev/null; do
    [ -d "$slot" ] && [ -n "$(find "$slot" -maxdepth 0 -mmin +75 2>/dev/null)" ] && rmdir "$slot" && continue
    sleep 15
  done
  "$FCC_BIN" exec --skip-git-repo-check --sandbox workspace-write -m "$MODEL" "$1" </dev/null
  local rc=$?; rmdir "$slot" 2>/dev/null; return $rc
}
```
Symptom of missing this: every "completed" call logs ~5k tokens and zero output text; solo probes succeed while the fleet fails.

### Claim with leaked-lock sweep + stale recycle (no lock leaks allowed)

```bash
recycle_stale() {  # mv is atomic; NEVER leave a lock behind
  find "$TASKS/active" -name '*.md' -type f -mmin "+$STALE_MINUTES" -print0 2>/dev/null |
  while IFS= read -r -d '' t; do
    base="$(basename "$t")"; mv "$t" "$TASKS/pending/${base#*__}" 2>/dev/null \
      && log recycle "requeued ${base#*__}"
  done
}
claim_task() {
  local worker="$1"; recycle_stale
  # sweep leaked locks: lock whose task has no live active/ entry is orphaned.
  # Do NOT use globs here: under nullglob a failed glob vanishes and bare `ls dir`
  # exits 0, making every leaked lock look legitimately held.
  for l in "$TASKS"/.locks/*.lock; do
    [ -e "$l" ] || continue
    lb="$(basename "$l" .lock)"; keep=""
    for a in "$TASKS"/active/*.md; do
      [ -e "$a" ] || continue
      case "$(basename "$a")" in *"$lb") keep=1; break ;; esac
    done
    [ -z "$keep" ] && rmdir "$l" 2>/dev/null
  done
  shopt -s nullglob
  for t in "$TASKS/pending"/*.md; do
    base="$(basename "$t")"
    mkdir "$TASKS/.locks/$base.lock" 2>/dev/null || continue
    mv "$t" "$TASKS/active/${worker}__${base}"
    touch "$TASKS/active/${worker}__${base}"   # mtime = claim time!
    echo "$TASKS/active/${worker}__${base}"; return 0
  done
  return 1
}
finish_task() {
  base="$(basename "$1")"; mv "$1" "$TASKS/done/$base"
  rm -rf "$TASKS/.locks/${base#*__}.lock"   # release so name is reusable
}
```

- `touch` at claim is mandatory: `mv` preserves creation mtime, and age-based recycle would otherwise steal fresh claims on old files.
- STALE_MINUTES must exceed longest legit task. At max reasoning effort that is 60–90 min, not 45. A keep-fresh `touch active/*.md` loop (every 4 min) during long runs is cheap insurance.

### Gated integrator (serial merges)

```bash
try_integrate() {
  grep -qx "$slug" integrated.txt && return 0
  br=$(git branch --list "sb/$slug" | tr -d ' *+');   # '+' = checked out in a worktree!
  [ -z "$br" ] && return 0
  git checkout -- . ; mv tsconfig.*.tsbuildinfo /tmp/ 2>/dev/null   # QA builds dirty trees
  git merge --no-ff -m "integrate: $slug" "$br" || { git merge --abort; file_fix_task "$slug"; return 1; }
  if typecheck && build; then
    git worktree remove --force ".swarm/wt/$slug"; echo "$slug OK" >> integrated.txt
  else
    [ "$(git log -1 --format=%s)" = "integrate: $slug" ] && git reset --hard HEAD~1   # SAFE reset only
    file_fix_task "$slug" "build broken"; echo "$slug BROKEN" >> integrated.txt
  fi
}
```

- SAFE RESET GUARD IS NOT OPTIONAL: a blind `reset --hard HEAD~1` inside a retry loop erased three unrelated commits once (including manual hotfixes).
- Branch listing: strip BOTH `*` (current) and `+` (worktree-checked-out) markers or merges target invalid refs like `+sb/foo`.
- Auto-commit safety net in worker after agent call: if Result exists but branch has no new commits and tree is dirty → `git add -A && git reset -q -- '*.tsbuildinfo' node_modules && git commit`. Agents omit the commit step constantly.
- Untracked files tracked-on-branch (node_modules symlinks committed by safety nets) abort merges with confusing "untracked would be overwritten" — fix .gitignore patterns (`node_modules` bare, not `node_modules/`, which misses symlinks).
- file_fix_task needs a once-per-slug guard (state file), else retry loops flood the board with duplicate fix tasks (60+ duplicates observed in one night).

## fcc-codex / free-proxy quirks

- Extra `-c key=value` flags BREAK provider injection → requests fall back to api.openai.com → HK-region 401 "Missing bearer authentication". Reasoning effort belongs in `~/.codex/config.toml`, never on the CLI.
- Upstream supports `xhigh`; `"max"` returns EMPTY replies (5k tokens burned, zero text). Symptom identical to concurrency empties — check config first when both change at once. Big prompts (~6k+ request tokens) can ALSO return empty when upstream is degraded while tiny probes succeed — test prompt size explicitly before blaming concurrency or effort level.
- The proxy server dies silently under load/cleanup daemons. Watchdog pattern (tmux-hosted): every 30 s, `lsof -i :8082` → relaunch `fcc-server >> log 2>&1 &`. Workers stuck printing "Reconnecting... waiting for network" recover by themselves once the port returns.
- Auth failures show as 401 with cf-ray headers relayed from upstream; connection-refused means the proxy process itself is gone (`fcc-server` to restart).

## node_modules protection

Agents delete/reinstall node_modules despite prompts (npm ci removes then fails offline). Make it structurally safe:
1. Real modules live OUTSIDE any writable root: `~/sb-deps/node_modules`.
2. Repo + worktrees get symlinks: `ln -sfn ~/sb-deps/node_modules <tree>/node_modules`.
3. Watchdog self-heals every 30 s: symlink missing → recreate; target missing → reinstall (watchdog has network, agents don't).
4. Auto-commit excludes `node_modules` and artifact globs (`*.tsbuildinfo`) — bare `.gitignore` entry needed for symlink case (trailing-slash form doesn't match symlinks).

## Prompt rules that measurably reduced silent deaths

1. Inline condensed methodology; forbid reads of multi-thousand-line skill docs (context exhaustion = session ends silently, no error, no Result).
2. Mandatory honest Result section with an explicit "if you run out of room: commit partial work + honest Result" escape hatch.
3. Forbid spawning role scripts/tmux/process managers (agents fork-bomb boards otherwise).
4. GUI-launch tasks: workers mark `LAUNCH-VERIFY: DEFERRED TO INTEGRATOR` instead of failing.
5. Escalating backoff on no-Result (30→60→90→120s) before requeueing.
6. Never overwrite existing task numbers NNN (check pending+active+done); duplicate-numbered rewrites caused double-execution races.

## Delegation alternative

Hermes `delegate_task` caps at ~600s per call — enough for focused feature chunks, not whole epics. Pattern: precise spec + explicit DoD + "report files changed"; on timeout, dispatch CONTINUATION delegates told to read current state first (partial work persists on disk). Batch parallel independent tasks works well; serialize only what shares state. Per-worktree setup before dispatch: `git worktree add -b sb/<slug> .swarm/wt/<slug> main && ln -sfn ~/sb-deps/node_modules .swarm/wt/<slug>/node_modules`.
